# Automated Database Backup and Restore

## Project Overview

This project is a DevOps solution for automating the backup and restoration of a PostgreSQL database hosted on an AWS EC2 instance.

The system uses Linux Crons to automatically run database backups every three hours. The backups are compressed, stored locally on the Database Server, and uploaded to an Amazon S3 bucket for reliable storage.

A restore script is also provided to allow an operator to select an available backup from S3 and restore the PostgreSQL database when required.

The project also uses Ansible to automate the configuration of the Database Server and AWS IAM roles to allow the EC2 instance to access S3 without storing long-lived AWS access keys on the server.

## Architecture

### Backup Flow

t
Linux Cron
|
| Every 3 hours
v
backup.sh
|
v
PostgreSQL Database
|
| pg_dump
v
Compressed Backup (.sql.gz)
|
+------------------+
|                  |
v                  v
EC2 Local Storage     AWS S3
Automated_Backups/    Automated_Backups/

### Restore Flow

Operator
|
v
restore.sh
|
v
List available backups
from S3
|
v
Operator selects backup
|
v
Download selected backup
|
v
Restore PostgreSQL Database

## Project Objectives

The main objectives of this project are to:

* Automate PostgreSQL database backups.
* Store timestamped backup files locally.
* Store backup files securely in Amazon S3.
* Schedule backups automatically using Linux Cron.
* Provide a simple database restoration process.
* Automate server configuration using Ansible.
* Use AWS IAM roles instead of storing AWS access keys on the Database Server.
* Maintain logs of backup and restoration activities.
* Organize the project using Git and GitHub.

## Technologies Used

| Technology   | Purpose                                     |
| ------------ | ------------------------------------------- |
| Ubuntu Linux | Operating system and server environment     |
| PostgreSQL   | Database management system                  |
| AWS EC2      | Hosts the PostgreSQL Database Server        |
| Amazon S3    | Remote storage for database backups         |
| AWS IAM      | Provides controlled access to S3            |
| AWS CLI      | Interacts with AWS services from the server |
| Ansible      | Automates server configuration              |
| Bash         | Backup and restore automation               |
| Linux Cron   | Schedules automatic backups                 |
| Git          | Version control                             |
| GitHub       | Source code repository                      |

## Database

The PostgreSQL database used in the project is:

nigerian_economic_data

The database contains Nigerian economic data, including:

* Foreign trade by mode of transport.
* Nigerian top export trading partners.
* Nigerian top import trading partners.

The database is hosted on the AWS EC2 Database Server.

## AWS Infrastructure

The project uses AWS EC2 and Amazon S3.

### EC2 Servers

The project contains separate EC2 servers for infrastructure/configuration and database operations.

The Database Server hosts:

* PostgreSQL
* AWS CLI
* `backup.sh`
* `restore.sh`
* Linux Cron

### S3 Bucket

Backups are stored in:

s3://godfrey-postgres-backups-2026/

The backup files are organized under:

Automated_Backups/

## IAM Security

The Database Server accesses Amazon S3 through an IAM role attached to the EC2 instance.

This approach avoids storing long-lived AWS access keys and secret access keys on the Database Server.

The IAM role is granted only the permissions required by the backup and restore operations, such as:

s3:ListBucket
s3:GetObject
s3:PutObject

This follows the principle of least privilege.

## Automated Backup

The backup.sh script performs the following operations:

1. Creates the local backup directory if it does not exist.
2. Creates a timestamp for the backup.
3. Uses `pg_dump` to back up the PostgreSQL database.
4. Compresses the backup using `gzip`.
5. Saves the backup locally.
6. Uploads the backup to Amazon S3.
7. Records backup activities in a log file.
8. Handles failed backup operations.

Example backup filename:

nigerian_economic_data_2026-08-09_12-00-00.sql.gz

## Automated Scheduling

Linux Cron is used to automatically execute `backup.sh`.

The backup is scheduled to run every three hours:

cron
0 */3 * * * /home/ubuntu/Automated_Backups/backup.sh

This means the backup runs at:

00:00
03:00
06:00
09:00
12:00
15:00
18:00
21:00

The Cron service is also enabled to start automatically when the EC2 instance starts.

## Database Restoration

The `restore.sh` script provides an interactive restoration process.

When executed, it:

1. Connects to the S3 backup location.
2. Lists the available PostgreSQL backups.
3. Displays the backups with serial numbers.
4. Prompts the operator to select a backup.
5. Downloads the selected backup.
6. Restores the selected backup into PostgreSQL.
7. Records restoration activities in a restore log.

Example:

Available backups:

1. nigerian_economic_data_2026-08-08_00-00-00.sql.gz
2. nigerian_economic_data_2026-08-08_03-00-00.sql.gz
3. nigerian_economic_data_2026-08-08_06-00-00.sql.gz

Enter the serial number of the backup to restore:

The operator can enter the required serial number and the script automatically performs the restoration.

## Logging

The backup process maintains a log containing information such as:

* Backup start time.
* Database name.
* Backup filename.
* Backup size.
* S3 upload status.
* Backup completion status.
* Errors encountered during the backup.

The restore process also maintains a restore log containing information about restoration activities.

## Ansible Configuration

Ansible is used to automate the configuration of the Database Server.

The Ansible playbook installs and configures:

* PostgreSQL
* AWS CLI
* Required AWS CLI dependencies

This eliminates the need to manually install and configure these components on the Database Server.

## Project Structure

automated-db-backup-restore/
│
├── IAC_config/
│   │
│   ├── ansible_configuration/
│   │   ├── inventory.example
│   │   └── setup_database_server.yml
│   │
│   ├── automated_backups/
│   │   ├── backup.sh
│   │   └── backup.log
│   │
│   ├── restore_manager/
│   │   ├── restore.sh
│   │   └── restore.log
│   │
│   ├── create_aws_resources.sh
│   ├── rename_server.sh
│   └── .env.example
│
├── architecture_diagram.png
├── demo_video
├── README.md
└── .gitignore

## How to Set Up the Project After Cloning

The `.env` and `inventory` files contain configuration information specific to the environment where the project is being deployed.

For security reasons, these files are excluded from the Git repository using `.gitignore`.

Instead, the repository contains:

* `.env.example`
* `inventory.example`

Anyone cloning this repository should use these example files as templates and create their own `.env` and `inventory` files before running the project.

### 1. Clone the Repository

Clone the repository to your local machine:

```bash
git clone <YOUR-GITHUB-REPOSITORY-URL>
```

Enter the project directory:

```bash
cd automated-db-backup-restore
```

### 2. Create the `.env` File

Go to the `IAC_config` directory:

```bash
cd IAC_config
```

Copy `.env.example` and create a new `.env` file:

```bash
cp .env.example .env
```

Open the new `.env` file:

```bash
nano .env
```

Replace the placeholder values with the values for your own AWS environment.

The `.env.example` file contains placeholders such as:

```text
OLD_INSTANCE_NAME="YOUR_OLD_INSTANCE_NAME"

NEW_INSTANCE_NAME="YOUR_NEW_INSTANCE_NAME"

AWS_REGION="YOUR_AWS_REGION"

AMI_ID="YOUR_AMI_ID"

INSTANCE_TYPE="YOUR_INSTANCE_TYPE"

KEY_NAME_1="YOUR_KEY_NAME_1"

KEY_NAME_2="YOUR_KEY_NAME_2"

PEM_FILE_1="YOUR_PEM_FILE_1"

PEM_FILE_2="YOUR_PEM_FILE_2"

S3_BUCKET="YOUR_S3_BUCKET"

INSTANCE_NAME_1="YOUR_INSTANCE_NAME_1"

INSTANCE_NAME_2="YOUR_INSTANCE_NAME_2"
```

The values must be changed to match the AWS resources being used in the new environment.

**Do not commit the ****`.env`**** file to GitHub.**

### 3. Create the Ansible Inventory File

Go to the Ansible configuration directory:

```bash
cd ansible_configuration
```

Copy `inventory.example` and create a new `inventory` file:

```bash
cp inventory.example inventory
```

Open the new inventory file:

```bash
nano inventory
```

The `inventory.example` file contains:

```ini
[database]

YOUR AWS EC2 INSTANCE PRIVATE IPV4 ADDRESSES
```

Replace the placeholder with the **private IPv4 address of the Database Server EC2 instance**.

For example:

```ini
[database]
172.37.9.85
```

The actual private IP address will be different for each AWS environment.

**Do not commit the ****`inventory`**** file to GitHub.**

### 4. Verify the Configuration Files

After creating the files, the structure should look similar to:

```text
automated-db-backup-restore/
│
├── IAC_config/
│   │
│   ├── .env
│   ├── .env.example
│   │
│   └── ansible_configuration/
│       ├── inventory
│       ├── inventory.example
│       └── setup_database_server.yml
```

The important point is that:

```text
.env.example      → template for creating .env
inventory.example → template for creating inventory
```

Each person reproducing the project should create their own `.env` and `inventory` files using these templates and replace the placeholder values with their own AWS and EC2 configuration.

---

## How the System Works

The complete workflow is:

```text
            AWS EC2
      Configuration Server
               |
               | Ansible
               v
      AWS EC2 Database Server
               |
      +--------+--------+
      |                 |
   PostgreSQL       Linux Cron
      |                 |
      |            Every 3 hours
      |                 |
      +--------> backup.sh
                        |
                 pg_dump + gzip
                        |
             +----------+----------+
             |                     |
             v                     v
      Local Backup             Amazon S3
      EC2 Storage          godfrey-postgres-
                          backups-2026
             |                     |
             |                     |
             +---------+-----------+
                       |
                   restore.sh
                       ^
                       |
                   Operator
```

## Security Considerations

The project follows several security practices:

* AWS credentials are not hard-coded into the backup script.
* The Database Server uses an IAM role to access S3.
* The IAM role follows the principle of least privilege.
* SSH private keys are not stored in the Git repository.
* The Ansible inventory file is excluded from Git where necessary.
* Environment files containing sensitive information are excluded from Git.
* PostgreSQL operations are performed using appropriate database privileges.
* Users reproducing this project should create their own `.env` and `inventory` files from the provided example files.
* Real AWS credentials, private keys, IP addresses, and other environment-specific information should not be committed to the repository.

---

## Testing

The system was tested by:

1. Creating the PostgreSQL database.
2. Populating the database with Nigerian economic data.
3. Running the backup script manually.
4. Confirming that a timestamped `.sql.gz` backup was created.
5. Confirming that the backup was uploaded to S3.
6. Configuring Linux Cron to automate backups.
7. Deleting/recreating the database when testing restoration.
8. Running the restore script.
9. Selecting a backup from the S3 backup list.
10. Confirming that the database was successfully restored.

## Key DevOps Concepts Demonstrated

This project demonstrates practical knowledge of:

* Infrastructure automation
* Configuration management
* Cloud computing
* AWS EC2
* Amazon S3
* IAM
* AWS CLI
* PostgreSQL administration
* Bash scripting
* Linux Cron
* Automated database backup
* Database disaster recovery
* SSH
* Git and GitHub
* Infrastructure as Code principles

## Project Outcome

The completed project provides an automated and repeatable PostgreSQL backup and restoration solution.

Instead of relying on manual database backups, the system automatically performs scheduled backups and stores copies both locally and in Amazon S3.

When a database recovery is required, an operator can use the restore script to select an available backup and restore the PostgreSQL database.

This demonstrates how DevOps practices can be used to improve automation, reliability, recoverability, and operational efficiency** for database systems.

## Author

Chibuzor Godfrey Ekwenye

3MTT NEXTGEN Cohort DevOps Capstone Project

Project Database Backup and Restore


