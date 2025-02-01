# Lavagna on AWS – Docker & RDS Integration

This repository contains the source and configuration files for a DevOps project demonstrating the deployment of the [Lavagna](http://lavagna.io) issue/project tracking application on AWS. The project showcases how to build Lavagna from source using Maven, containerize it with Docker (both heavy-weight and lightweight images), and then deploy the application on an EC2 instance with external RDS (MySQL) database support and an Nginx reverse proxy.

## Overview

The project is divided into two major parts:

1. **Local Containerization & Deployment with Docker Compose:**
    - Build Lavagna using Maven.
    - Create Dockerfiles to produce both a heavy-weight (Maven-based) image and a lightweight multi-stage image based on an Alpine JRE.
    - Configure Docker Compose to run three services:
        - Lavagna (Java backend on port 8080),
        - MySQL (for local testing with persistent volume),
        - Nginx (as a reverse proxy for Lavagna on port 80 and to serve static content and documentation on port 8081).
    - Ensure the application waits for the database to be ready before starting.
2. **AWS Integration:**
    - Deploy the Lavagna Docker-based application on an EC2 instance using Docker Compose.
    - Push the Lavagna Docker image to AWS ECR for proper image management.
    - Remove the local MySQL container in favor of an AWS RDS instance running MySQL.
    - Update the application and Docker Compose configurations to point to the RDS endpoint.
    - Use deployment scripts to automate container cleanup, image pulling, and container startup on the EC2 instance.

## Prerequisites

-   **Local Tools:**
    -   Maven (version 3.6.3+ with Java 8)
    -   Docker & Docker Compose
    -   Git
-   **AWS Environment:**
    -   An AWS account with appropriate permissions for EC2, RDS, and ECR.
    -   An Ubuntu-based EC2 instance (e.g., t3a.micro) for deployment.
    -   An RDS instance running MySQL 5.7 (with a database created using `CREATE DATABASE lavagna CHARACTER SET utf8 COLLATE utf8_bin;`).
    -   Security groups configured to allow EC2 access to RDS on port 3306.
-   **Other:**
    -   Your custom Nginx configuration file for reverse proxying and serving static content/documentation.
    -   Deployment and build scripts for automating the process.

## Project Structure
