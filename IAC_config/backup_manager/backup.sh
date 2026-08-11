#!/bin/bash

# ==========================================
# PostgreSQL Automated Backup Script
# ==========================================

set -e

# ------------------------------------------
# Configuration
# ------------------------------------------

DATABASE="nigerian_economic_data"

BACKUP_DIR="/home/ubuntu/Automated_Backups"

LOG_FILE="$BACKUP_DIR/backup.log"

S3_BUCKET="godfrey-postgres-backups-2026"

S3_FOLDER="Automated_Backups"

RETENTION_DAYS=7

# ------------------------------------------
# Create backup directory if it does not exist
# ------------------------------------------

mkdir -p "$BACKUP_DIR"

# ------------------------------------------
# Create timestamp
# ------------------------------------------

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

BACKUP_FILE="$BACKUP_DIR/${DATABASE}_${TIMESTAMP}.sql.gz"

# ------------------------------------------
# Logging function
# ------------------------------------------

log_message() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" >> "$LOG_FILE"
}

# ------------------------------------------
# Start backup
# ------------------------------------------

log_message "=========================================="
log_message "Starting PostgreSQL backup"
log_message "Database: $DATABASE"
log_message "Backup file: $BACKUP_FILE"

# ------------------------------------------
# Create PostgreSQL backup
# ------------------------------------------

if sudo -u postgres pg_dump "$DATABASE" | gzip > "$BACKUP_FILE"; then

    log_message "Backup completed successfully."
    log_message "Backup saved to: $BACKUP_FILE"

else

    log_message "ERROR: PostgreSQL backup failed."

    rm -f "$BACKUP_FILE"

    exit 1

fi

# ------------------------------------------
# Display backup size
# ------------------------------------------

BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)

log_message "Backup size: $BACKUP_SIZE"

# ------------------------------------------
# Upload backup to S3
# ------------------------------------------

log_message "Uploading backup to S3..."

if aws s3 cp "$BACKUP_FILE" \
    "s3://$S3_BUCKET/$S3_FOLDER/"; then

    log_message "Backup successfully uploaded to S3."
    log_message "S3 location: s3://$S3_BUCKET/$S3_FOLDER/"

else

    log_message "ERROR: Failed to upload backup to S3."

    exit 1

fi

# ------------------------------------------
# Delete local backups older than 7 days
# ------------------------------------------

log_message "Checking for local backups older than $RETENTION_DAYS days..."

find "$BACKUP_DIR" \
    -type f \
    -name "${DATABASE}_*.sql.gz" \
    -mtime +7 \
    -print \
    -delete | while read -r OLD_BACKUP
do
    log_message "Deleted old local backup: $OLD_BACKUP"
done

# ------------------------------------------
# Delete S3 backups older than 7 days
# ------------------------------------------

log_message "Checking S3 for backups older than $RETENTION_DAYS days..."

CUTOFF_DATE=$(date -u -d "$RETENTION_DAYS days ago" +"%Y-%m-%dT%H:%M:%SZ")

OLD_S3_FILES=$(aws s3api list-objects-v2 \
    --bucket "$S3_BUCKET" \
    --prefix "$S3_FOLDER/" \
    --query "Contents[?LastModified<='$CUTOFF_DATE'].Key" \
    --output text)

if [ -n "$OLD_S3_FILES" ] && [ "$OLD_S3_FILES" != "None" ]; then

    for OLD_S3_FILE in $OLD_S3_FILES
    do

        aws s3 rm "s3://$S3_BUCKET/$OLD_S3_FILE"

        log_message "Deleted old S3 backup: $OLD_S3_FILE"

    done

else

    log_message "No S3 backups older than $RETENTION_DAYS days found."

fi

# ------------------------------------------
# Finish
# ------------------------------------------

log_message "Backup process completed."
log_message "=========================================="
log_message ""

echo "Backup completed successfully."
echo "Database: $DATABASE"
echo "Backup file: $BACKUP_FILE"
echo "Backup size: $BACKUP_SIZE"
echo "S3 location: s3://$S3_BUCKET/$S3_FOLDER/"
echo "Log file: $LOG_FILE"
