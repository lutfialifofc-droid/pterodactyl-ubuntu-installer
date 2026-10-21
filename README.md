<div align="center">

# 🚀 Pterodactyl Auto-Installer

**Automated, one-command installer for Pterodactyl Panel & Wings daemon on Ubuntu 24.04 LTS (Noble Numbat).**

[![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04%20LTS-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)](https://ubuntu.com)
[![PHP](https://img.shields.io/badge/PHP-8.3-777BB4?style=for-the-badge&logo=php&logoColor=white)](https://www.php.net)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)](LICENSE)

</div>

---

## ⚡ Quick Start (One-Liner)

Run this single command on your clean **Ubuntu 24.04 LTS** VPS with `root` privileges:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/YOUR_REPO_NAME/main/install.sh)
```

> [!NOTE]
> Replace `YOUR_GITHUB_USERNAME/YOUR_REPO_NAME` with your actual GitHub repository name once pushed.

---

## 📋 Features

- 🎯 **Tailored for Ubuntu 24.04 LTS**: Native PHP 8.3 extensions and packages pre-configured out-of-the-box.
- 🔒 **Automated Database Security**: Automatic MariaDB creation with cryptographic password generation.
- ⚡ **Redis & Queue Automation**: Configures Redis cache and manages background queue workers via `pteroq.service`.
- 🌐 **Nginx & Let's Encrypt SSL**: Automatic Nginx virtual host setup with optional Certbot SSL certificate acquisition.
- 🐳 **Docker & Wings Ready**: Installs official Docker CE and installs/registers the `wings.service` systemd daemon.
- 🔄 **Safe Panel Upgrades**: Built-in option to update existing Pterodactyl panel installations seamlessly.
- 💻 **Cross-Architecture**: Compatible with both `x86_64` (Intel/AMD) and `aarch64` (ARM64, e.g. Oracle Cloud Ampere).

---

## 🖥️ Interactive Menu Preview

When launched, you are greeted with an interactive CLI menu:

```text
  ____  _                      _            _             _ 
 |  _ \| |_ ___ _ __ ___   __| | __ _  ___| |_ _   _ ___| |
 | |_) | __/ _ \ '__/ _ \ / _` |/ _` |/ __| __| | | / __| |
 |  __/| ||  __/ | | (_) | (_| | (_| | (__| |_| |_| \__ \_|
 |_|    \__\___|_|  \___/ \__,_|\__,_|\___|\__|\__, |___(_)
                                               |___/        
      Pterodactyl Auto-Installer - Ubuntu 24.04 LTS

Please choose an option:

  [1] Install Pterodactyl Panel
  [2] Install Wings (Daemon)
  [3] Install Both (Panel + Wings on this VPS)
  [4] Update Existing Panel
  [5] Configure / Start Wings
  [6] Troubleshoot / Debug Wings
  [0] Exit
```

---

## 🛠️ Technology Stack Installed

| Component | Software | Role |
| :--- | :--- | :--- |
| **Operating System** | Ubuntu 24.04 LTS | Host Operating System |
| **Web Server** | Nginx | Reverse proxy & web delivery |
| **Runtime** | PHP 8.3 (FPM & CLI) | Laravel backend execution |
| **Database** | MariaDB | Persistent relational database |
| **Cache & Queue** | Redis | Session state & asynchronous queue dispatch |
| **Container Engine**| Docker CE | Game server process isolation |
| **Node Daemon** | Wings (Go) | Node agent communicating with Docker |
| **SSL / TLS** | Certbot | Let's Encrypt certificate automation |

---

## 🛡️ Firewall Configuration (UFW)

Ensure the required ports are accessible before or after installation:

```bash
# Allow HTTP/HTTPS Web Panel access
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow Wings daemon & SFTP
sudo ufw allow 8080/tcp
sudo ufw allow 2022/tcp

# Game Server Allocation Range (Default range example)
sudo ufw allow 25565:25595/tcp
sudo ufw allow 25565:25595/udp

# SSH
sudo ufw allow 22/tcp

# Enable firewall
sudo ufw enable
```

---

## 📦 Manual Installation (Without One-Liner)

If you prefer to download and inspect the script locally before running:

```bash
# 1. Download the script
curl -sSL -o install.sh https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/YOUR_REPO_NAME/main/install.sh

# 2. Make it executable
chmod +x install.sh

# 3. Execute with root privileges
sudo ./install.sh
```

---

## 🚀 Post-Installation: Connecting Wings

After installing **Wings** (Option 2 or 3):
1. Log in to your Pterodactyl Panel web interface.
2. Navigate to **Admin Area** (`/admin`) ➔ **Locations** (ensure at least one location exists, e.g. "Local").
3. Navigate to **Nodes** ➔ **Create New**.
4. Fill in your node details:
   - **FQDN**: Your server domain or IP.
   - **Communicate Over SSL**: Use SSL if you configured Let's Encrypt with a domain; select HTTP if using a bare IP address.
   - **Daemon Port**: `8080`, **Daemon SFTP Port**: `2022`.
5. Click your new node, navigate to the **Configuration** tab.
6. Copy the **Auto-Deploy** command, or copy the YAML content.
7. Either:
   - Run the script again and select **`[5] Configure / Start Wings`** to paste the command interactively, **OR**
   - Run the command directly in your VPS terminal, **OR**
   - Save the YAML to `/etc/pterodactyl/config.yml` and run:
     ```bash
     sudo systemctl enable --now wings
     sudo systemctl status wings
     ```

---

## 🔧 Troubleshooting Wings (`status=1/FAILURE` or Auto-Restart Loop)

If Wings fails to start or shows `Active: activating (auto-restart)`:
1. **Run Option `[6] Troubleshoot / Debug Wings`** directly in `./install.sh` for an automatic health check and log view.
2. **Common Causes**:
   - **Missing Configuration**: Wings cannot run without `/etc/pterodactyl/config.yml`. Do not start Wings until you generate this from the Panel!
   - **Reset Failed Systemd State**: If Wings crashed repeatedly, systemd rate-limits starts. Run:
     ```bash
     sudo systemctl stop wings
     sudo systemctl reset-failed wings
     sudo systemctl start wings
     ```
   - **SSL Mismatch**: If `ssl.enabled: true` in `/etc/pterodactyl/config.yml`, but certificates do not exist in `/etc/letsencrypt/live/...`, Wings will crash. For non-SSL or IP setups, set `enabled: false` under `ssl`.
   - **Check Debug Output**:
     ```bash
     sudo wings --debug
     ```

---

## 🤝 Contributing

Contributions, bug reports, and improvements are welcome! Please review [CONTRIBUTING.md](CONTRIBUTING.md) for details.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
Pterodactyl® is a registered trademark of Dane Everitt and the Pterodactyl project.
