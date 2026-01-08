#!/bin/bash

#########################################
# Moodle 5.1 Docker Auto-Setup Script
#
# Usage:
#   1. Extract Moodle files to ./moodle/
#   2. Run: ./setup-moodle.sh
#   3. Access: http://localhost:8080
#########################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables (can be customized)
MOODLE_DIR="./moodle"
DB_NAME="moodle"
DB_USER="moodle"
DB_PASSWORD="moodle"
DB_ROOT_PASSWORD="moodle_root_pass"
WWWROOT="http://localhost:8080"
ADMIN_USER="admin"
ADMIN_PASS="Admin123!"
ADMIN_EMAIL="admin@example.com"
SITE_FULLNAME="Moodle Site"
SITE_SHORTNAME="Moodle"

echo -e "${BLUE}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Moodle 5.1 Docker Auto-Setup Script        ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════╝${NC}"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker compose &> /dev/null; then
    echo -e "${RED}Error: Docker Compose is not installed. Please install Docker Compose first.${NC}"
    exit 1
fi

# Check if Moodle directory exists
if [ ! -d "$MOODLE_DIR" ]; then
    echo -e "${RED}Error: Moodle directory not found at $MOODLE_DIR${NC}"
    echo -e "${YELLOW}Please extract your Moodle 5.1 files to ./moodle/ first${NC}"
    exit 1
fi

# Check if Moodle files exist
if [ ! -f "$MOODLE_DIR/version.php" ]; then
    echo -e "${RED}Error: Moodle files not found in $MOODLE_DIR${NC}"
    echo -e "${YELLOW}Please ensure Moodle is properly extracted to ./moodle/${NC}"
    exit 1
fi

# Check if public directory exists (Moodle 5.1+)
if [ ! -d "$MOODLE_DIR/public" ]; then
    echo -e "${RED}Error: public directory not found. This script is for Moodle 5.1+${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites check passed${NC}"
echo ""

# Ask user if they want to customize settings
echo -e "${YELLOW}Do you want to customize the installation settings? (y/n)${NC}"
read -r customize

if [ "$customize" = "y" ] || [ "$customize" = "Y" ]; then
    echo ""
    echo -e "${BLUE}Enter custom values (press Enter to use defaults):${NC}"

    read -p "Database name [$DB_NAME]: " input
    DB_NAME=${input:-$DB_NAME}

    read -p "Database user [$DB_USER]: " input
    DB_USER=${input:-$DB_USER}

    read -sp "Database password [$DB_PASSWORD]: " input
    echo ""
    DB_PASSWORD=${input:-$DB_PASSWORD}

    read -sp "Database root password [$DB_ROOT_PASSWORD]: " input
    echo ""
    DB_ROOT_PASSWORD=${input:-$DB_ROOT_PASSWORD}

    read -p "Site URL [$WWWROOT]: " input
    WWWROOT=${input:-$WWWROOT}

    read -p "Admin username [$ADMIN_USER]: " input
    ADMIN_USER=${input:-$ADMIN_USER}

    read -sp "Admin password [$ADMIN_PASS]: " input
    echo ""
    ADMIN_PASS=${input:-$ADMIN_PASS}

    read -p "Admin email [$ADMIN_EMAIL]: " input
    ADMIN_EMAIL=${input:-$ADMIN_EMAIL}

    read -p "Site full name [$SITE_FULLNAME]: " input
    SITE_FULLNAME=${input:-$SITE_FULLNAME}

    read -p "Site short name [$SITE_SHORTNAME]: " input
    SITE_SHORTNAME=${input:-$SITE_SHORTNAME}
fi

echo ""
echo -e "${BLUE}Creating configuration files...${NC}"

# Create docker-compose.yml
cat > docker-compose.yml <<'EOF'
version: '3'
services:
  mariadb:
    image: mariadb:10.11
    container_name: moodle_db
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASSWORD}
      MYSQL_DATABASE: ${DB_NAME}
      MYSQL_USER: ${DB_USER}
      MYSQL_PASSWORD: ${DB_PASSWORD}
    volumes:
      - mariadb_data:/var/lib/mysql
    ports:
      - "3306:3306"
    networks:
      - moodle_network
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

  moodle:
    image: php:8.2-apache
    container_name: moodle_app
    restart: unless-stopped
    ports:
      - "8080:80"
    volumes:
      - ./moodle:/var/www/moodle
      - ./moodle/public:/var/www/html
      - moodledata:/var/moodledata
    depends_on:
      mariadb:
        condition: service_healthy
    networks:
      - moodle_network
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
        chown -R www-data:www-data /var/www/html
        chmod -R 755 /var/www/html

        # Ensure components.json is accessible in web root
        if [ ! -f /var/www/html/lib/components.json ] && [ -f /var/www/moodle/lib/components.json ]; then
            cp /var/www/moodle/lib/components.json /var/www/html/lib/components.json
            chown www-data:www-data /var/www/html/lib/components.json
        fi

        # Create /var/www/lib directory for path resolution
        if [ ! -d /var/www/lib ]; then
            mkdir -p /var/www/lib
        fi

        # Copy components.json
        if [ ! -f /var/www/lib/components.json ]; then
            if [ -f /var/www/html/lib/components.json ]; then
                cp /var/www/html/lib/components.json /var/www/lib/components.json
            elif [ -f /var/www/moodle/lib/components.json ]; then
                cp /var/www/moodle/lib/components.json /var/www/lib/components.json
            fi
            chown www-data:www-data /var/www/lib/components.json 2>/dev/null || true
        fi

        # Copy plugins.json
        if [ ! -f /var/www/lib/plugins.json ]; then
            if [ -f /var/www/html/lib/plugins.json ]; then
                cp /var/www/html/lib/plugins.json /var/www/lib/plugins.json
            elif [ -f /var/www/moodle/lib/plugins.json ]; then
                cp /var/www/moodle/lib/plugins.json /var/www/lib/plugins.json
            fi
            chown www-data:www-data /var/www/lib/plugins.json 2>/dev/null || true
        fi

        # Create symlinks for path resolution
        if [ -e /var/www/html/public ] && [ ! -L /var/www/html/public ]; then
            rm -rf /var/www/html/public
        fi
        if [ ! -e /var/www/html/public ]; then
            cd /var/www/html && ln -sf . public
        fi

        if [ -e /var/www/public ] && [ ! -L /var/www/public ]; then
            rm -rf /var/www/public
        fi
        if [ ! -e /var/www/public ]; then
            ln -sf html /var/www/public
        fi

        # Ensure cache directories exist
        mkdir -p /var/www/html/cache
        chown -R www-data:www-data /var/www/html/cache
        chmod -R 777 /var/www/html/cache

        mkdir -p /var/moodledata
        chown -R www-data:www-data /var/moodledata
        chmod -R 777 /var/moodledata

        echo "Starting Apache..."
        apache2-foreground

networks:
  moodle_network:
    driver: bridge

volumes:
  mariadb_data:
  moodledata:
EOF

echo -e "${GREEN}✓ docker-compose.yml created${NC}"

# Create .env file
cat > .env <<EOF
DB_ROOT_PASSWORD=$DB_ROOT_PASSWORD
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
EOF

echo -e "${GREEN}✓ .env file created${NC}"

# Create main config.php
cat > "$MOODLE_DIR/config.php" <<EOF
<?php
unset(\$CFG);
global \$CFG;
\$CFG = new stdClass();

\$CFG->dbtype    = 'mariadb';
\$CFG->dblibrary = 'native';
\$CFG->dbhost    = 'mariadb';
\$CFG->dbname    = '$DB_NAME';
\$CFG->dbuser    = '$DB_USER';
\$CFG->dbpass    = '$DB_PASSWORD';
\$CFG->prefix    = 'mdl_';
\$CFG->dboptions = array(
    'dbpersist' => false,
    'dbsocket'  => false,
    'dbport'    => '',
    'dbcollation' => 'utf8mb4_unicode_ci',
);

\$CFG->wwwroot   = '$WWWROOT';
\$CFG->dataroot  = '/var/moodledata';
\$CFG->dirroot   = '/var/www/html';
\$CFG->root      = '/var/www/html';
\$CFG->libdir    = '/var/www/html/lib';
\$CFG->cachedir  = '/var/moodledata/cache';
\$CFG->directorypermissions = 02777;
\$CFG->admin = 'admin';

require_once(\$CFG->dirroot . '/lib/setup.php');
EOF

echo -e "${GREEN}✓ Main config.php created${NC}"

# Create or update public/config.php
cat > "$MOODLE_DIR/public/config.php" <<'EOF'
<?php
// This file is part of Moodle - http://moodle.org/
//
// Moodle is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Moodle is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Moodle.  If not, see <http://www.gnu.org/licenses/>.

/**
 * Moodle configuration loader.
 *
 * @package    core
 * @copyright  2024 Andrew Lyons <andrew@nicols.co.uk>
 * @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

// Try to load config from parent directory first, then fallback to moodle root
$configfile = __DIR__ . '/../config.php';
if (!file_exists($configfile)) {
    $configfile = '/var/www/moodle/config.php';
}
if (!file_exists($configfile)) {
    header("Location: install.php");
    die;
}

require($configfile);
EOF

echo -e "${GREEN}✓ Public config.php created${NC}"

# Create installation script
cat > install-moodle.sh <<EOF
#!/bin/bash
echo "Running Moodle installation..."
docker exec -it moodle_app php /var/www/moodle/admin/cli/install.php \\
  --lang=en \\
  --wwwroot=$WWWROOT \\
  --dataroot=/var/moodledata \\
  --dbtype=mariadb \\
  --dbhost=mariadb \\
  --dbname=$DB_NAME \\
  --dbuser=$DB_USER \\
  --dbpass=$DB_PASSWORD \\
  --prefix=mdl_ \\
  --fullname="$SITE_FULLNAME" \\
  --shortname="$SITE_SHORTNAME" \\
  --adminuser=$ADMIN_USER \\
  --adminpass=$ADMIN_PASS \\
  --adminemail=$ADMIN_EMAIL \\
  --agree-license \\
  --non-interactive

if [ \$? -eq 0 ]; then
    echo ""
    echo "✓ Moodle installation completed successfully!"
    echo ""
    echo "Access your Moodle site at: $WWWROOT"
    echo "Username: $ADMIN_USER"
    echo "Password: $ADMIN_PASS"
    echo ""
else
    echo ""
    echo "✗ Installation failed. Please check the logs."
    echo "You can try the web installer at: $WWWROOT/admin/index.php"
fi
EOF

chmod +x install-moodle.sh
echo -e "${GREEN}✓ Installation script created${NC}"

# Create helper scripts
cat > start.sh <<'EOF'
#!/bin/bash
echo "Starting Moodle containers..."
docker compose up -d
echo "Waiting for containers to be ready..."
sleep 5
docker compose ps
echo ""
echo "Moodle is starting up. This may take 2-3 minutes on first run."
echo "Check progress with: docker compose logs -f moodle"
EOF

chmod +x start.sh

cat > stop.sh <<'EOF'
#!/bin/bash
echo "Stopping Moodle containers..."
docker compose down
echo "✓ Containers stopped"
EOF

chmod +x stop.sh

cat > logs.sh <<'EOF'
#!/bin/bash
docker compose logs -f
EOF

chmod +x logs.sh

cat > reset.sh <<'EOF'
#!/bin/bash
echo "WARNING: This will delete ALL data including the database!"
read -p "Are you sure you want to reset everything? (yes/no): " confirm
if [ "$confirm" = "yes" ]; then
    docker compose down -v
    echo "✓ All data has been deleted"
    echo "Run ./start.sh to start fresh"
else
    echo "Reset cancelled"
fi
EOF

chmod +x reset.sh

echo -e "${GREEN}✓ Helper scripts created${NC}"

# Create README
cat > README.md <<EOF
# Moodle Docker Setup

## Quick Start

1. **Start Moodle:**
   \`\`\`bash
   ./start.sh
   \`\`\`

2. **Install Moodle (choose one):**

   **Option A: Automated CLI Installation (Recommended)**
   \`\`\`bash
   ./install-moodle.sh
   \`\`\`

   **Option B: Web Installer**
   Go to: $WWWROOT/admin/index.php

3. **Access Moodle:**
   - URL: $WWWROOT
   - Username: $ADMIN_USER
   - Password: $ADMIN_PASS

## Helper Scripts

- \`./start.sh\` - Start Moodle containers
- \`./stop.sh\` - Stop Moodle containers
- \`./logs.sh\` - View container logs
- \`./install-moodle.sh\` - Run automated installation
- \`./reset.sh\` - Delete all data and start fresh (DANGEROUS!)

## Manual Commands

\`\`\`bash
# View status
docker compose ps

# View logs
docker compose logs -f moodle

# Restart
docker compose restart

# Access Moodle container
docker exec -it moodle_app bash

# Access database
docker exec -it moodle_db mysql -u $DB_USER -p$DB_PASSWORD $DB_NAME

# Clear caches
docker exec -it moodle_app php /var/www/moodle/admin/cli/purge_caches.php

# Run cron
docker exec -it moodle_app php /var/www/moodle/admin/cli/cron.php
\`\`\`

## Configuration

Your installation settings:
- Database Name: $DB_NAME
- Database User: $DB_USER
- Site URL: $WWWROOT
- Admin User: $ADMIN_USER
- Admin Email: $ADMIN_EMAIL

## Troubleshooting

If you encounter issues:

1. Check logs: \`./logs.sh\`
2. Verify containers: \`docker compose ps\`
3. Restart: \`./stop.sh && ./start.sh\`
4. Reset (deletes all data): \`./reset.sh\`

## Files Created

- \`docker-compose.yml\` - Docker configuration
- \`.env\` - Environment variables (passwords)
- \`moodle/config.php\` - Main Moodle configuration
- \`moodle/public/config.php\` - Public directory config loader
- \`*.sh\` - Helper scripts
EOF

echo -e "${GREEN}✓ README.md created${NC}"

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Setup completed successfully!               ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "  1. Start containers:  ${YELLOW}./start.sh${NC}"
echo -e "  2. Wait 2-3 minutes for first-time setup"
echo -e "  3. Install Moodle:    ${YELLOW}./install-moodle.sh${NC}"
echo -e "  4. Access Moodle:     ${YELLOW}$WWWROOT${NC}"
echo ""
echo -e "${BLUE}Credentials:${NC}"
echo -e "  Username: ${YELLOW}$ADMIN_USER${NC}"
echo -e "  Password: ${YELLOW}$ADMIN_PASS${NC}"
echo ""
echo -e "${BLUE}Useful commands:${NC}"
echo -e "  View logs:    ${YELLOW}./logs.sh${NC}"
echo -e "  Stop:         ${YELLOW}./stop.sh${NC}"
echo -e "  Full reset:   ${YELLOW}./reset.sh${NC}"
echo ""
echo -e "See ${YELLOW}README.md${NC} for more information"
echo ""