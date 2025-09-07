# E-commerce Application Terraform Deployment

This project provides infrastructure as code (IaC) using Terraform to deploy a Python Flask e-commerce web application to AWS EC2. The application uses the local `app-source/` directory which includes enhanced checkout functionality, and is deployed using a separate deployment script.

## 🏗️ Architecture Overview

- **EC2 Instance**: Amazon Linux 2 instance running the Flask application
- **Security Group**: Configured for SSH (22), HTTP (80), HTTPS (443), and Flask app (5000) access
- **Application Stack**: Python 3, Flask, SQLAlchemy, Nginx (reverse proxy)
- **Automation**: User data script handles complete application setup
- **Monitoring**: Health check scripts and systemd service management

## 📋 Prerequisites

Before deploying, ensure you have:

1. **Terraform** installed (>= 1.0)
   ```bash
   # macOS
   brew install terraform
   
   # Or download from https://terraform.io/downloads.html
   ```

2. **AWS CLI** installed and configured
   ```bash
   # Install AWS CLI
   pip install awscli
   
   # Configure with your credentials
   aws configure
   ```

3. **AWS Account** with appropriate permissions:
   - EC2 instance management
   - Security group management
   - IAM role/policy management
   - VPC access

4. **AWS Key Pair** for EC2 access
   ```bash
   # Create a new key pair (replace 'ecommerce-key' with your preferred name)
   aws ec2 create-key-pair --key-name ecommerce-key --query 'KeyMaterial' --output text > ecommerce-key.pem
   chmod 400 ecommerce-key.pem
   ```

## 🚀 Quick Start

1. **Clone and setup the project** (already done if you're reading this)

2. **Configure variables**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your specific values
   ```

3. **Deploy the infrastructure**:
   ```bash
   ./deploy.sh apply
   ```

4. **Deploy the application**:
   ```bash
   ./deploy-app.sh
   ```

5. **Access your application**:
   - The deployment will output the application URL
   - Access via browser: `http://[instance-ip]:5000`
   - Or via Nginx proxy: `http://[instance-ip]`

## 🔧 Configuration

### Terraform Variables

Edit `terraform.tfvars` to customize your deployment:

```hcl
aws_region          = "us-east-1"                    # AWS region
aws_account_id      = "676206911983"                 # Your AWS account ID
project_name        = "ecommerce-app"                # Project name prefix
environment         = "dev"                          # Environment tag
instance_type       = "t3.micro"                     # EC2 instance type
key_pair_name       = "ecommerce-key"                # Your AWS key pair name
allowed_cidr_blocks = ["0.0.0.0/0"]                  # Restrict for better security
app_port           = 5000                            # Flask application port
# github_repo_url is no longer used - app deployed from local app-source/
```

### Security Considerations

- **Restrict CIDR blocks**: Change `allowed_cidr_blocks` from `["0.0.0.0/0"]` to your specific IP ranges
- **Key pair security**: Ensure your `.pem` key file has proper permissions (400)
- **Instance size**: Start with `t3.micro` (free tier) and scale as needed

## 📦 Deployment Commands

### Two-Step Deployment Process:

**Step 1: Deploy Infrastructure**
```bash
# Plan deployment (see what will be created)
./deploy.sh plan

# Deploy infrastructure
./deploy.sh apply

# Destroy infrastructure
./deploy.sh destroy

# Show help
./deploy.sh help
```

**Step 2: Deploy Application from Local Source**
```bash
# Deploy the Flask app from local app-source/ directory
./deploy-app.sh
```

### Manual Terraform commands:

```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Apply configuration
terraform apply

# Destroy resources
terraform destroy
```

## 🔍 Application Management

Use the provided management script to monitor and control your deployed application:

```bash
# Check application status
./manage-app.sh status

# View application logs
./manage-app.sh logs

# Restart application services
./manage-app.sh restart

# Run health check
./manage-app.sh health

# Show help
./manage-app.sh help
```

## 📊 Outputs

After successful deployment, Terraform will output:

- **instance_id**: EC2 instance identifier
- **instance_public_ip**: Public IP address
- **instance_public_dns**: Public DNS name
- **application_url**: Direct URL to access the Flask app
- **ssh_connection_command**: SSH command to connect to the instance
- **security_group_id**: Security group identifier

## 🗂️ Project Structure

```
ecommerce-terraform-deploy/
├── main.tf                    # Main Terraform configuration
├── variables.tf               # Variable definitions
├── outputs.tf                 # Output definitions
├── terraform.tfvars.example   # Example variable values
├── user-data.sh              # EC2 user data script (infrastructure only)
├── deploy.sh                 # Infrastructure deployment script
├── deploy-app.sh             # Application deployment script
├── manage-app.sh             # Application management script
├── README.md                 # This documentation
├── .gitignore               # Git ignore rules
└── app-source/              # Local e-commerce application with checkout
    ├── unwrap/              # Flask application package
    ├── requirements.txt     # Python dependencies
    ├── run.py              # Application entry point
    └── products.csv        # Sample product data
```

## 🔧 Application Details

### Flask Application Features:
- User registration and authentication
- Product catalog with sample products
- Shopping cart functionality
- **Complete checkout and order confirmation flow**
- SQLite database (SQLAlchemy)
- Bootstrap frontend

### Deployment Features:
- **Systemd Service**: Application runs as a system service
- **Nginx Reverse Proxy**: Professional web server setup
- **Health Monitoring**: Automated health checks
- **Log Management**: Centralized logging with journalctl
- **Auto-restart**: Service automatically restarts on failure

## 🐛 Troubleshooting

### Common Issues:

1. **SSH Key Not Found**:
   ```bash
   # Ensure your key pair exists and has correct permissions
   ls -la *.pem
   chmod 400 your-key-name.pem
   ```

2. **Application Not Starting**:
   ```bash
   # Check logs using the management script
   ./manage-app.sh logs
   
   # Or SSH directly and check
   ssh -i your-key.pem ec2-user@[instance-ip]
   sudo journalctl -u ecommerce-app -f
   ```

3. **Permission Errors**:
   ```bash
   # Make sure scripts are executable
   chmod +x deploy.sh manage-app.sh
   ```

4. **Terraform State Issues**:
   ```bash
   # If state is corrupted, you may need to import resources
   terraform import aws_instance.ecommerce_app [instance-id]
   ```

### Logs Location on EC2:
- Application logs: `sudo journalctl -u ecommerce-app`
- Nginx logs: `/var/log/nginx/error.log`
- Deployment logs: `/var/log/deployment.log`
- Cloud-init logs: `/var/log/cloud-init-output.log`

## 🔄 Updates and Maintenance

### Updating the Application:
1. Modify files in the local `app-source/` directory
2. Run the deployment script: `./deploy-app.sh`
3. The script will copy updated files and restart the application

### Updating Infrastructure:
1. Modify Terraform files as needed
2. Run `./deploy.sh plan` to see changes
3. Run `./deploy.sh apply` to apply changes

## 🏷️ Cost Optimization

- **Instance Type**: Use `t3.micro` for development (free tier eligible)
- **Storage**: Default 20GB encrypted GP3 volume
- **Region**: Choose region closest to your users
- **Scheduling**: Consider using Lambda to start/stop instances on schedule

## 🔒 Security Best Practices

1. **Restrict Access**: Update security group to allow access only from your IP
2. **Key Management**: Store SSH keys securely and rotate regularly
3. **Updates**: Regularly update the EC2 instance and application dependencies
4. **Monitoring**: Consider adding CloudWatch monitoring and alerting
5. **SSL/TLS**: Add HTTPS certificates for production use

## 📚 Additional Resources

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS EC2 User Guide](https://docs.aws.amazon.com/ec2/latest/userguide/)
- [Flask Application Documentation](https://flask.palletsprojects.com/)
- [Original E-commerce App Repository](https://github.com/mujoko/E-commerce-Web-App)

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📄 License

This project is licensed under the MIT License - see the original application repository for details.

---

**Note**: This deployment is configured for development/testing purposes. For production use, consider additional security measures, load balancing, database separation, and monitoring solutions.
