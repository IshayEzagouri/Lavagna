# #!/bin/bash
# cd /home/ubuntu/lavagna-deployment  # Ensure you're in the correct directory
# echo "Stopping old containers..."
# docker compose down
# echo "Cleaning up old Docker images..."
# docker system prune -af
# echo "Logging into AWS ECR..."
# aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_URI}
# echo "Pulling the latest Docker image..."
# docker compose pull  # This will pull the image from ECR
# echo "Starting the application..."
# docker compose up -d
# echo "Deployment Completed!"


#!/bin/bash
set -e

# --- Source environment variables from .env if available ---
ENV_FILE="/home/ubuntu/lavagna-deployment/.env"
if [ -f "$ENV_FILE" ]; then
    echo "Sourcing environment variables from $ENV_FILE..."
    source "$ENV_FILE"
else
    echo "Warning: $ENV_FILE not found; ensure necessary environment variables are set."
fi

# --- Export AWS/ECR configuration variables ---
# If these variables are not already set in the .env file, use these defaults.
export AWS_REGION=${AWS_REGION:-"ap-south-1"}
export AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-"324037305534"}
export ECR_REPO_NAME=${ECR_REPO_NAME:-"ishay_lavagna_ecr"}
export ECR_URI=${ECR_URI:-"${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"}

echo "AWS_REGION: ${AWS_REGION}"
echo "ECR_URI: ${ECR_URI}"

#  Ensure required DB variables are set
: "${DB_HOST:?DB_HOST not set}"
: "${DB_NAME:?DB_NAME not set}"
: "${DB_USERNAME:?DB_USERNAME not set}"
: "${DB_PASSWORD:?DB_PASSWORD not set}"

# Construct DB_URL if not already set in .env
export DB_URL=${DB_URL:-"jdbc:mysql://${DB_HOST}:3306/${DB_NAME}?autoReconnect=true&useSSL=false"}

# --- Flyway configuration ---
FLYWAY_VERSION="4.2.0"
FLYWAY_INSTALL_DIR="/opt/flyway-${FLYWAY_VERSION}"
FLYWAY_BIN="${FLYWAY_INSTALL_DIR}/flyway"

# --- Function: Install Flyway if not present ---
install_flyway() {
  echo "Flyway not found. Installing Flyway ${FLYWAY_VERSION}..."
  # Download the Flyway tarball
  curl -L -o flyway.tar.gz "https://repo1.maven.org/maven2/org/flywaydb/flyway-commandline/${FLYWAY_VERSION}/flyway-commandline-${FLYWAY_VERSION}-linux-x64.tar.gz"
  # Extract to the desired directory (requires sudo for /opt)
  sudo mkdir -p "${FLYWAY_INSTALL_DIR}"
  sudo tar -xzf flyway.tar.gz --strip-components=1 -C "${FLYWAY_INSTALL_DIR}"
  rm flyway.tar.gz
  # Ensure the flyway binary is executable
  sudo chmod +x "${FLYWAY_BIN}"
  # Add Flyway to PATH for this session
  export PATH="${FLYWAY_INSTALL_DIR}:$PATH"
  echo "Flyway installed at ${FLYWAY_INSTALL_DIR}"
}

# --- Check if Flyway is installed and at the correct version ---
if ! command -v flyway >/dev/null 2>&1; then
  install_flyway
else
  current_flyway_version=$(flyway -v | awk '{print $2}')
  if [ "$current_flyway_version" != "$FLYWAY_VERSION" ]; then
    echo "Installed Flyway version ($current_flyway_version) does not match required version ($FLYWAY_VERSION). Reinstalling..."
    install_flyway
  else
    echo "Flyway ${FLYWAY_VERSION} is already installed."
  fi
fi

# --- Create the database (fresh start for testing) ---
echo "Ensuring database ${DB_NAME} exists on ${DB_HOST}..."
mysql -h "${DB_HOST}" -u "${DB_USERNAME}" -p"${DB_PASSWORD}" -e "DROP DATABASE IF EXISTS ${DB_NAME};"
mysql -h "${DB_HOST}" -u "${DB_USERNAME}" -p"${DB_PASSWORD}" -e "CREATE DATABASE ${DB_NAME} CHARACTER SET utf8 COLLATE utf8_bin;"

# --- Run Flyway migrations ---
echo "Running Flyway migrations..."
flyway -url="${DB_URL}" -user="${DB_USERNAME}" -password="${DB_PASSWORD}" migrate

# --- Proceed with Docker Compose actions ---
cd /home/ubuntu/lavagna-deployment  # Ensure you're in the correct directory

echo "Stopping old containers..."
docker compose down

echo "Cleaning up old Docker images..."
docker system prune -af

echo "Logging into AWS ECR..."
aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${ECR_URI}"

echo "Pulling the latest Docker image..."
docker compose pull  # This will pull the image from ECR

echo "Starting the application..."
docker compose up -d

echo "Deployment Completed!"
