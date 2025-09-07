#!/bin/bash

# Deploy local app-source to EC2 instance
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Starting app deployment...${NC}"

# Get the EC2 instance IP from Terraform output
INSTANCE_IP=$(terraform output -raw instance_public_ip 2>/dev/null)
if [ -z "$INSTANCE_IP" ]; then
    echo -e "${RED}Error: Could not get instance IP. Make sure infrastructure is deployed.${NC}"
    exit 1
fi

echo -e "${YELLOW}Deploying to instance: $INSTANCE_IP${NC}"

# Check if SSH key exists
SSH_KEY="./ecommerce-key.pem"
if [ ! -f "$SSH_KEY" ]; then
    echo -e "${RED}Error: SSH key not found at $SSH_KEY${NC}"
    exit 1
fi

# Wait for instance to be ready
echo -e "${YELLOW}Waiting for instance to be ready...${NC}"
sleep 30

# Copy app-source to EC2 instance
echo -e "${YELLOW}Copying app-source files...${NC}"
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no -r app-source/* ec2-user@$INSTANCE_IP:/tmp/

# Connect to instance and deploy the app
echo -e "${YELLOW}Setting up application on EC2...${NC}"
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ec2-user@$INSTANCE_IP << 'EOF'
    # Stop the existing service if running
    sudo systemctl stop ecommerce-app || true
    
    # Remove old app and copy new one
    sudo rm -rf /opt/ecommerce-app/app
    sudo mkdir -p /opt/ecommerce-app/app
    sudo cp -r /tmp/* /opt/ecommerce-app/app/
    sudo chown -R ec2-user:ec2-user /opt/ecommerce-app/app
    
    # Install dependencies
    cd /opt/ecommerce-app/app
    pip3 install -r requirements.txt --user
    
    # Start the Flask application service
    sudo systemctl start ecommerce-app
    sudo systemctl enable ecommerce-app
    
    # Wait a moment for the app to start
    sleep 5
    
    # Start the database initialization service
    sudo systemctl start init-ecommerce-db
    
    echo "Application deployed successfully!"
EOF

echo -e "${GREEN}App deployment completed!${NC}"
echo -e "${GREEN}Application URL: http://$INSTANCE_IP${NC}"
echo -e "${GREEN}Direct Flask URL: http://$INSTANCE_IP:5000${NC}"
