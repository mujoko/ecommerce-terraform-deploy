#!/bin/bash

# E-commerce Application Terraform Deployment Script
# Usage: ./deploy.sh [plan|apply|destroy]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if terraform is installed
check_terraform() {
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install Terraform first."
        exit 1
    fi
    print_success "Terraform is installed: $(terraform version --short)"
}

# Check if AWS CLI is configured
check_aws_config() {
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS CLI is not configured or credentials are invalid."
        print_status "Please run 'aws configure' to set up your credentials."
        exit 1
    fi
    print_success "AWS CLI is configured"
}

# Check if terraform.tfvars exists
check_tfvars() {
    if [ ! -f "terraform.tfvars" ]; then
        print_warning "terraform.tfvars not found. Creating from example..."
        cp terraform.tfvars.example terraform.tfvars
        print_status "Please edit terraform.tfvars with your specific values before proceeding."
        print_status "Especially update the 'key_pair_name' with your actual AWS key pair name."
        exit 1
    fi
    print_success "terraform.tfvars found"
}

# Initialize Terraform
terraform_init() {
    print_status "Initializing Terraform..."
    terraform init
    print_success "Terraform initialized successfully"
}

# Plan Terraform deployment
terraform_plan() {
    print_status "Planning Terraform deployment..."
    terraform plan -out=tfplan
    print_success "Terraform plan completed"
}

# Apply Terraform deployment
terraform_apply() {
    if [ -f "tfplan" ]; then
        print_status "Applying Terraform plan..."
        terraform apply tfplan
        rm -f tfplan
    else
        print_status "Applying Terraform configuration..."
        terraform apply -auto-approve
    fi
    print_success "Terraform apply completed"
    
    # Show outputs
    print_status "Deployment outputs:"
    terraform output
}

# Destroy Terraform deployment
terraform_destroy() {
    print_warning "This will destroy all resources created by this Terraform configuration."
    read -p "Are you sure you want to proceed? (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
        print_status "Destroying Terraform deployment..."
        terraform destroy -auto-approve
        print_success "Terraform destroy completed"
    else
        print_status "Destroy cancelled"
    fi
}

# Show help
show_help() {
    echo "E-commerce Application Terraform Deployment Script"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  plan       - Run terraform plan to see what will be created"
    echo "  apply      - Apply the terraform configuration (deploy infrastructure)"
    echo "  destroy    - Destroy all created resources"
    echo "  help       - Show this help message"
    echo ""
    echo "Before running, ensure you have:"
    echo "  1. Terraform installed"
    echo "  2. AWS CLI configured with valid credentials"
    echo "  3. An AWS key pair created for EC2 access"
    echo "  4. Updated terraform.tfvars with your values"
}

# Main execution
main() {
    local action=${1:-help}
    
    case $action in
        "plan")
            check_terraform
            check_aws_config
            check_tfvars
            terraform_init
            terraform_plan
            ;;
        "apply")
            check_terraform
            check_aws_config
            check_tfvars
            terraform_init
            terraform_plan
            terraform_apply
            ;;
        "destroy")
            check_terraform
            check_aws_config
            terraform_init
            terraform_destroy
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "Unknown command: $action"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
