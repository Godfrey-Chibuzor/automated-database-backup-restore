
#!/bin/bash

# =========================================================
# Interactive PostgreSQL Restore Script
# =========================================================

set -e

# ---------------------------------------------------------
# Configuration
# ---------------------------------------------------------

DATABASE="nigerian_economic_data"

S3_BUCKET="godfrey-postgres-backups-2026"
S3_BACKUP_DIR="Automated_Backups"

RESTORE_DIR="/home/ubuntu/db_restore"
LOG_FILE="$RESTORE_DIR/restore.log"

# ---------------------------------------------------------
# Create restore directory
# ---------------------------------------------------------

mkdir -p "$RESTORE_DIR"

# ---------------------------------------------------------
# Function to write to restore log
# ---------------------------------------------------------

log_message() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" >> "$LOG_FILE"
}

# ---------------------------------------------------------
# Start
# ---------------------------------------------------------

echo "=========================================="
echo "   PostgreSQL Database Restore"
echo "=========================================="
echo ""

log_message "=========================================="
log_message "Starting interactive PostgreSQL restore"

# ---------------------------------------------------------
# Check S3 access
# ---------------------------------------------------------

echo "Checking available backups in S3..."
echo ""

if ! aws s3 ls "s3://$S3_BUCKET/$S3_BACKUP_DIR/" >/dev/null 2>&1; then

    echo "ERROR: Unable to access S3 bucket."
    echo "Check your IAM role and AWS CLI configuration."

    log_message "ERROR: Unable to access S3 bucket."

    exit 1
fi

# ---------------------------------------------------------
# Get backup files from S3
# ---------------------------------------------------------

mapfile -t BACKUPS < <(
    aws s3 ls "s3://$S3_BUCKET/$S3_BACKUP_DIR/" |
    awk '$4 ~ /\.sql\.gz$/ {print $4}'
)

# ---------------------------------------------------------
# Check if backups exist
# ---------------------------------------------------------

if [ "${#BACKUPS[@]}" -eq 0 ]; then

    echo "No PostgreSQL backup files were found in S3."

    log_message "No PostgreSQL backup files found in S3."

    exit 1
fi

# ---------------------------------------------------------
# Display available backups
# ---------------------------------------------------------

echo "Available PostgreSQL backups:"
echo ""

for i in "${!BACKUPS[@]}"; do

    SERIAL=$((i + 1))

    echo "$SERIAL. ${BACKUPS[$i]}"

done

echo ""

# ---------------------------------------------------------
# Ask user to select backup
# ---------------------------------------------------------

read -rp "Enter the serial number of the backup you want to restore: " CHOICE

# ---------------------------------------------------------
# Validate selection
# ---------------------------------------------------------

if ! [[ "$CHOICE" =~ ^[0-9]+$ ]]; then

    echo "ERROR: Please enter a valid number."

    log_message "ERROR: Invalid backup selection: $CHOICE"

    exit 1
fi

if [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt "${#BACKUPS[@]}" ]; then

    echo "ERROR: Invalid serial number."

    log_message "ERROR: Backup selection out of range: $CHOICE"

    exit 1
fi

# ---------------------------------------------------------
# Select backup
# ---------------------------------------------------------

SELECTED_BACKUP="${BACKUPS[$((CHOICE - 1))]}"

S3_BACKUP_PATH="s3://$S3_BUCKET/$S3_BACKUP_DIR/$SELECTED_BACKUP"

LOCAL_BACKUP_FILE="$RESTORE_DIR/$SELECTED_BACKUP"

echo ""
echo "Selected backup:"
echo "$SELECTED_BACKUP"
echo ""

log_message "Selected backup: $SELECTED_BACKUP"

# ---------------------------------------------------------
# Download selected backup
# ---------------------------------------------------------

echo "Downloading selected backup from S3..."

log_message "Downloading backup from S3: $S3_BACKUP_PATH"

if aws s3 cp "$S3_BACKUP_PATH" "$LOCAL_BACKUP_FILE"; then

    echo "Backup downloaded successfully."

    log_message "Backup downloaded successfully."

else

    echo "ERROR: Failed to download backup."

    log_message "ERROR: Failed to download backup."

    exit 1
fi

# ---------------------------------------------------------
# Verify backup file
# ---------------------------------------------------------

if [ ! -s "$LOCAL_BACKUP_FILE" ]; then

    echo "ERROR: Downloaded backup file is empty."

    log_message "ERROR: Downloaded backup file is empty."

    rm -f "$LOCAL_BACKUP_FILE"

    exit 1
fi

BACKUP_SIZE=$(du -h "$LOCAL_BACKUP_FILE" | cut -f1)

echo "Backup size: $BACKUP_SIZE"

log_message "Downloaded backup size: $BACKUP_SIZE"

# ---------------------------------------------------------
# Check whether database exists
# ---------------------------------------------------------

echo ""
echo "Checking PostgreSQL database..."

DATABASE_EXISTS=$(sudo -u postgres psql -tAc \
    "SELECT 1 FROM pg_database WHERE datname='$DATABASE'")

# ---------------------------------------------------------
# Drop existing database
# ---------------------------------------------------------

if [ "$DATABASE_EXISTS" = "1" ]; then

    echo "Existing database found."
    echo "Dropping $DATABASE..."

    log_message "Existing database found."
    log_message "Dropping database: $DATABASE"

    sudo -u postgres psql -c \
        "DROP DATABASE $DATABASE;"

    log_message "Existing database dropped."

fi

# ---------------------------------------------------------
# Create database
# ---------------------------------------------------------

echo "Creating database: $DATABASE..."

log_message "Creating database: $DATABASE"

sudo -u postgres psql -c \
    "CREATE DATABASE $DATABASE;"

log_message "Database created successfully."

# ---------------------------------------------------------
# Restore backup
# ---------------------------------------------------------

echo "Restoring backup..."
echo ""

log_message "Starting database restoration."

if gunzip -c "$LOCAL_BACKUP_FILE" | \
    sudo -u postgres psql "$DATABASE"; then

    echo "Database restored successfully."

    log_message "Database restored successfully."

else

    echo "ERROR: Database restoration failed."

    log_message "ERROR: Database restoration failed."

    exit 1
fi

# ---------------------------------------------------------
# Verify restored tables
# ---------------------------------------------------------

echo ""
echo "Verifying restored database..."

TABLE_COUNT=$(sudo -u postgres psql \
    -d "$DATABASE" \
    -tAc "SELECT count(*)
          FROM information_schema.tables
          WHERE table_schema='public';")

echo "Number of restored tables: $TABLE_COUNT"

log_message "Number of restored tables: $TABLE_COUNT"

# ---------------------------------------------------------
# Finish
# ---------------------------------------------------------

log_message "Restore completed successfully."
log_message "Database: $DATABASE"
log_message "Backup restored: $SELECTED_BACKUP"
log_message "=========================================="

echo ""
echo "=========================================="
echo "   RESTORE COMPLETED SUCCESSFULLY"
echo "=========================================="
echo "Database:        $DATABASE"
echo "Backup restored: $SELECTED_BACKUP"
echo "Restored tables: $TABLE_COUNT"
echo "Restore log:     $LOG_FILE"
echo "=========================================="


