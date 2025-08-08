# n8n Production Deployment Script

A fully automated bash script to deploy a production-ready n8n instance on Ubuntu 24.04 with PostgreSQL database, Nginx reverse proxy, and SSL encryption.

## 🚀 Features

- **Single Command Deployment**: Copy, paste, and run - no manual configuration required
- **Production Ready**: PostgreSQL database, SSL/HTTPS, firewall configuration
- **Security Focused**: UFW firewall, basic auth, secure password generation
- **Docker Based**: Uses Docker Compose for easy management and updates
- **Low Resource Optimized**: Designed for VPS instances with limited resources
- **Auto SSL**: Let's Encrypt certificate with automatic renewal

## 📋 Prerequisites

- **VPS/Server**: Ubuntu 24.04 (fresh installation recommended)
- **Domain**: A domain name pointing to your server's IP address
- **Resources**: Minimum 1GB RAM, 1 CPU core (4GB+ recommended)
- **Access**: Root or sudo access to the server

## ⚡ Quick Start

1. **Configure the script**: Edit the configuration variables at the top of `n8n-deploy.sh`:
   ```bash
   DOMAIN="your-domain.com"  # Replace with your actual domain
   N8N_USER="admin"          # Replace with your desired admin username
   ```

2. **Make the script executable**:
   ```bash
   chmod +x n8n-deploy.sh
   ```

3. **Run the deployment**:
   ```bash
   sudo ./n8n-deploy.sh
   ```

4. **Access your n8n instance**: Once completed, visit `https://your-domain.com` and log in with the credentials displayed at the end of the installation.

## 🔧 What the Script Does

### System Setup
- Updates Ubuntu packages to latest versions
- Installs prerequisites: curl, wget, nginx, certbot, etc.

### Security Configuration
- Configures UFW firewall (allows only SSH, HTTP, HTTPS)
- Generates secure random passwords for database and n8n admin

### Docker Installation
- Installs latest Docker Engine and Docker Compose plugin
- Configures Docker to start on boot

### Application Deployment
- Creates Docker Compose configuration with PostgreSQL and n8n
- Sets up persistent volumes for data storage
- Configures n8n with basic authentication (email registration disabled)

### Reverse Proxy & SSL
- Configures Nginx as reverse proxy on the host system
- Obtains Let's Encrypt SSL certificate automatically
- Sets up HTTPS redirect and proper security headers

## 📁 Directory Structure

After deployment, the following structure is created:

```
/root/n8n-docker/
├── docker-compose.yml    # Docker services configuration
├── .env                  # Environment variables and secrets
└── (Docker volumes for data persistence)
```

## 🛠️ Management Commands

After deployment, you can manage your n8n instance with these commands:

```bash
# Navigate to project directory
cd /root/n8n-docker

# View logs
docker compose logs -f

# Restart services
docker compose restart

# Stop services
docker compose down

# Start services
docker compose up -d

# Update n8n to latest version
docker compose pull
docker compose up -d
```

## 🔐 Security Features

- **Firewall**: UFW configured to allow only necessary ports
- **Basic Authentication**: Username/password protection
- **SSL/TLS**: HTTPS encryption with Let's Encrypt certificates
- **User Management**: Email-based registration disabled
- **Database**: PostgreSQL with secure password generation
- **Network Isolation**: Docker containers on isolated network

## 🔄 Updating n8n

To update n8n to the latest version:

```bash
cd /root/n8n-docker
docker compose pull n8n
docker compose up -d
```

## 🗄️ Data Backup

Your n8n data is stored in Docker volumes. To backup:

```bash
# Backup n8n data
docker run --rm -v n8n-docker_n8n_data:/data -v $(pwd):/backup ubuntu tar czf /backup/n8n-backup.tar.gz -C /data .

# Backup PostgreSQL data
docker run --rm -v n8n-docker_postgres_data:/data -v $(pwd):/backup ubuntu tar czf /backup/postgres-backup.tar.gz -C /data .
```

## 🆘 Troubleshooting

### SSL Certificate Issues
If SSL certificate generation fails:
```bash
# Manually obtain certificate
sudo certbot --nginx -d your-domain.com

# Check certificate status
sudo certbot certificates
```

### Container Issues
```bash
# Check container status
cd /root/n8n-docker
docker compose ps

# View detailed logs
docker compose logs n8n
docker compose logs postgres
```

### Firewall Issues
```bash
# Check firewall status
sudo ufw status

# Allow additional ports if needed
sudo ufw allow [port]
```

## 🔧 Customization

### Changing Configuration
Edit the `.env` file in `/root/n8n-docker/` to modify:
- Admin credentials
- Database settings
- n8n configuration options

After changes, restart services:
```bash
docker compose restart
```

### Resource Limits
To add resource limits, edit `docker-compose.yml`:
```yaml
services:
  n8n:
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M
```

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## ⚠️ Disclaimer

This script is provided as-is. Always review and test scripts before running them on production systems. Make sure to backup any existing data before deployment.

## 🆘 Support

If you encounter issues:

1. Check the troubleshooting section above
2. Review the Docker and Nginx logs
3. Open an issue in this repository with detailed error information

## 📚 Additional Resources

- [n8n Documentation](https://docs.n8n.io/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Nginx Documentation](https://nginx.org/en/docs/)
