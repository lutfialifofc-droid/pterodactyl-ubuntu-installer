#!/usr/bin/env bash

# ==============================================================================
# Pterodactyl Auto-Installer for Ubuntu 24.04 LTS
# GitHub: https://github.com/pterodactyl/panel
# Target OS: Ubuntu 24.04 LTS (Noble Numbat)
# Architecture: x86_64, aarch64 (ARM64)
# Components: Panel, Wings, MariaDB, Redis, Nginx, PHP 8.3, Docker, Certbot SSL
# ==============================================================================

set -o pipefail

# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

LOG_FILE="/var/log/pterodactyl-installer.log"

# Helpers
log_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" >> "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1" >> "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $1" >> "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" >> "$LOG_FILE"
}

# Safe input reading that works both interactively and via curl piping
prompt_read() {
    local prompt_text="$1"
    local var_name="$2"
    if [ -t 0 ]; then
        read -rp "$prompt_text" "$var_name"
    elif [ -e /dev/tty ]; then
        read -rp "$prompt_text" "$var_name" < /dev/tty
    else
        read -rp "$prompt_text" "$var_name"
    fi
}

print_banner() {
    clear
    echo -e "${BLUE}${BOLD}"
    cat << "EOF"
  ____  _                      _            _             _ 
 |  _ \| |_ ___ _ __ ___   __| | __ _  ___| |_ _   _ ___| |
 | |_) | __/ _ \ '__/ _ \ / _` |/ _` |/ __| __| | | / __| |
 |  __/| ||  __/ | | (_) | (_| | (_| | (__| |_| |_| \__ \_|
 |_|    \__\___|_|  \___/ \__,_|\__,_|\___|\__|\__, |___(_)
                                               |___/        
      Pterodactyl Auto-Installer - Ubuntu 24.04 LTS
EOF
    echo -e "${NC}"
}

check_environment() {
    log_info "Verifying system compatibility..."
    
    # Check Root
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root (or via sudo)."
        exit 1
    fi

    # Check OS
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [ "$ID" != "ubuntu" ]; then
            log_warning "This script is tailored specifically for Ubuntu. Detected: $PRETTY_NAME"
            prompt_read "Do you wish to proceed anyway? (y/N): " confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                exit 1
            fi
        elif [ "$VERSION_ID" != "24.04" ]; then
            log_warning "Detected Ubuntu version $VERSION_ID. This script is optimized for 24.04 LTS."
            prompt_read "Proceed anyway? (y/N): " confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    else
        log_error "Unable to verify operating system (/etc/os-release not found)."
        exit 1
    fi

    # Check architecture
    ARCH=$(uname -m)
    if [ "$ARCH" != "x86_64" ] && [ "$ARCH" != "aarch64" ]; then
        log_error "Unsupported CPU architecture: $ARCH (Requires x86_64 or aarch64/arm64)"
        exit 1
    fi

    touch "$LOG_FILE"
    log_success "System compatibility check passed ($PRETTY_NAME on $ARCH)."
}

generate_password() {
    head /dev/urandom | tr -dc A-Za-z0-9 | head -c 24
}

# ------------------------------------------------------------------------------
# PANEL INSTALLATION
# ------------------------------------------------------------------------------
install_panel() {
    print_banner
    log_info "Starting Pterodactyl Panel installation on Ubuntu 24.04 LTS..."

    # Gather user configuration
    echo -e "\n${BOLD}=== Panel Configuration ===${NC}"
    
    prompt_read "Enter Domain / FQDN or Server IP (e.g., panel.example.com or 192.168.1.50): " FQDN
    while [ -z "$FQDN" ]; do
        echo -e "${RED}Domain or IP cannot be empty.${NC}"
        prompt_read "Enter Domain / FQDN or Server IP: " FQDN
    done

    prompt_read "Configure SSL with Let's Encrypt? (Requires valid domain pointing to this IP) (y/N): " USE_SSL
    if [[ "$USE_SSL" =~ ^[Yy]$ ]]; then
        prompt_read "Enter Admin Email for SSL certificate: " SSL_EMAIL
        while [ -z "$SSL_EMAIL" ]; do
            echo -e "${RED}Email cannot be empty when configuring SSL.${NC}"
            prompt_read "Enter Admin Email for SSL: " SSL_EMAIL
        done
        APP_URL="https://${FQDN}"
    else
        APP_URL="http://${FQDN}"
    fi

    prompt_read "Enter Application Timezone [UTC]: " APP_TIMEZONE
    APP_TIMEZONE=${APP_TIMEZONE:-UTC}

    DB_PASS=$(generate_password)
    log_info "Generated random database password: $DB_PASS"

    # Step 1: Install System Dependencies
    log_info "Updating package lists and installing base utilities..."
    apt-get update -y >> "$LOG_FILE" 2>&1
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        software-properties-common curl apt-transport-https ca-certificates \
        gnupg lsb-release tar unzip git nginx certbot python3-certbot-nginx \
        mariadb-server redis-server >> "$LOG_FILE" 2>&1

    # Step 2: Install PHP 8.3 & Extensions
    log_info "Installing PHP 8.3 and required extensions..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        php8.3 php8.3-fpm php8.3-cli php8.3-gd php8.3-mysql php8.3-pdo \
        php8.3-mbstring php8.3-tokenizer php8.3-bcmath php8.3-xml \
        php8.3-curl php8.3-zip php8.3-intl >> "$LOG_FILE" 2>&1

    systemctl enable --now php8.3-fpm >> "$LOG_FILE" 2>&1
    systemctl enable --now redis-server >> "$LOG_FILE" 2>&1
    systemctl enable --now mariadb >> "$LOG_FILE" 2>&1

    # Step 3: Install Composer
    log_info "Installing Composer..."
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer >> "$LOG_FILE" 2>&1

    # Step 4: Configure Database
    log_info "Configuring MariaDB database & user..."
    mariadb -u root <<EOF
CREATE DATABASE IF NOT EXISTS pterodactyl;
CREATE USER IF NOT EXISTS 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON pterodactyl.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

    # Step 5: Download & Extract Pterodactyl Panel
    log_info "Downloading latest Pterodactyl Panel release..."
    mkdir -p /var/www/pterodactyl
    cd /var/www/pterodactyl || exit 1
    curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz >> "$LOG_FILE" 2>&1
    tar -xzvf panel.tar.gz >> "$LOG_FILE" 2>&1
    chmod -R 755 storage/* bootstrap/cache/

    # Step 6: Configure Environment
    log_info "Setting up environment configuration (.env)..."
    cp .env.example .env
    
    export COMPOSER_ALLOW_SUPERUSER=1
    composer install --no-dev --optimize-autoloader >> "$LOG_FILE" 2>&1

    php artisan key:generate --force >> "$LOG_FILE" 2>&1

    # Setup database & cache settings directly in .env
    sed -i "s|APP_URL=.*|APP_URL=${APP_URL}|g" .env
    sed -i "s|APP_TIMEZONE=.*|APP_TIMEZONE=${APP_TIMEZONE}|g" .env
    sed -i "s|DB_HOST=.*|DB_HOST=127.0.0.1|g" .env
    sed -i "s|DB_PORT=.*|DB_PORT=3306|g" .env
    sed -i "s|DB_DATABASE=.*|DB_DATABASE=pterodactyl|g" .env
    sed -i "s|DB_USERNAME=.*|DB_USERNAME=pterodactyl|g" .env
    sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=\"${DB_PASS}\"|g" .env
    sed -i "s|CACHE_DRIVER=.*|CACHE_DRIVER=redis|g" .env
    sed -i "s|SESSION_DRIVER=.*|SESSION_DRIVER=redis|g" .env
    sed -i "s|QUEUE_CONNECTION=.*|QUEUE_CONNECTION=redis|g" .env
    sed -i "s|REDIS_HOST=.*|REDIS_HOST=127.0.0.1|g" .env

    # Run Migrations & Base Seeds
    log_info "Running database migrations..."
    php artisan migrate --seed --force >> "$LOG_FILE" 2>&1

    # Create Initial Admin User
    echo -e "\n${BOLD}=== Create Initial Admin User ===${NC}"
    php artisan p:user:make

    # Permissions
    chown -R www-data:www-data /var/www/pterodactyl/*

    # Step 7: Queue Worker Systemd Service
    log_info "Configuring systemd queue worker (pteroq.service)..."
    cat << EOF > /etc/systemd/system/pteroq.service
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now pteroq.service >> "$LOG_FILE" 2>&1

    # Step 8: Cronjob for schedule runner
    log_info "Configuring cron schedule runner..."
    (crontab -l 2>/dev/null | grep -v "artisan schedule:run"; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1") | crontab -

    # Step 9: Configure Nginx
    log_info "Configuring Nginx web server..."
    cat << EOF > /etc/nginx/sites-available/pterodactyl.conf
server {
    listen 80;
    server_name ${FQDN};

    root /var/www/pterodactyl/public;
    index index.html index.htm index.php;
    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    access_log off;
    error_log  /var/log/nginx/pterodactyl.app-error.log error;

    client_max_body_size 100m;
    client_body_timeout 120s;

    sendfile off;

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

    # Enable site, remove default if present
    rm -f /etc/nginx/sites-enabled/default
    ln -sf /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf

    nginx -t >> "$LOG_FILE" 2>&1
    systemctl restart nginx >> "$LOG_FILE" 2>&1

    # Step 10: SSL Setup (optional)
    if [[ "$USE_SSL" =~ ^[Yy]$ ]]; then
        log_info "Acquiring Let's Encrypt SSL certificate via Certbot..."
        certbot --nginx -d "${FQDN}" --non-interactive --agree-tos -m "${SSL_EMAIL}" --redirect >> "$LOG_FILE" 2>&1
        systemctl restart nginx >> "$LOG_FILE" 2>&1
        log_success "SSL Certificate installed successfully!"
    fi

    # Output Summary
    print_banner
    log_success "Pterodactyl Panel has been installed successfully!"
    echo -e "\n${BOLD}================ INSTALLATION DETAILS ================${NC}"
    echo -e "${CYAN}URL:${NC}              $APP_URL"
    echo -e "${CYAN}Database Name:${NC}    pterodactyl"
    echo -e "${CYAN}Database User:${NC}    pterodactyl"
    echo -e "${CYAN}Database Password:${NC}$DB_PASS"
    echo -e "${CYAN}Panel Path:${NC}       /var/www/pterodactyl"
    echo -e "${CYAN}Nginx Config:${NC}     /etc/nginx/sites-available/pterodactyl.conf"
    echo -e "${CYAN}Queue Service:${NC}    pteroq.service"
    echo -e "${CYAN}Install Log:${NC}      $LOG_FILE"
    echo -e "${BOLD}======================================================${NC}\n"
}

# ------------------------------------------------------------------------------
# WINGS (DAEMON) INSTALLATION
# ------------------------------------------------------------------------------
install_wings() {
    print_banner
    log_info "Starting Pterodactyl Wings (Daemon) installation on Ubuntu 24.04 LTS..."

    # Step 1: Install Docker
    log_info "Installing Docker Engine..."
    curl -sSL https://get.docker.com/ | CHANNEL=stable bash >> "$LOG_FILE" 2>&1
    systemctl enable --now docker >> "$LOG_FILE" 2>&1

    # Step 2: Download Wings Binary
    log_info "Downloading Wings daemon binary..."
    mkdir -p /etc/pterodactyl
    ARCH=$(uname -m)
    if [ "$ARCH" == "x86_64" ]; then
        WINGS_ARCH="amd64"
    else
        WINGS_ARCH="arm64"
    fi

    curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_${WINGS_ARCH}" >> "$LOG_FILE" 2>&1
    chmod u+x /usr/local/bin/wings

    # Step 3: Create systemd unit file
    log_info "Creating systemd service for Wings..."
    cat << EOF > /etc/systemd/system/wings.service
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service
PartOf=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable wings >> "$LOG_FILE" 2>&1

    print_banner
    log_success "Wings daemon binary and service installed successfully!"
    echo -e "\n${BOLD}================ NEXT STEPS FOR WINGS ================${NC}"
    echo -e "1. Open your Pterodactyl Panel Web UI."
    echo -e "2. Go to ${CYAN}Admin Area -> Nodes -> Create New${NC}."
    echo -e "3. Once created, click on the node and open the ${CYAN}'Configuration'${NC} tab."
    echo -e "4. Copy the YAML config or use the 'Auto-Deploy' token command, or paste content to:"
    echo -e "   ${YELLOW}/etc/pterodactyl/config.yml${NC}"
    echo -e "5. Start wings using:"
    echo -e "   ${GREEN}systemctl start wings${NC}"
    echo -e "   Check status with: ${GREEN}systemctl status wings${NC}"
    echo -e "${BOLD}======================================================${NC}\n"
}

# ------------------------------------------------------------------------------
# UPDATE EXISTING PANEL
# ------------------------------------------------------------------------------
update_panel() {
    print_banner
    log_info "Updating Pterodactyl Panel..."

    if [ ! -d "/var/www/pterodactyl" ]; then
        log_error "/var/www/pterodactyl directory not found! Is Panel installed?"
        exit 1
    fi

    cd /var/www/pterodactyl || exit 1
    php artisan down
    curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz >> "$LOG_FILE" 2>&1
    tar -xzvf panel.tar.gz >> "$LOG_FILE" 2>&1
    chmod -R 755 storage/* bootstrap/cache/

    export COMPOSER_ALLOW_SUPERUSER=1
    composer install --no-dev --optimize-autoloader >> "$LOG_FILE" 2>&1
    php artisan view:clear
    php artisan config:clear
    php artisan migrate --seed --force >> "$LOG_FILE" 2>&1
    chown -R www-data:www-data /var/www/pterodactyl/*
    php artisan queue:restart
    php artisan up

    log_success "Pterodactyl Panel successfully updated!"
}

# ------------------------------------------------------------------------------
# MAIN MENU
# ------------------------------------------------------------------------------
main_menu() {
    print_banner
    check_environment

    echo -e "${BOLD}Please choose an option:${NC}\n"
    echo -e "  [1] Install Pterodactyl Panel"
    echo -e "  [2] Install Wings (Daemon)"
    echo -e "  [3] Install Both (Panel + Wings on this VPS)"
    echo -e "  [4] Update Existing Panel"
    echo -e "  [0] Exit"
    echo ""
    prompt_read "Enter choice [0-4]: " CHOICE

    case "$CHOICE" in
        1)
            install_panel
            ;;
        2)
            install_wings
            ;;
        3)
            install_panel
            install_wings
            ;;
        4)
            update_panel
            ;;
        0)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option selected.${NC}"
            exit 1
            ;;
    esac
}

main_menu
