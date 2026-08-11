
#!/bin/bash

# ==========================================
# AWS EC2 + S3 Resource Creation Script
# ==========================================

set -e

# ------------------------------------------
# Load environment variables
# ------------------------------------------

if [ ! -f .env ]; then
    echo "ERROR: .env file not found."
    exit 1
fi

source .env

echo "=========================================="
echo "AWS RESOURCE CREATION SCRIPT"
echo "=========================================="
echo "Region:         $AWS_REGION"
echo "AMI:            $AMI_ID"
echo "Instance Type:  $INSTANCE_TYPE"
echo ""


# ------------------------------------------
# 1. Check Key Pair 1
# ------------------------------------------

echo "Checking key pair: $KEY_NAME_1"

if aws ec2 describe-key-pairs \
    --key-names "$KEY_NAME_1" \
    --region "$AWS_REGION" \
    >/dev/null 2>&1
then
    echo "Key pair $KEY_NAME_1 already exists. Reusing it."
else
    echo "Key pair $KEY_NAME_1 does not exist."

    echo "Creating key pair: $KEY_NAME_1"

    aws ec2 create-key-pair \
        --key-name "$KEY_NAME_1" \
        --region "$AWS_REGION" \
        --query 'KeyMaterial' \
        --output text > "$PEM_FILE_1"

    chmod 400 "$PEM_FILE_1"

    echo "Key pair $KEY_NAME_1 created."
fi

echo ""


# ------------------------------------------
# 2. Check Key Pair 2
# ------------------------------------------

echo "Checking key pair: $KEY_NAME_2"

if aws ec2 describe-key-pairs \
    --key-names "$KEY_NAME_2" \
    --region "$AWS_REGION" \
    >/dev/null 2>&1
then
    echo "Key pair $KEY_NAME_2 already exists. Reusing it."
else
    echo "Key pair $KEY_NAME_2 does not exist."

    echo "Creating key pair: $KEY_NAME_2"

    aws ec2 create-key-pair \
        --key-name "$KEY_NAME_2" \
        --region "$AWS_REGION" \
        --query 'KeyMaterial' \
        --output text > "$PEM_FILE_2"

    chmod 400 "$PEM_FILE_2"

    echo "Key pair $KEY_NAME_2 created."
fi

echo ""


# ------------------------------------------
# 3. Check PEM File 1
# ------------------------------------------

if [ -f "$PEM_FILE_1" ]; then
    echo "Private key found: $PEM_FILE_1"
else
    echo "WARNING: $PEM_FILE_1 does not exist."

    if aws ec2 describe-key-pairs \
        --key-names "$KEY_NAME_1" \
        --region "$AWS_REGION" \
        >/dev/null 2>&1
    then
        echo "The AWS key pair exists, but the private key file is missing."
        echo "AWS cannot provide the original private key again."
        echo "Please restore $PEM_FILE_1 before using this key pair for SSH."
    fi
fi

echo ""


# ------------------------------------------
# 4. Check PEM File 2
# ------------------------------------------

if [ -f "$PEM_FILE_2" ]; then
    echo "Private key found: $PEM_FILE_2"
else
    echo "WARNING: $PEM_FILE_2 does not exist."

    if aws ec2 describe-key-pairs \
        --key-names "$KEY_NAME_2" \
        --region "$AWS_REGION" \
        >/dev/null 2>&1
    then
        echo "The AWS key pair exists, but the private key file is missing."
        echo "AWS cannot provide the original private key again."
        echo "Please restore $PEM_FILE_2 before using this key pair for SSH."
    fi
fi

echo ""


# ------------------------------------------
# 5. Check / Create S3 Bucket
# ------------------------------------------

echo "Checking S3 bucket: $S3_BUCKET"

if aws s3api head-bucket \
    --bucket "$S3_BUCKET" \
    --region "$AWS_REGION" \
    >/dev/null 2>&1
then
    echo "S3 bucket $S3_BUCKET already exists. Reusing it."
else
    echo "S3 bucket does not exist."
    echo "Creating S3 bucket: $S3_BUCKET"

    aws s3api create-bucket \
        --bucket "$S3_BUCKET" \
        --region "$AWS_REGION" \
        --create-bucket-configuration LocationConstraint="$AWS_REGION"

    echo "S3 bucket created."
fi

echo ""


# ------------------------------------------
# 6. Check / Create PostgreSQL Server
# ------------------------------------------

echo "Checking EC2 instance: $INSTANCE_NAME_1"

INSTANCE1=$(aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --filters \
        "Name=tag:Name,Values=$INSTANCE_NAME_1" \
        "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[].Instances[0].InstanceId' \
    --output text)

if [ "$INSTANCE1" != "None" ] && [ -n "$INSTANCE1" ]; then

    echo "Instance $INSTANCE_NAME_1 already exists."
    echo "Instance ID: $INSTANCE1"

else

    echo "Creating EC2 instance: $INSTANCE_NAME_1"

    INSTANCE1=$(aws ec2 run-instances \
        --image-id "$AMI_ID" \
        --instance-type "$INSTANCE_TYPE" \
        --key-name "$KEY_NAME_1" \
        --region "$AWS_REGION" \
        --query 'Instances[0].InstanceId' \
        --output text)

    aws ec2 create-tags \
        --region "$AWS_REGION" \
        --resources "$INSTANCE1" \
        --tags Key=Name,Value="$INSTANCE_NAME_1"

    echo "EC2 instance created."
    echo "Instance ID: $INSTANCE1"
    echo "Instance Name: $INSTANCE_NAME_1"

fi

echo ""


# ------------------------------------------
# 7. Check / Create Config Server
# ------------------------------------------

echo "Checking EC2 instance: $INSTANCE_NAME_2"

INSTANCE2=$(aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --filters \
        "Name=tag:Name,Values=$INSTANCE_NAME_2" \
        "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[].Instances[0].InstanceId' \
    --output text)

if [ "$INSTANCE2" != "None" ] && [ -n "$INSTANCE2" ]; then

    echo "Instance $INSTANCE_NAME_2 already exists."
    echo "Instance ID: $INSTANCE2"

else

    echo "Creating EC2 instance: $INSTANCE_NAME_2"

    INSTANCE2=$(aws ec2 run-instances \
        --image-id "$AMI_ID" \
        --instance-type "$INSTANCE_TYPE" \
        --key-name "$KEY_NAME_2" \
        --region "$AWS_REGION" \
        --query 'Instances[0].InstanceId' \
        --output text)

    aws ec2 create-tags \
        --region "$AWS_REGION" \
        --resources "$INSTANCE2" \
        --tags Key=Name,Value="$INSTANCE_NAME_2"

    echo "EC2 instance created."
    echo "Instance ID: $INSTANCE2"
    echo "Instance Name: $INSTANCE_NAME_2"

fi

echo ""


# ------------------------------------------
# 8. Display Final Results
# ------------------------------------------

echo "=========================================="
echo "AWS RESOURCE CHECK COMPLETE"
echo "=========================================="

echo ""
echo "S3 Bucket:"
echo "$S3_BUCKET"

echo ""
echo "EC2 Instances:"

aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --filters \
        "Name=tag:Name,Values=$INSTANCE_NAME_1,$INSTANCE_NAME_2" \
    --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0],InstanceType,State.Name,PublicIpAddress,KeyName]' \
    --output table

echo ""
echo "Key Pairs:"

aws ec2 describe-key-pairs \
    --region "$AWS_REGION" \
    --query "KeyPairs[?KeyName==\`$KEY_NAME_1\` || KeyName==\`$KEY_NAME_2\`].[KeyName,KeyPairId]" \
    --output table

echo ""
echo "Private Key Files:"

ls -l "$PEM_FILE_1" "$PEM_FILE_2" 2>/dev/null || true

echo ""
echo "=========================================="
echo "SCRIPT COMPLETE"
echo "=========================================="


