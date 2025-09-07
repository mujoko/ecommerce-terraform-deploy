#!/bin/bash

# E-commerce Application Management Script
# Usage: ./manage-app.sh [status|logs|restart|health] [instance-ip]

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

# Get instance IP from Terraform output if not provided
get_instance_ip() {
    if [ -z "$1" ]; then
        if [ -f "terraform.tfstate" ]; then
            terraform output -raw instance_public_ip 2>/dev/null || {
                print_error "Could not get instance IP from Terraform output"
                print_status "Please provide the instance IP as second argument"
                exit 1
            }
        else
            print_error "No Terraform state found and no IP provided"
            print_status "Please provide the instance IP as second argument"
            exit 1
        fi
    else
        echo "$1"
    fi
}

# Check application status
check_status() {
    local instance_ip=$1
    local key_pair=$(terraform output -raw key_pair_name 2>/dev/null || echo "ecommerce-key")
    
    print_status "Checking application status on $instance_ip..."
    
    ssh -i "${key_pair}.pem" -o StrictHostKeyChecking=no ec2-user@$instance_ip << 'EOF'
        echo "=== System Status ==="
        uptime
        echo ""
        
        echo "=== E-commerce App Service Status ==="
        sudo systemctl status ecommerce-app --no-pager || true
        echo ""
        
        echo "=== Nginx Status ==="
        sudo systemctl status nginx --no-pager || true
        echo ""
        
        echo "=== Application Health Check ==="
        if [ -f "/opt/ecommerce-app/health-check.sh" ]; then
            /opt/ecommerce-app/health-check.sh || true
        else
            curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost:5000 || echo "Health check failed"
        fi
        echo ""
        
        echo "=== Disk Usage ==="
        df -h / | tail -1
        echo ""
        
        echo "=== Memory Usage ==="
        free -h
EOF
}

# View application logs
view_logs() {
    local instance_ip=$1
    local key_pair=$(terraform output -raw key_pair_name 2>/dev/null || echo "ecommerce-key")
    
    print_status "Viewing application logs on $instance_ip..."
    
    ssh -i "${key_pair}.pem" -o StrictHostKeyChecking=no ec2-user@$instance_ip << 'EOF'
        echo "=== E-commerce App Service Logs (last 50 lines) ==="
        sudo journalctl -u ecommerce-app -n 50 --no-pager || true
        echo ""
        
        echo "=== Nginx Error Logs (last 20 lines) ==="
        sudo tail -20 /var/log/nginx/error.log 2>/dev/null || echo "No nginx error log found"
        echo ""
        
        echo "=== Deployment Logs ==="
        sudo tail -10 /var/log/deployment.log 2>/dev/null || echo "No deployment log found"
        echo ""
        
        echo "=== Cloud-init Logs (last 20 lines) ==="
        sudo tail -20 /var/log/cloud-init-output.log 2>/dev/null || echo "No cloud-init log found"
EOF
}

# Restart application
restart_app() {
    local instance_ip=$1
    local key_pair=$(terraform output -raw key_pair_name 2>/dev/null || echo "ecommerce-key")
    
    print_status "Restarting application on $instance_ip..."
    
    ssh -i "${key_pair}.pem" -o StrictHostKeyChecking=no ec2-user@$instance_ip << 'EOF'
        echo "Restarting E-commerce application..."
        sudo systemctl restart ecommerce-app
        
        echo "Restarting Nginx..."
        sudo systemctl restart nginx
        
        echo "Waiting for services to start..."
        sleep 5
        
        echo "Checking service status..."
        sudo systemctl is-active ecommerce-app && echo "✓ E-commerce app is running"
        sudo systemctl is-active nginx && echo "✓ Nginx is running"
        
        echo "Running health check..."
        if [ -f "/opt/ecommerce-app/health-check.sh" ]; then
            /opt/ecommerce-app/health-check.sh
        else
            curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost:5000
        fi
EOF
    
    print_success "Application restart completed"
}

# Run health check
health_check() {
    local instance_ip=$1
    local app_port=$(terraform output -raw app_port 2>/dev/null || echo "5000")
    
    print_status "Running health check on $instance_ip:$app_port..."
    
    # Check if application responds
    if curl -s -f "http://$instance_ip:$app_port" > /dev/null; then
        print_success "✓ Application is responding on port $app_port"
    else
        print_error "✗ Application is not responding on port $app_port"
        return 1
    fi
    
    # Check if nginx is serving on port 80
    if curl -s -f "http://$instance_ip" > /dev/null; then
        print_success "✓ Nginx reverse proxy is working on port 80"
    else
        print_warning "⚠ Nginx reverse proxy may not be working on port 80"
    fi
}

# Show help
show_help() {
    echo "E-commerce Application Management Script"
    echo ""
    echo "Usage: $0 [command] [instance-ip]"
    echo ""
    echo "Commands:"
    echo "  status     - Check application and system status"
    echo "  logs       - View application and system logs"
    echo "  restart    - Restart the application services"
    echo "  health     - Run health check on the application"
    echo "  help       - Show this help message"
    echo ""
    echo "Arguments:"
    echo "  instance-ip  - Public IP of the EC2 instance (optional if Terraform state exists)"
    echo ""
    echo "Note: Ensure you have the SSH key file (.pem) in the current directory"
    echo "      and that it matches the key_pair_name in your Terraform configuration"
}

# Main execution
main() {
    local action=${1:-help}
    local instance_ip=$(get_instance_ip "$2")
    
    case $action in
        "status")
            check_status "$instance_ip"
            ;;
        "logs")
            view_logs "$instance_ip"
            ;;
        "restart")
            restart_app "$instance_ip"
            ;;
        "health")
            health_check "$instance_ip"
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
