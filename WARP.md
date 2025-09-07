# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

This is an **Infrastructure as Code (IaC)** project that deploys a Flask e-commerce web application to AWS using Terraform. The project consists of two main components:

1. **Terraform Infrastructure** - AWS deployment configuration (EC2, Security Groups, etc.)
2. **Flask E-commerce App** - A Python web application with shopping cart functionality

### Architecture

The deployment creates:
- **EC2 Instance**: Amazon Linux 2 running the Flask application
- **Security Groups**: SSH (22), HTTP (80), HTTPS (443), Flask app (5000)
- **Application Stack**: Python 3, Flask, SQLAlchemy, Nginx (reverse proxy)
- **Database**: SQLite with User, Products, and Cart models
- **Service Management**: systemd service with auto-restart capabilities

The Flask app is cloned from https://github.com/mujoko/E-commerce-Web-App.git during EC2 deployment.

## Common Commands

### Infrastructure Deployment

```bash
# Quick deployment using the wrapper script
./deploy.sh apply

# Plan deployment (see what will be created)
./deploy.sh plan

# Destroy infrastructure
./deploy.sh destroy

# Manual Terraform commands
terraform init
terraform plan
terraform apply
terraform destroy
```

### Application Management

```bash
# Check application status
./manage-app.sh status

# View application logs
./manage-app.sh logs

# Restart application services
./manage-app.sh restart

# Run health check
./manage-app.sh health
```

### Local Development (Flask App)

```bash
# Install dependencies
pip3 install -r app-source/requirements.txt

# Run locally
cd app-source
python run.py
```

### SSH Access to Deployed Instance

```bash
# SSH to deployed EC2 instance
ssh -i <key-pair-name>.pem ec2-user@<instance-ip>

# Check service status on instance
sudo systemctl status ecommerce-app
sudo journalctl -u ecommerce-app -f
```

## Key Files and Their Purposes

### Terraform Configuration
- `main.tf` - Primary infrastructure definitions (EC2, Security Groups, IAM)
- `variables.tf` - All configurable parameters
- `outputs.tf` - Deployment outputs (IP, SSH commands, URLs)
- `user-data.sh` - EC2 initialization script that installs and configures the app

### Deployment Scripts
- `deploy.sh` - Main deployment wrapper with error checking and colored output
- `manage-app.sh` - Remote application management via SSH
- `terraform.tfvars.example` - Template for configuration values

### Flask Application (`app-source/`)
- `run.py` - Application entry point
- `unwrap/__init__.py` - Flask app initialization, database config
- `unwrap/models.py` - SQLAlchemy models (User, Products, Cart)
- `unwrap/routes.py` - All Flask routes and business logic
- `unwrap/forms.py` - WTForms for user input validation
- `requirements.txt` - Python dependencies

## Configuration

### Required Setup Before Deployment

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** installed (>= 1.0)
3. **AWS Key Pair** created for EC2 access
4. **terraform.tfvars** file configured from example

### Critical Configuration Values

The most important variables to configure in `terraform.tfvars`:

```hcl
key_pair_name       = "your-actual-key-pair"  # MUST match existing AWS key pair
allowed_cidr_blocks = ["your.ip.address/32"]  # Security: restrict access
aws_region          = "us-east-1"             # Choose appropriate region
instance_type       = "t3.micro"              # Free tier eligible
```

## Development Patterns

### Flask Application Architecture

The Flask app follows a modular structure:
- **Models**: SQLAlchemy ORM with User authentication and shopping cart functionality
- **Routes**: Clean separation of concerns with login required decorators
- **Templates**: Jinja2 templates with Bootstrap styling
- **Forms**: WTForms with validation

### Deployment Flow

1. **terraform.tfvars** configuration drives infrastructure parameters
2. **user-data.sh** handles complete application setup during EC2 boot
3. **systemd service** manages Flask app with auto-restart
4. **Nginx reverse proxy** provides production-ready web serving

### Key Infrastructure Patterns

- Uses **data sources** to find default VPC and AMI
- **IAM roles** prepared for future CloudWatch integration  
- **Security groups** with specific port configurations
- **Encrypted storage** with GP3 volumes for performance

## Troubleshooting

### Common Issues and Solutions

**Application not starting**:
```bash
./manage-app.sh logs
# Or SSH and check:
sudo journalctl -u ecommerce-app -f
```

**SSH key issues**:
```bash
chmod 400 your-key.pem
# Ensure key_pair_name matches actual AWS key pair
```

**Terraform state issues**:
```bash
# Import existing resources if needed
terraform import aws_instance.ecommerce_app [instance-id]
```

### Log Locations on EC2

- Application logs: `sudo journalctl -u ecommerce-app`
- Nginx logs: `/var/log/nginx/error.log`
- Deployment logs: `/var/log/deployment.log`
- Cloud-init logs: `/var/log/cloud-init-output.log`

## Security Considerations

- **Restrict CIDR blocks** in security groups (don't use 0.0.0.0/0 in production)
- **Manage SSH keys** securely with proper permissions (400)
- **Database**: Currently uses SQLite; consider RDS for production
- **HTTPS**: Add SSL certificates for production deployment
- **Secrets**: Flask secret key is hardcoded (should use AWS Secrets Manager)

## Production Readiness Notes

This is configured for development/testing. For production:
- Add load balancing (ALB)
- Separate database (RDS)
- Add CloudWatch monitoring
- Implement proper secret management
- Add auto-scaling groups
- Configure HTTPS with certificates
