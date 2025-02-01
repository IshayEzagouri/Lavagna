#!/bin/bash

# Ensure a tag is provided, else exit with an error
if [ -z "$1" ]; then
  echo "Error: You must provide a tag for the deployment package."
  echo "Usage: ./deploy.sh <tag>"
  exit 1
else
  IMAGE_TAG="$1"  
fi

AWS_REGION="ap-south-1"
AWS_ACCOUNT_ID="324037305534"
ECR_REPO_NAME="ishay_lavagna_ecr"
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"

EC2_USER="ubuntu"
EC2_HOST="65.0.181.101"
SSH_KEY="../ishay.aws2.pem"  

DEPLOY_PACKAGE="lavagna-startup-package_${IMAGE_TAG}.tar.gz"  # Use the tag in the deployment package name

echo "Starting Deployment..."

# Ensure the package exists before proceeding
if [[ ! -f ${DEPLOY_PACKAGE} ]]; then
    echo "Deployment package not found: ${DEPLOY_PACKAGE}"
    exit 1
fi

# Step 1: Docker login
echo "Logging into AWS ECR..."

# Ensure the AWS region is set
export AWS_REGION=${AWS_REGION}

# Log into ECR using the proper credentials
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_URI}

# Step 2: Clean up any old deployment files on the EC2 instance
echo "Cleaning up old deployment files on EC2..."
ssh -i ${SSH_KEY} ${EC2_USER}@${EC2_HOST} "sudo rm -rf /home/ubuntu/lavagna-deployment && echo 'Deleted old lavagna-deployment directory.'"
ssh -i ${SSH_KEY} ${EC2_USER}@${EC2_HOST} "sudo rm -f /home/ubuntu/lavagna-startup-package_*.tar.gz && echo 'Deleted old .tar.gz deployment packages.'"

# Step 3: Copy the deployment package to the EC2 instance
echo "Copying deployment package to EC2 instance..."
scp -i ${SSH_KEY} ${DEPLOY_PACKAGE} ${EC2_USER}@${EC2_HOST}:/home/ubuntu/

# Step 4: Extract the package on EC2 and ensure it goes to the correct directory
echo "Extracting package on EC2..."
ssh -i ${SSH_KEY} ${EC2_USER}@${EC2_HOST} "mkdir -p /home/ubuntu/lavagna-deployment && tar -xzvf /home/ubuntu/${DEPLOY_PACKAGE} -C /home/ubuntu/lavagna-deployment/"

# Step 5: Check Docker version on EC2 (optional)
echo "Verifying Docker installation on EC2..."
ssh -i ${SSH_KEY} ${EC2_USER}@${EC2_HOST} "docker --version || (echo 'Docker not found, installing...' && sudo apt-get update && sudo apt-get install -y docker.io)"

# Step 6: Check Docker Compose installation and install if necessary
echo "Verifying Docker Compose installation..."
ssh -i ${SSH_KEY} ${EC2_USER}@${EC2_HOST} "docker-compose --version || (echo 'Docker Compose not found, installing...' && sudo apt-get update && sudo apt-get install -y docker-compose)"

# Step 7: Set permissions for the startup script to be executable
echo "Setting execute permission for the startup script..."
ssh -i ${SSH_KEY} ${EC2_USER}@${EC2_HOST} "chmod +x /home/ubuntu/lavagna-deployment/startup.sh"

# Step 8: Run the startup script on EC2
echo "Running startup script on EC2..."
ssh -i ${SSH_KEY} ${EC2_USER}@${EC2_HOST} "bash /home/ubuntu/lavagna-deployment/startup.sh"

# Step 9: Check if containers are running after deployment
echo "Checking Docker containers on EC2..."
docker_status=$(ssh -i ${SSH_KEY} ${EC2_USER}@${EC2_HOST} "docker ps -q")

# If no containers are running, something went wrong
if [[ -z "$docker_status" ]]; then
    echo "Error: No running containers found on EC2!"
    exit 1
fi

# Step 10: Check if the specific application container (lavagna) is running
echo "Checking if the lavagna container is running..."
lavagna_container=$(ssh -i ${SSH_KEY} ${EC2_USER}@${EC2_HOST} "docker ps -q --filter name=lavagna-app")

if [[ -z "$lavagna_container" ]]; then
    echo "Error: The lavagna container is not running!"
    exit 1
fi

# Step 11: Check the logs for the lavagna container
echo "Checking logs for the lavagna container..."
ssh -i ${SSH_KEY} ${EC2_USER}@${EC2_HOST} "docker logs ${lavagna_container}"

# Confirm deployment success
echo "Deployment Completed Successfully!"
