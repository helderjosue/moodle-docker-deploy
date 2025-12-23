# Moodle 5.x Docker Setup Guide

Complete guide to set up Moodle 5.x with Docker using local Moodle files.

## Prerequisites

- Docker and Docker Compose installed
- Moodle 5.1 source files extracted locally
- Port 8080 available (or use another port)

## Project Structure

```
moodle-docker/
├── docker-compose.yml
└── moodle/              # Your extracted Moodle files
    ├── public/          # Web root for Moodle 5.1
    ├── lib/
    ├── config.php       # Will be created
    └── ...
```

## Step 1: Create docker-compose.yml

Create `docker-compose.yml` in your project directory:

```yaml
version: '3'
services:
  mariadb:
    image: mariadb:10.11
    environment:
      MYSQL_ROOT_PASSWORD: moodle
      MYSQL_DATABASE: moodle
      MYSQL_USER: moodle
      MYSQL_PASSWORD: moodle
    volumes:
      - mariadb_data:/var/lib/mysql
    ports:
      - "3306:3306"
  moodle:
    image: php:8.2-apache
    ports:
      - "8080:80"
    volumes:
      - ./moodle:/var/www/moodle
      - ./moodle/public:/var/www/html
      - moodledata:/var/moodledata
    depends_on:
      - mariadb
    entrypoint: /bin/bash -c
    command:
      - |
        set -e
        echo "Installing PHP extensions..."
        apt-get update
        apt-get install -y libpng-dev libjpeg-dev libzip-dev libicu-dev libxml2-dev libcurl4-openssl-dev libexif-dev
        docker-php-ext-configure gd --with-jpeg
        docker-php-ext-install gd mysqli pdo pdo_mysql zip intl soap opcache exif

        echo "Configuring PHP settings..."
        echo "zend.exception_ignore_args = On" >> /usr/local/etc/php/conf.d/security.ini
        echo "max_input_vars = 5000" >> /usr/local/etc/php/conf.d/moodle.ini

        echo "Setting permissions..."
        chown -R www-data:www-data /var/www/moodle
        chmod -R 755 /var/www/moodle
        mkdir -p /var/moodledata
        chown -R www-data:www-data /var/moodledata
        chmod -R 777 /var/moodledata

        echo "Starting Apache..."
        apache2-foreground
volumes:
  mariadb_data:
  moodledata:
```

## Step 2: Create Main config.php

Create `config.php` in the `moodle/` directory (not in `public/`):

```php
<?php
unset($CFG);
global $CFG;
$CFG = new stdClass();

$CFG->dbtype    = 'mariadb';
$CFG->dblibrary = 'native';
$CFG->dbhost    = 'mariadb';
$CFG->dbname    = 'moodle';
$CFG->dbuser    = 'moodle';
$CFG->dbpass    = 'moodle';
$CFG->prefix    = 'mdl_';
$CFG->dboptions = array(
    'dbpersist' => false,
    'dbsocket'  => false,
    'dbport'    => '',
    'dbcollation' => 'utf8mb4_unicode_ci',
);

$CFG->wwwroot   = 'http://localhost:8080';
$CFG->dataroot  = '/var/moodledata';
$CFG->dirroot   = '/var/www/moodle';
$CFG->libdir    = '/var/www/moodle/lib';
$CFG->directorypermissions = 02777;
$CFG->admin = 'admin';

require_once(__DIR__ . '/lib/setup.php');
```

## Step 3: Update Public config.php

Moodle 5.1 has a `config.php` file in the `public/` directory. Update it to point to the main config:

Edit `moodle/public/config.php`:

```php
<?php
$configfile = '/var/www/moodle/config.php';
if (!file_exists($configfile)) {
    header("Location: install.php");
    die;
}
require($configfile);
```

## Step 4: Start Docker Containers

```bash
cd moodle-docker
docker compose up -d
```

Wait for the containers to start (watch logs with `docker compose logs -f moodle`). You should see "Starting Apache..." at the end.

## Step 5: Access Moodle

Open your browser and go to: **http://localhost:8080**

Follow the Moodle installation wizard to complete the setup.

## Common Issues and Solutions

### Issue 1: Port 3306 Already in Use

**Error:** `Bind on TCP/IP port: Address already in use`

**Solution:** Another MySQL/MariaDB or Docker container is using port 3306.

```bash
# Find what's using the port
sudo lsof -i :3306

# If it's a Docker container
docker ps
docker stop <container_name>

# Or change the port in docker-compose.yml
ports:
  - "3307:3306"  # Use port 3307 instead
```

### Issue 2: PHP Version Error

**Error:** `Moodle 5.1 requires at least PHP 8.2.0`

**Solution:** Ensure you're using `php:8.2-apache` or higher in docker-compose.yml (already included in the config above).

### Issue 3: Config File Not Found

**Error:** `Failed to open stream: No such file or directory config.php`

**Solution:** Ensure both config files exist:
- Main config: `moodle/config.php`
- Public config: `moodle/public/config.php`

The public config must use the absolute path `/var/www/moodle/config.php`.

### Issue 4: Permission Denied Errors

**Error:** Permission errors when accessing files

**Solution:**
```bash
docker exec -it moodle-docker-moodle-1 bash -c "chown -R www-data:www-data /var/www/moodle"
docker exec -it moodle-docker-moodle-1 bash -c "chmod -R 777 /var/moodledata"
```

### Issue 5: Components.json Not Found

**Error:** `file_get_contents(/var/www/lib/components.json): Failed to open stream`

**Solution:** This happens when `$CFG->dirroot` and `$CFG->libdir` are not set correctly. Ensure they point to `/var/www/moodle` and `/var/www/moodle/lib` respectively in your main config.php.

## Useful Commands

```bash
# View container status
docker compose ps

# View logs
docker compose logs -f moodle

# Restart containers
docker compose restart

# Stop containers
docker compose down

# Rebuild containers (if you change docker-compose.yml)
docker compose down
docker compose up -d --build

# Access container shell
docker exec -it moodle-docker-moodle-1 bash

# Check PHP version
docker exec -it moodle-docker-moodle-1 php -v
```

## Database Connection from Host

If you need to connect to the database from your host machine (e.g., using MySQL Workbench):

```
Host: localhost
Port: 3306
User: moodle
Password: moodle
Database: moodle
```

## Changing System MySQL Port

If you have system MySQL running and want it to use a different port:

```bash
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
```

Change or add:
```
port = 3307
```

Then restart MySQL:
```bash
sudo systemctl restart mysql
```

## Notes

- Any changes to local Moodle files are immediately reflected in the container
- The first startup takes a few minutes to install PHP extensions
- Database and moodledata are persisted in Docker volumes
- To reset everything: `docker compose down -v` (this deletes all data!)

## Security Reminders

For production use:
1. Change all default passwords
2. Use proper SSL/TLS certificates
3. Restrict database access
4. Use environment variables for sensitive data
5. Regular backups of database and moodledata volumes