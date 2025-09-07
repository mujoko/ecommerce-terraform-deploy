#!/bin/bash

# Update system packages
yum update -y

# Install required packages
yum install -y python3 python3-pip git nginx

# Create application directory
mkdir -p /opt/ecommerce-app
cd /opt/ecommerce-app

# Prepare application directory (app will be deployed separately)
mkdir -p app
cd app

# Install common Python packages
pip3 install Flask Flask-SQLAlchemy Flask-Bcrypt Flask-Login Flask-WTF WTForms

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
Environment=DD_SERVICE=ecommerce-flask-app
Environment=DD_ENV=dev
Environment=DD_VERSION=1.0.0
ExecStart=/home/ec2-user/.local/bin/ddtrace-run python3 run.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF


# --- Datadog Agent install ---
DD_API_KEY="${dd_api_key}" DD_SITE="${dd_site}" \
bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script_agent7.sh)"

# Enable core features (APM, logs, process); set useful tags
sudo tee /etc/datadog-agent/datadog.yaml >/dev/null <<'YAML'
api_key: __API_KEY__
site: __SITE__

tags:
  - env:dev
  - app:ecommerce
  - team:partner-demo

apm_config:
  enabled: true

logs_config:
  logs_enabled: true

process_config:
  enabled: "true"
  process_collection:
    enabled: true
YAML

# Configure log collection for Nginx and Flask app
sudo tee /etc/datadog-agent/conf.d/nginx.d/conf.yaml >/dev/null <<'YAML'
logs:
  - type: file
    path: /var/log/nginx/access.log
    service: nginx
    source: nginx
    sourcecategory: http_web_access
    tags:
      - env:dev
      - app:ecommerce
  - type: file
    path: /var/log/nginx/error.log
    service: nginx
    source: nginx
    sourcecategory: http_web_error
    tags:
      - env:dev
      - app:ecommerce
YAML

# Configure log collection for Flask application
sudo tee /etc/datadog-agent/conf.d/flask.d/conf.yaml >/dev/null <<'YAML'
logs:
  - type: journald
    source: flask
    service: ecommerce-flask-app
    include_units:
      - ecommerce-app.service
    tags:
      - env:dev
      - app:ecommerce
  - type: journald
    source: flask-db-init
    service: ecommerce-flask-app
    include_units:
      - init-ecommerce-db.service
    tags:
      - env:dev
      - app:ecommerce
      - component:database
YAML

# replace placeholders safely
sudo sed -i "s/__API_KEY__/${dd_api_key}/" /etc/datadog-agent/datadog.yaml
sudo sed -i "s/__SITE__/${dd_site}/" /etc/datadog-agent/datadog.yaml


# Change ownership of application directory
chown -R ec2-user:ec2-user /opt/ecommerce-app

# Wait for app deployment, then initialize database
cd /opt/ecommerce-app/app

# Create database initialization script
cat > init_db.py << 'EOF'
import os
import sys
import csv
from flask import Flask
from flask_sqlalchemy import SQLAlchemy

# Add the app directory to Python path
sys.path.insert(0, '/opt/ecommerce-app/app')

try:
    from unwrap import app, db
    from unwrap.models import Products
    
    with app.app_context():
        print("Creating database tables...")
        db.create_all()
        
        # Clear existing products
        Products.query.delete()
        
        # Add sample products if CSV exists
        csv_file = '/opt/ecommerce-app/app/products.csv'
        if os.path.exists(csv_file):
            print("Loading sample products from CSV...")
            with open(csv_file, 'r') as file:
                reader = csv.DictReader(file)
                for row in reader:
                    try:
                        product = Products(
                            name=row['name'],
                            price=int(row['price']),
                            description=row['description'],
                            image='default.jpg'
                        )
                        db.session.add(product)
                    except Exception as e:
                        print(f"Error adding product {row.get('name', 'unknown')}: {e}")
                        continue
        else:
            print("No CSV file found, adding default products...")
            # Add default products if no CSV
            default_products = [
                {"name": "Laptop", "price": 999, "description": "High-performance laptop"},
                {"name": "Smartphone", "price": 599, "description": "Latest smartphone"},
                {"name": "Headphones", "price": 199, "description": "Wireless headphones"},
                {"name": "Tablet", "price": 399, "description": "10-inch tablet"},
                {"name": "Smartwatch", "price": 299, "description": "Fitness smartwatch"}
            ]
            
            for prod in default_products:
                product = Products(
                    name=prod['name'],
                    price=prod['price'],
                    description=prod['description'],
                    image='default.jpg'
                )
                db.session.add(product)
        
        db.session.commit()
        print("Database initialized successfully!")
        
except Exception as e:
    print(f"Database initialization failed: {e}")
    sys.exit(1)
EOF

# Create a service to initialize database after app deployment
cat > /etc/systemd/system/init-ecommerce-db.service << 'EOF'
[Unit]
Description=Initialize E-commerce Database
After=ecommerce-app.service
Requires=ecommerce-app.service

[Service]
Type=oneshot
User=ec2-user
WorkingDirectory=/opt/ecommerce-app/app
ExecStartPre=/bin/sleep 10
ExecStart=/usr/bin/python3 init_db.py
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

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

# Create nginx log directories and set permissions
mkdir -p /var/log/nginx
touch /var/log/nginx/access.log /var/log/nginx/error.log
chown nginx:nginx /var/log/nginx/access.log /var/log/nginx/error.log
chmod 644 /var/log/nginx/access.log /var/log/nginx/error.log

# Create Datadog agent configuration directories
mkdir -p /etc/datadog-agent/conf.d/nginx.d
mkdir -p /etc/datadog-agent/conf.d/flask.d

# Enable and start systemd services
systemctl daemon-reload
systemctl enable ecommerce-app
systemctl enable init-ecommerce-db
# Note: Services will start after app deployment via deploy-app.sh
systemctl enable nginx
systemctl start nginx

# Restart Datadog agent to pick up log configurations
systemctl restart datadog-agent

# Create a simple health check script
cat > /opt/ecommerce-app/health-check.sh << EOF
#!/bin/bash
response=\$(curl -s -o /dev/null -w "%%{http_code}" http://localhost:${app_port})
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
