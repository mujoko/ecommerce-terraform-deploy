#!/bin/bash

# Update system packages
yum update -y

# Install required packages
yum install -y python3 python3-pip git nginx

# Create application directory
mkdir -p /opt/ecommerce-app
cd /opt/ecommerce-app

# Clone the e-commerce application
git clone ${github_repo_url} app
cd app

# Install Python dependencies
pip3 install -r requirements.txt

# Create systemd service for the Flask application
cat > /etc/systemd/system/ecommerce-app.service << EOF
[Unit]
Description=E-commerce Flask Application
After=network.target

[Service]
Type=simple
User=ec2-user
Group=ec2-user
WorkingDirectory=/opt/ecommerce-app/app
Environment=FLASK_APP=run.py
Environment=FLASK_ENV=production
ExecStart=/usr/bin/python3 run.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Change ownership of application directory
chown -R ec2-user:ec2-user /opt/ecommerce-app

# Configure Flask app to run on all interfaces
cd /opt/ecommerce-app/app
cat > run_production.py << EOF
from unwrap import app

if __name__ == '__main__':
    app.run(debug=False, host='0.0.0.0', port=${app_port})
EOF

# Update systemd service to use production script
sed -i 's/ExecStart=\/usr\/bin\/python3 run.py/ExecStart=\/usr\/bin\/python3 run_production.py/' /etc/systemd/system/ecommerce-app.service

# Configure nginx as reverse proxy (optional)
cat > /etc/nginx/sites-available/ecommerce << EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:${app_port};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Create sites-available and sites-enabled directories if they don't exist
mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled

# Enable the site
ln -sf /etc/nginx/sites-available/ecommerce /etc/nginx/sites-enabled/

# Update nginx main config to include sites-enabled
if ! grep -q "include /etc/nginx/sites-enabled" /etc/nginx/nginx.conf; then
    sed -i '/include \/etc\/nginx\/conf.d/a\    include /etc/nginx/sites-enabled/*;' /etc/nginx/nginx.conf
fi

# Start and enable services
systemctl daemon-reload
systemctl enable ecommerce-app
systemctl start ecommerce-app
systemctl enable nginx
systemctl start nginx

# Create a simple health check script
cat > /opt/ecommerce-app/health-check.sh << EOF
#!/bin/bash
response=\$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${app_port})
if [ \$response -eq 200 ]; then
    echo "Application is healthy"
    exit 0
else
    echo "Application is not responding"
    exit 1
fi
EOF

chmod +x /opt/ecommerce-app/health-check.sh

# Log deployment completion
echo "E-commerce application deployment completed at \$(date)" >> /var/log/deployment.log

# Display status in cloud-init logs
systemctl status ecommerce-app
