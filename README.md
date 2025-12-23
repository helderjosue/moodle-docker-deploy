# Moodle Docker Deployment

Docker configuration for deploying Moodle 5.x with MariaDB. Quick setup with docker-compose for development and testing environments.

## Quick Start

1. **Clone this repository**
```bash
   git clone https://github.com/helderjosue/moodle-docker-deploy.git
   cd moodle-docker-deploy
```

2. **Add your Moodle files**
    - Extract Moodle 5.x source files into the `moodle/` directory
    - The structure should be: `moodle/public/`, `moodle/lib/`, etc.

3. **Start the containers**
```bash
   docker compose up -d
```

4. **Access Moodle**
    - Open http://localhost:8080
    - Follow the installation wizard

## What's Included

- **MariaDB 10.11** - Database server
- **PHP 8.2 with Apache** - Web server with required PHP extensions
- **Persistent volumes** - Database and moodledata storage
- **Pre-configured settings** - Ready-to-use config files

## Requirements

- Docker and Docker Compose
- Moodle 5.x source files
- Port 8080 available (or modify in docker-compose.yml)

## Project Structure
```
moodle-docker-deploy/
├── docker-compose.yml
├── moodle/
│   ├── config.php           # Main configuration
│   ├── public/
│   │   └── config.php       # Public config (points to main)
│   ├── lib/
│   └── ...
```

## Default Credentials

- **Database:** moodle / moodle
- **Database Name:** moodle
- **Admin URL:** http://localhost:8080/admin

> ⚠️ **Change these for production use!**

## Complete Setup Guide

For detailed installation instructions, troubleshooting, and configuration options, see:
- **[SETUP_GUIDE.md](SETUP_GUIDE.md)** - Complete step-by-step guide with common issues and solutions

## Useful Commands
```bash
# View logs
docker compose logs -f moodle

# Restart services
docker compose restart

# Stop containers
docker compose down

# Reset everything (deletes all data!)
docker compose down -v
```

## Notes

- First startup takes a few minutes to install PHP extensions
- Local file changes are immediately reflected in the container
- Data persists in Docker volumes