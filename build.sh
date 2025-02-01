#!/bin/bash

# Prompt the user to confirm if they updated the version in docker-compose
echo "Did you make sure you changed the version of the lavagna image in docker-compose to match the version you are trying to build? (y/n)"
read -p "Enter 'y' to continue, or 'n' to exit: " user_response

# If the user didn't type 'y' or 'yes', exit the script
if [[ ! "$user_response" =~ ^[Yy]$ ]]; then
    echo "Exiting the script. Please make sure you updated the version in docker-compose."
    exit 1
fi

# Ensure a tag is provided, else exit with an error
if [ -z "$1" ]; then
  echo "Error: You must provide a tag for the image."
  echo "Usage: ./build.sh <tag>"
  exit 1
else
  IMAGE_TAG="$1"  # Use the provided tag
fi

AWS_REGION="ap-south-1"
AWS_ACCOUNT_ID="324037305534"
ECR_REPO_NAME="ishay_lavagna_ecr"
IMAGE_NAME="lavagna_repo"  # Image name as lavagna_repo
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"

# Step 1: Clean up any old .tar.gz files in the local directory
echo "Cleaning up old .tar.gz files..."
rm -f *.tar.gz && echo "Deleted old .tar.gz files." || echo "No old .tar.gz files to delete."

# Step 2: Prepare the Deployment Directory
echo "Preparing Deployment Directory..."

# Remove any existing lavagna-deployment directory and create the necessary subdirectories
rm -rf lavagna-deployment && echo "Deleted local lavagna-deployment" || echo "Failed to delete lavagna-deployment"
ls -la
mkdir -p lavagna-deployment/nginx lavagna-deployment/src/main lavagna-deployment/target/lavagna

# Copy the necessary deployment files

echo "Copying Deployment Files..."

# Copy .env file to the deployment directory
cp .env lavagna-deployment/.env 

# Copy docker-compose.yaml
cp docker-compose.yaml lavagna-deployment/

# Copy nginx.conf into the nginx directory
mkdir -p lavagna-deployment/nginx
cp nginx/nginx.conf lavagna-deployment/nginx/nginx.conf

# Copy the webapp folder into the appropriate subdirectory
mkdir -p lavagna-deployment/src/main  # Ensure the parent directories exist
cp -r src/main/webapp lavagna-deployment/src/main/webapp && echo "Successfully copied webapp into lavagna-deployment/src/main/webapp" || echo "Failed to copy webapp"

# Copy the help folder into the target subdirectory
mkdir -p lavagna-deployment/target/lavagna  # Ensure the parent directories exist
cp -r target/lavagna/help lavagna-deployment/target/lavagna/help && echo "Successfully copied target/lavagna/help into lavagna-deployment/target/lavagna/help" || echo "Failed to copy help"

# Copy the startup.sh script into the lavagna-deployment directory
echo "Copying startup.sh script..."
cp startup.sh lavagna-deployment/  # Copy the startup.sh script to the deployment folder

# Step 3: Check if the image already exists locally
echo "Checking if the image with tag ${IMAGE_TAG} exists locally..."
image_exists_local=$(docker images -q ${IMAGE_NAME}:${IMAGE_TAG})

# Step 4: Check if the image exists in ECR and handle error gracefully
echo "Checking if the image with tag ${IMAGE_TAG} exists in ECR..."

# Query for the image in ECR
image_exists_ecr=$(aws ecr describe-images --repository-name ${ECR_REPO_NAME} --region ${AWS_REGION} --query "imageDetails[?contains(imageTags, '${IMAGE_TAG}')].imageTags" --output text)

# If the image exists in either location, skip build
if [[ "$image_exists_ecr" == "$IMAGE_TAG" ]]; then
    echo "Image with tag ${IMAGE_TAG} already exists in ECR. Skipping both build and push."
elif [[ -n "$image_exists_local" && -z "$image_exists_ecr" ]]; then
    # If image exists locally but not in ECR, skip build but push to ECR
    echo "Image with tag ${IMAGE_TAG} exists locally but not in ECR. Skipping build and pushing to ECR..."
    
    # Tag and push to ECR
    docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ECR_URI}:${IMAGE_TAG}
    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_URI}
    docker push ${ECR_URI}:${IMAGE_TAG}
else
    # Step 5: If image does not exist locally or in ECR, build and push
    echo "Image with tag ${IMAGE_TAG} does not exist locally or in ECR. Building and pushing image..."
    docker build --platform linux/amd64 -t ${IMAGE_NAME}:${IMAGE_TAG} .  # Build for amd64 architecture
    docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ECR_URI}:${IMAGE_TAG}
    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_URI}
    docker push ${ECR_URI}:${IMAGE_TAG}
fi


# Step 6: Create the deployment package
echo "Creating Deployment Package..."
tar -czvf lavagna-startup-package_${IMAGE_TAG}.tar.gz -C lavagna-deployment .

echo "Build Completed! Deployment package is ready: lavagna-startup-package_${IMAGE_TAG}.tar.gz"
