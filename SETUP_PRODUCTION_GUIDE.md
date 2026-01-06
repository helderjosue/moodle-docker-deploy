# Moodle 5.1 Production Deployment Guide

## Full Production Deployment

### 1. Project Structure

```
moodle-docker/
├── .env.production           # Environment variables (DO NOT commit to git)
├── docker-compose.yml        # Local development
├── docker-compose.prod.yml   # Production configuration
├── apache-config/            # Apache virtual host configs
│   └── moodle-ssl.conf
├── ssl/                      # SSL certificates
│   ├── certificate.crt
│   └── private.key
├── backups/                  # Database backups
└── moodle/                   # Your Moodle files
    ├── config.php            # Main config
    └── public/               # Web root
        └── config.php        # Config loader
```

### 2. Production Deployment Steps

#### Step 1: Prepare Environment File

Create `.env.production`:
```bash
cp .env.production.example .env.production
nano .env.production
```

Update with your secure credentials:
```env
DB_ROOT_PASSWORD=YourSecureRootPassword123!
DB_NAME=moodle_prod
DB_USER=moodle_user
DB_PASSWORD=YourSecureDBPassword456!
MOODLE_WWWROOT=https://moodle.yourdomain.com
TZ=Africa/Maputo
```

#### Step 2: Update Production Config

Create `moodle/config.production.php` (use the artifact provided above) or update your existing `config.php` to use environment variables.

#### Step 3: SSL Certificate Setup

**Option A: Let's Encrypt (Recommended)**

```bash
# Install certbot
sudo apt-get update
sudo apt-get install certbot python3-certbot-apache

# Get certificate
sudo certbot certonly --standalone -d moodle.yourdomain.com

# Copy certificates to your project
mkdir -p ssl
sudo cp /etc/letsencrypt/live/moodle.yourdomain.com/fullchain.pem ssl/certificate.crt
sudo cp /etc/letsencrypt/live/moodle.yourdomain.com/privkey.pem ssl/private.key
sudo chmod 644 ssl/*
```

**Option B: Self-Signed (Development/Testing)**

```bash
mkdir -p ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ssl/private.key \
  -out ssl/certificate.crt \
  -subj "/C=MZ/ST=Maputo/L=Maputo/O=YourOrg/CN=moodle.yourdomain.com"
```

#### Step 4: Apache SSL Configuration

Create `apache-config/moodle-ssl.conf`:

```apache
<VirtualHost *:443>
    ServerName moodle.yourdomain.com
    ServerAdmin admin@yourdomain.com
    
    DocumentRoot /var/www/html
    
    <Directory /var/www/html>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    # SSL Configuration
    SSLEngine on
    SSLCertificateFile /etc/apache2/ssl/certificate.crt
    SSLCertificateKeyFile /etc/apache2/ssl/private.key
    
    # Security Headers
    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-XSS-Protection "1; mode=block"
    
    # PHP Configuration
    php_value upload_max_filesize 512M
    php_value post_max_size 512M
    php_value memory_limit 512M
    php_value max_execution_time 300
    
    # Logging
    ErrorLog ${APACHE_LOG_DIR}/moodle_error.log
    CustomLog ${APACHE_LOG_DIR}/moodle_access.log combined
</VirtualHost>

# Redirect HTTP to HTTPS
<VirtualHost *:80>
    ServerName moodle.yourdomain.com
    Redirect permanent / https://moodle.yourdomain.com/
</VirtualHost>
```

#### Step 5: Deploy to Production

```bash
# Stop development environment
docker compose down

# Start production environment
docker compose -f docker-compose.prod.yml --env-file .env.production up -d

# Check logs
docker compose -f docker-compose.prod.yml logs -f moodle

# Wait for "Starting Apache..." message
```

#### Step 6: Configure DNS

Point your domain to your server:
```
Type: A Record
Name: moodle (or @)
Value: YOUR_SERVER_IP
TTL: 3600
```

#### Step 7: Initial Setup

1. Access https://moodle.yourdomain.com
2. Complete Moodle installation wizard
3. Configure site settings
4. Set up users and courses

### 4. Post-Deployment Configuration

#### Enable Cron Jobs (Already configured in prod compose)

The production docker-compose already sets up cron to run every 5 minutes.

Verify it's running:
```bash
docker exec -it moodle_app bash -c "crontab -l -u www-data"
```

#### Database Backups

Create backup script `backup-db.sh`:
```bash
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
docker exec moodle_db mysqldump -u root -p$DB_ROOT_PASSWORD moodle > backups/moodle_backup_$DATE.sql
gzip backups/moodle_backup_$DATE.sql
echo "Backup completed: moodle_backup_$DATE.sql.gz"

# Keep only last 7 days of backups
find backups/ -name "moodle_backup_*.sql.gz" -mtime +7 -delete
```

Make it executable and add to crontab:
```bash
chmod +x backup-db.sh
crontab -e
# Add: 0 2 * * * /path/to/backup-db.sh
```

#### Moodledata Backups

```bash
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
docker run --rm -v moodle-docker_moodledata:/data -v $(pwd)/backups:/backup ubuntu tar czf /backup/moodledata_$DATE.tar.gz /data
echo "Moodledata backup completed: moodledata_$DATE.tar.gz"
```

### 5. Security Checklist

- [ ] SSL/TLS enabled (HTTPS)
- [ ] Strong database passwords
- [ ] Firewall configured (allow only 80, 443, 22)
- [ ] Debug mode disabled (`$CFG->debug = 0`)
- [ ] Regular backups scheduled
- [ ] Cron jobs running
- [ ] File upload limits configured
- [ ] Session timeout configured
- [ ] Security headers enabled
- [ ] `/var/moodledata` is NOT web-accessible
- [ ] Only `/public` directory is web-accessible

### 6. Monitoring

#### Check Container Status
```bash
docker compose -f docker-compose.prod.yml ps
```

#### View Logs
```bash
# All logs
docker compose -f docker-compose.prod.yml logs -f

# Moodle only
docker compose -f docker-compose.prod.yml logs -f moodle

# Database only
docker compose -f docker-compose.prod.yml logs -f mariadb
```

#### Resource Usage
```bash
docker stats
```

### 7. Maintenance Commands

#### Restart Services
```bash
docker compose -f docker-compose.prod.yml restart
```

#### Update Moodle
```bash
# Backup first!
./backup-db.sh

# Update code
cd moodle
git pull origin MOODLE_51_STABLE

# Run upgrade
docker exec -it moodle_app php /var/www/moodle/admin/cli/upgrade.php
```

#### Clear Caches
```bash
docker exec -it moodle_app php /var/www/moodle/admin/cli/purge_caches.php
```

### 8. Troubleshooting

#### Issue: "Failed to open stream" errors

**Solution:** Check that `$CFG->dirroot = '/var/www/moodle'` in your config.php

#### Issue: SSL certificate errors

**Solution:** Ensure certificate files are in correct location and permissions are set:
```bash
chmod 644 ssl/certificate.crt
chmod 644 ssl/private.key
```

#### Issue: Database connection failed

**Solution:** Check database credentials in `.env.production` and ensure MariaDB container is running

#### Issue: File upload fails

**Solution:** Check PHP upload limits and moodledata permissions:
```bash
docker exec -it moodle_app php -i | grep upload_max_filesize
docker exec -it moodle_app ls -la /var/moodledata
```

### 9. Performance Optimization

#### Enable Redis Cache (Optional)

Add to docker-compose.prod.yml:
```yaml
  redis:
    image: redis:7-alpine
    container_name: moodle_redis
    restart: unless-stopped
    networks:
      - moodle_network
```

Update config.php:
```php
$CFG->session_handler_class = '\core\session\redis';
$CFG->session_redis_host = 'redis';
$CFG->session_redis_port = 6379;
```

### 10. Scaling Considerations

For high-traffic sites:
- Use external database server (not Docker)
- Configure load balancer
- Use CDN for static assets
- Enable Redis for sessions and caching
- Increase PHP-FPM workers
- Use external file storage (S3, etc.)

---

## Quick Commands Reference

### Local Development
```bash
# Start
docker compose up -d

# Stop
docker compose down

# View logs
docker compose logs -f moodle

# Restart
docker compose restart moodle
```

### Production
```bash
# Start
docker compose -f docker-compose.prod.yml --env-file .env.production up -d

# Stop
docker compose -f docker-compose.prod.yml down

# View logs
docker compose -f docker-compose.prod.yml logs -f

# Backup
./backup-db.sh

# Update
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
```

---

## Support

For issues or questions:
- Moodle Documentation: https://docs.moodle.org
- Moodle Forums: https://moodle.org/forums
- Email me at: helderjosuemata@gmail.com