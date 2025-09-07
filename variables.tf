variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
  default     = "676206911983"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "ecommerce-app"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_pair_name" {
  description = "Name of AWS key pair for EC2 access"
  type        = string
  default     = "ecommerce-key"
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the application"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "app_port" {
  description = "Port on which the Flask application runs"
  type        = number
  default     = 5000
}

variable "github_repo_url" {
  description = "GitHub repository URL for the e-commerce application"
  type        = string
  default     = "https://github.com/mujoko/E-commerce-Web-App.git"
}
