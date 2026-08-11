
#!/bin/bash

# ==========================================
# EC2 Instance Rename Script
# ==========================================

set -e

# ------------------------------------------
# Load .env file
# ------------------------------------------

if [ ! -f .env ]; then
    echo "ERROR: .env file not found."
    exit 1
fi

source .env


# ------------------------------------------
# Check required variables
# ------------------------------------------

if [ -z "$AWS_REGION" ]; then
    echo "ERROR: AWS_REGION is not set in .env"
    exit 1
fi

if [ -z "$OLD_INSTANCE_NAME" ]; then
    echo "ERROR: OLD_INSTANCE_NAME is not set in .env"
    exit 1
fi

if [ -z "$NEW_INSTANCE_NAME" ]; then
    echo "ERROR: NEW_INSTANCE_NAME is not set in .env"
    exit 1
fi


# ------------------------------------------
# Display configuration
# ------------------------------------------

echo "=========================================="
echo "EC2 INSTANCE RENAME"
echo "=========================================="
echo "Region:     $AWS_REGION"
echo "Old Name:   $OLD_INSTANCE_NAME"
echo "New Name:   $NEW_INSTANCE_NAME"
echo ""


# ------------------------------------------
# Find the EC2 instance
# ------------------------------------------

echo "Searching for instance: $OLD_INSTANCE_NAME"

INSTANCE_ID=$(aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --filters \
        "Name=tag:Name,Values=$OLD_INSTANCE_NAME" \
        "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[].Instances[0].InstanceId' \
    --output text)


# ------------------------------------------
# Check if instance exists
# ------------------------------------------

if [ "$INSTANCE_ID" = "None" ] || [ -z "$INSTANCE_ID" ]; then
    echo "ERROR: EC2 instance '$OLD_INSTANCE_NAME' was not found."
    exit 1
fi

echo "Found instance: $INSTANCE_ID"
echo ""


# ------------------------------------------
# Change the Name tag
# ------------------------------------------

echo "Changing name from '$OLD_INSTANCE_NAME' to '$NEW_INSTANCE_NAME'..."

aws ec2 create-tags \
    --region "$AWS_REGION" \
    --resources "$INSTANCE_ID" \
    --tags Key=Name,Value="$NEW_INSTANCE_NAME"

echo ""
echo "Successfully renamed the EC2 instance."


# ------------------------------------------
# Confirm the change
# ------------------------------------------

echo ""
echo "=========================================="
echo "CONFIRMATION"
echo "=========================================="

aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name]' \
    --output table

echo ""
echo "=========================================="
echo "RENAME COMPLETE"
echo "=========================================="


