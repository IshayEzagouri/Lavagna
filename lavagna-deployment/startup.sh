#!/bin/bash
cd /home/ubuntu/lavagna-deployment  # Ensure you're in the correct directory
echo "Stopping old containers..."
docker compose down
echo "Cleaning up old Docker images..."
docker system prune -af
echo "Logging into AWS ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_URI}
echo "Pulling the latest Docker image..."
docker compose pull  # This will pull the image from ECR
echo "Starting the application..."
docker compose up -d
echo "Deployment Completed!"
