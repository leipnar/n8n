#!/bin/bash

# n8n Production Deployment Script
# Automated deployment of n8n with PostgreSQL, Nginx, and SSL
# Compatible with Ubuntu 24.04

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables - MODIFY THESE BEFORE RUNNING
DOMAIN="your-domain.com"  # Replace with your actual domain
N8N_USER="admin"          # Replace with your desired admin username
PROJECT_DIR="/root/n8n-docker"
DB_PASSWORD=$(openssl rand -base64 32)
N8N_PASSWORD=$(openssl rand -base64 24)

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

# Function to wait for service to be ready
wait_for_service() {
    local url=$1
    local max_attempts=60
    local attempt=1
    
    print_status "Waiting for service at $url to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200\|302\|401"; then
            print_success "Service is ready!"
            return 0
        fi
        
        echo -n "."
        sleep 5
        attempt=$((attempt + 1))
    done
    
    print_error "Service did not become ready within expected time"
    return 1
}

# Validation function
validate_config() {
    if [[ "$DOMAIN" == "your-domain.com" ]]; then
        print_error "Please modify the DOMAIN variable at the top of this script before running!"
        print_error "Set DOMAIN to your actual domain name (e.g., 'n8n.yourdomain.com')"
        exit 1
    fi
    
    if [[ "$N8N_USER" == "admin" ]]; then
        print_warning "Using default username 'admin'. Consider changing N8N_USER for better security."
    fi
}

print_status "Starting n8n deployment for $DOMAIN"
print_status "This script will set up a production-ready n8n instance with PostgreSQL and HTTPS"

# Validate configuration
validate_config

# Step 1: System Setup
print_status "Step 1: Updating system and installing prerequisites..."

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

# Install required packages
apt-get install -y \
    curl \
    wget \
    gnupg \
    lsb-release \
    ca-certificates \
    software-properties-common \
    ufw \
    nginx \
    certbot \
    python3-certbot-nginx \
    openssl

print_success "System updated and prerequisites installed"

# Step 2: Firewall Configuration
print_status "Step 2: Configuring UFW firewall..."

# Reset UFW to defaults
ufw --force reset

# Set default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH, HTTP, and HTTPS
ufw allow ssh
ufw allow 'Nginx Full'

# Enable firewall
ufw --force enable

print_success "UFW firewall configured and enabled"

# Step 3: Docker Installation
print_status "Step 3: Installing Docker Engine and Docker Compose..."

# Remove old Docker versions if they exist
apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Add Docker's official GPG key
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Set up Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index and install Docker
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker service
systemctl start docker
systemctl enable docker

# Verify Docker installation
docker --version
docker compose version

print_success "Docker Engine and Docker Compose installed successfully"

# Step 4: Docker Configuration
print_status "Step 4: Setting up Docker configuration..."

# Create project directory
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Create .env file with secrets
cat > .env << EOF
# Database Configuration
POSTGRES_DB=n8n
POSTGRES_USER=n8n
POSTGRES_PASSWORD=$DB_PASSWORD

# n8n Configuration
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=$N8N_USER
N8N_BASIC_AUTH_PASSWORD=$N8N_PASSWORD
N8N_HOST=$DOMAIN
N8N_PORT=5678
N8N_PROTOCOL=https
WEBHOOK_URL=https://$DOMAIN/

# Database Connection
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=postgres
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_DATABASE=n8n
DB_POSTGRESDB_USER=n8n
DB_POSTGRESDB_PASSWORD=$DB_PASSWORD

# Disable user management via email
N8N_USER_MANAGEMENT_DISABLED=true
N8N_PERSONALIZATION_ENABLED=false
EOF

# Create docker-compose.yml file
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15
    restart: unless-stopped
    environment:
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - n8n_network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5

  n8n:
    image: n8nio/n8n:latest
    restart: unless-stopped
    ports:
      - "127.0.0.1:5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=${N8N_BASIC_AUTH_ACTIVE}
      - N8N_BASIC_AUTH_USER=${N8N_BASIC_AUTH_USER}
      - N8N_BASIC_AUTH_PASSWORD=${N8N_BASIC_AUTH_PASSWORD}
      - N8N_HOST=${N8N_HOST}
      - N8N_PORT=${N8N_PORT}
      - N8N_PROTOCOL=${N8N_PROTOCOL}
      - WEBHOOK_URL=${WEBHOOK_URL}
      - DB_TYPE=${DB_TYPE}
      - DB_POSTGRESDB_HOST=${DB_POSTGRESDB_HOST}
      - DB_POSTGRESDB_PORT=${DB_POSTGRESDB_PORT}
      - DB_POSTGRESDB_DATABASE=${DB_POSTGRESDB_DATABASE}
      - DB_POSTGRESDB_USER=${DB_POSTGRESDB_USER}
      - DB_POSTGRESDB_PASSWORD=${DB_POSTGRESDB_PASSWORD}
      - N8N_USER_MANAGEMENT_DISABLED=${N8N_USER_MANAGEMENT_DISABLED}
      - N8N_PERSONALIZATION_ENABLED=${N8N_PERSONALIZATION_ENABLED}
    volumes:
      - n8n_data:/home/node/.n8n
    networks:
      - n8n_network
    depends_on:
      postgres:
        condition: service_healthy

networks:
  n8n_network:
    driver: bridge

volumes:
  postgres_data:
    driver: local
  n8n_data:
    driver: local
EOF

print_success "Docker configuration files created"

# Step 5: Start Docker Services
print_status "Step 5: Starting Docker services..."

# Start services in detached mode
docker compose up -d

# Wait for services to be healthy
print_status "Waiting for database to be ready..."
sleep 10

# Check if containers are running
if ! docker compose ps | grep -q "Up"; then
    print_error "Docker containers failed to start properly"
    docker compose logs
    exit 1
fi

print_success "Docker services started successfully"

# Step 6: Nginx Configuration (HTTP first)
print_status "Step 6: Configuring Nginx reverse proxy..."

# Remove default Nginx site
rm -f /etc/nginx/sites-enabled/default

# Create initial HTTP-only configuration
cat > /etc/nginx/sites-available/n8n << EOF
server {
    listen 80;
    server_name $DOMAIN;

    client_max_body_size 50M;

    location / {
        proxy_pass http://127.0.0.1:5678;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeout settings
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

# Enable the site
ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/

# Test Nginx configuration
nginx -t

# Reload Nginx
systemctl reload nginx

print_success "Nginx HTTP configuration applied"

# Wait for n8n to be ready before SSL setup
print_status "Waiting for n8n to be fully ready..."
wait_for_service "http://127.0.0.1:5678"

# Step 7: SSL Configuration with Certbot
print_status "Step 7: Setting up SSL certificate with Let's Encrypt..."

print_warning "Make sure your domain $DOMAIN points to this server's IP address"
print_status "Attempting to obtain SSL certificate..."

# Obtain SSL certificate and automatically configure Nginx
if certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email --redirect; then
    print_success "SSL certificate obtained and Nginx configured for HTTPS"
else
    print_error "Failed to obtain SSL certificate"
    print_warning "You can manually run: certbot --nginx -d $DOMAIN"
fi

# Test Nginx configuration again after SSL setup
nginx -t
systemctl reload nginx

print_success "SSL configuration completed"

# Final verification
print_status "Performing final verification..."

# Check if containers are still running
if docker compose ps | grep -q "Up"; then
    print_success "All Docker containers are running"
else
    print_warning "Some Docker containers may not be running properly"
    docker compose ps
fi

# Check if Nginx is running
if systemctl is-active --quiet nginx; then
    print_success "Nginx is running"
else
    print_error "Nginx is not running properly"
fi

print_success "=== n8n Deployment Complete ==="
echo ""
echo -e "${GREEN}🎉 Your n8n instance is now ready!${NC}"
echo ""
echo -e "${BLUE}Access Information:${NC}"
echo -e "URL: ${GREEN}https://$DOMAIN${NC}"
echo -e "Username: ${GREEN}$N8N_USER${NC}"
echo -e "Password: ${GREEN}$N8N_PASSWORD${NC}"
echo ""
echo -e "${YELLOW}Important Notes:${NC}"
echo "• Save your credentials securely - they are also stored in $PROJECT_DIR/.env"
echo "• Your data is persisted in Docker volumes"
echo "• SSL certificate will auto-renew via systemd timer"
echo "• Firewall (UFW) is active - only SSH, HTTP, and HTTPS are allowed"
echo ""
echo -e "${BLUE}Management Commands:${NC}"
echo "• View logs: cd $PROJECT_DIR && docker compose logs -f"
echo "• Restart services: cd $PROJECT_DIR && docker compose restart"
echo "• Update n8n: cd $PROJECT_DIR && docker compose pull && docker compose up -d"
echo ""
echo -e "${GREEN}Deployment completed successfully!${NC}"
