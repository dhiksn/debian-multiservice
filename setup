#!/bin/bash

# =====================================================
# Script: Multi-Service Installer for Debian
# Author: TechCorp
# Description: Install and configure Apache2, vsftpd, OpenSSH, and WordPress
# =====================================================

# Warna untuk tampilan
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Fungsi untuk logging
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

# Fungsi untuk menampilkan banner
show_banner() {
    echo -e "${BLUE}${BOLD}"
    cat << "EOF"
â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•— â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—â–ˆâ–ˆâ•—  â–ˆâ–ˆâ•— â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•— â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•— â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•— â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•— 
â•šâ•â•â–ˆâ–ˆâ•”â•â•â•â–ˆâ–ˆâ•”â•â•â•â•â•â–ˆâ–ˆâ•”â•â•â•â•â•â–ˆâ–ˆâ•‘  â–ˆâ–ˆâ•‘â–ˆâ–ˆâ•”â•â•â•â•â•â–ˆâ–ˆâ•”â•â•â•â–ˆâ–ˆâ•—â–ˆâ–ˆâ•”â•â•â–ˆâ–ˆâ•—â–ˆâ–ˆâ•”â•â•â–ˆâ–ˆâ•—
   â–ˆâ–ˆâ•‘   â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—  â–ˆâ–ˆâ•‘     â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•‘â–ˆâ–ˆâ•‘     â–ˆâ–ˆâ•‘   â–ˆâ–ˆâ•‘â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•”â•â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•”â•
   â–ˆâ–ˆâ•‘   â–ˆâ–ˆâ•”â•â•â•  â–ˆâ–ˆâ•‘     â–ˆâ–ˆâ•”â•â•â–ˆâ–ˆâ•‘â–ˆâ–ˆâ•‘     â–ˆâ–ˆâ•‘   â–ˆâ–ˆâ•‘â–ˆâ–ˆâ•”â•â•â–ˆâ–ˆâ•—â–ˆâ–ˆâ•”â•â•â•â• 
   â–ˆâ–ˆâ•‘   â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—â•šâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—â–ˆâ–ˆâ•‘  â–ˆâ–ˆâ•‘â•šâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—â•šâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•”â•â–ˆâ–ˆâ•‘  â–ˆâ–ˆâ•‘â–ˆâ–ˆâ•‘ 
   â•šâ•â•   â•šâ•â•â•â•â•â•â• â•šâ•â•â•â•â•â•â•šâ•â•  â•šâ•â• â•šâ•â•â•â•â•â• â•šâ•â•â•â•â•â• â•šâ•â•  â•šâ•â•â•šâ•â• 
EOF
    echo -e "${NC}"
    echo -e "${CYAN}${BOLD}====================================================================${NC}"
    echo -e "${YELLOW}${BOLD}           Multi-Service Installer | Apache2 + vsftpd + OpenSSH${NC}"
    echo -e "${CYAN}${BOLD}====================================================================${NC}"
    echo ""
}

# Fungsi untuk mengecek root privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Script ini harus dijalankan sebagai root!"
        exit 1
    fi
}

# Fungsi untuk update system
update_system() {
    log_step "Mengupdate sistem..."
    apt update -y
    apt upgrade -y
    apt autoremove -y
    apt autoclean
    log_info "Update sistem selesai"
}

# Fungsi untuk install Apache2
install_apache() {
    log_step "Menginstall Apache2 Web Server..."
    apt install apache2 -y
    
    systemctl enable apache2
    systemctl start apache2
    
    log_info "Membuat halaman web custom..."
    cat > /var/www/html/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TechCorp - Solusi Teknologi Terpercaya</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            max-width: 1200px;
            width: 100%;
            overflow: hidden;
            animation: fadeIn 0.5s ease-in;
        }
        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(-20px); }
            to { opacity: 1; transform: translateY(0); }
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px;
            text-align: center;
        }
        .header h1 {
            font-size: 3em;
            margin-bottom: 10px;
        }
        .header p {
            font-size: 1.2em;
            opacity: 0.9;
        }
        .content {
            padding: 40px;
        }
        .services {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin: 30px 0;
        }
        .service-card {
            background: #f7f7f7;
            padding: 25px;
            border-radius: 10px;
            text-align: center;
            transition: transform 0.3s;
        }
        .service-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 5px 20px rgba(0,0,0,0.1);
        }
        .service-card h3 {
            color: #667eea;
            margin-bottom: 15px;
        }
        .contact {
            background: #f7f7f7;
            padding: 30px;
            border-radius: 10px;
            margin-top: 30px;
            text-align: center;
        }
        .contact h3 {
            color: #667eea;
            margin-bottom: 15px;
        }
        footer {
            background: #333;
            color: white;
            text-align: center;
            padding: 20px;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>TechCorp</h1>
            <p>Solusi Teknologi Inovatif untuk Masa Depan</p>
        </div>
        <div class="content">
            <h2>Tentang Kami</h2>
            <p style="margin: 20px 0; line-height: 1.6;">
                TechCorp adalah perusahaan teknologi terkemuka yang menyediakan solusi digital komprehensif 
                untuk bisnis modern. Dengan pengalaman lebih dari 10 tahun, kami telah membantu ribuan klien 
                mengubah ide menjadi realitas digital.
            </p>
            
            <h2>Layanan Kami</h2>
            <div class="services">
                <div class="service-card">
                    <h3>Web Development</h3>
                    <p>Membangun website modern, responsif, dan scalable dengan teknologi terbaru.</p>
                </div>
                <div class="service-card">
                    <h3>Cybersecurity</h3>
                    <p>Perlindungan sistem dan data dari ancaman siber dengan solusi keamanan terbaik.</p>
                </div>
                <div class="service-card">
                    <h3>Network Solutions</h3>
                    <p>Infrastruktur jaringan yang handal dan aman untuk mendukung operasional bisnis.</p>
                </div>
            </div>
            
            <div class="contact">
                <h3>Hubungi Kami</h3>
                <p>Email: info@techcorp.com</p>
                <p>Telepon: (021) 1234-5678</p>
                <p>Alamat: Jl. Teknologi No. 123, Jakarta Selatan</p>
            </div>
        </div>
        <footer>
            <p>&copy; 2024 TechCorp. All rights reserved. | Powered by Apache2 on Debian</p>
        </footer>
    </div>
</body>
</html>
HTMLEOF
    
    chown -R www-data:www-data /var/www/html/
    chmod -R 755 /var/www/html/
    
    log_info "Apache2 berhasil diinstall dan berjalan di port 80"
}

# Fungsi untuk install vsftpd
install_ftp() {
    log_step "Menginstall vsftpd FTP Server..."
    apt install vsftpd -y
    
    cp /etc/vsftpd.conf /etc/vsftpd.conf.bak
    
    cat > /etc/vsftpd.conf << 'FTPEOF'
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
chroot_local_user=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
rsa_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
ssl_enable=NO
pasv_enable=YES
pasv_min_port=30000
pasv_max_port=31000
allow_writeable_chroot=YES
FTPEOF
    
    log_info "Membuat user admin untuk FTP..."
    useradd -m -s /bin/bash admin
    echo "admin:123" | chpasswd
    
    chmod 755 /home/admin
    
    systemctl restart vsftpd
    systemctl enable vsftpd
    
    log_info "vsftpd berhasil dikonfigurasi"
    log_info "User FTP: admin, Password: 123"
}

# Fungsi untuk install SSH Server
install_ssh() {
    log_step "Menginstall dan mengkonfigurasi OpenSSH Server..."
    apt install openssh-server -y
    
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    
    cat > /etc/ssh/sshd_config << 'SSHEOF'
Port 22
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
LoginGraceTime 2m
PermitRootLogin no
StrictModes yes
MaxAuthTries 6
MaxSessions 10
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
AllowUsers admin
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
SSHEOF
    
    mkdir -p /home/admin/.ssh
    chmod 700 /home/admin/.ssh
    
    log_info "Membuat contoh SSH key pair..."
    ssh-keygen -t rsa -b 4096 -f /home/admin/.ssh/id_rsa -N "" -C "admin@techcorp"
    
    cp /home/admin/.ssh/id_rsa.pub /home/admin/.ssh/authorized_keys
    chmod 600 /home/admin/.ssh/authorized_keys
    
    chown -R admin:admin /home/admin/.ssh
    
    systemctl restart sshd
    systemctl enable sshd
    
    log_info "SSH Server berhasil dikonfigurasi dengan key-based authentication"
    log_warning "Password authentication telah dinonaktifkan"
    log_info "Private key disimpan di: /home/admin/.ssh/id_rsa"
}

# Fungsi untuk install WordPress
install_wordpress() {
    log_step "Menginstall WordPress..."
    
    apt install php php-mysql php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip -y
    apt install mariadb-server mariadb-client -y
    
    log_info "Mengkonfigurasi database MariaDB..."
    systemctl start mariadb
    systemctl enable mariadb
    
    mysql << 'SQLEOF'
CREATE DATABASE IF NOT EXISTS wordpress;
CREATE USER IF NOT EXISTS 'wpuser'@'localhost' IDENTIFIED BY 'wp123456';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'localhost';
FLUSH PRIVILEGES;
SQLEOF
    
    log_info "Download WordPress..."
    cd /tmp
    wget https://wordpress.org/latest.tar.gz
    tar -xzf latest.tar.gz
    
    mkdir -p /var/www/html/wordpress
    cp -r /tmp/wordpress/* /var/www/html/wordpress/
    
    cp /var/www/html/wordpress/wp-config-sample.php /var/www/html/wordpress/wp-config.php
    sed -i 's/database_name_here/wordpress/g' /var/www/html/wordpress/wp-config.php
    sed -i 's/username_here/wpuser/g' /var/www/html/wordpress/wp-config.php
    sed -i 's/password_here/wp123456/g' /var/www/html/wordpress/wp-config.php
    
    chown -R www-data:www-data /var/www/html/wordpress/
    chmod -R 755 /var/www/html/wordpress/
    
    systemctl restart apache2
    
    rm -rf /tmp/wordpress*
    
    log_info "WordPress berhasil diinstall"
    log_info "Akses WordPress di: http://localhost/wordpress"
    log_info "Database: wordpress | User: wpuser | Password: wp123456"
}

# Fungsi untuk install semua service
install_all() {
    log_step "Memulai instalasi semua service..."
    update_system
    install_apache
    install_ftp
    install_ssh
    install_wordpress
    log_info "Semua service berhasil diinstall!"
    log_info "Apache: http://localhost"
    log_info "FTP: ftp://localhost (user: admin, pass: 123)"
    log_info "SSH: ssh admin@localhost (gunakan private key)"
    log_info "WordPress: http://localhost/wordpress"
}

# Fungsi untuk menampilkan menu utama
show_menu() {
    echo ""
    echo -e "${YELLOW}${BOLD}========================================${NC}"
    echo -e "${YELLOW}${BOLD}           MENU INSTALASI              ${NC}"
    echo -e "${YELLOW}${BOLD}========================================${NC}"
    echo -e "${CYAN} 1.${NC} Install Semua Service"
    echo -e "${CYAN} 2.${NC} Install Apache2 (Web Server)"
    echo -e "${CYAN} 3.${NC} Install FTP (vsftpd)"
    echo -e "${CYAN} 4.${NC} Install SSH (Secure Server)"
    echo -e "${CYAN} 5.${NC} Install WordPress (Optional)"
    echo -e "${CYAN} 6.${NC} Exit"
    echo ""
    echo -ne "${GREEN}Pilih menu (1-6): ${NC}"
}

# ==================== MAIN PROGRAM ====================

check_root

while true; do
    show_banner
    show_menu
    read choice
    
    case $choice in
        1)
            echo ""
            install_all
            ;;
        2)
            echo ""
            install_apache
            ;;
        3)
            echo ""
            install_ftp
            ;;
        4)
            echo ""
            install_ssh
            ;;
        5)
            echo ""
            install_wordpress
            ;;
        6)
            echo ""
            log_info "Terima kasih telah menggunakan TechCorp Multi-Service Installer!"
            echo -e "${GREEN}Script by TechCorp - All rights reserved${NC}"
            exit 0
            ;;
        *)
            log_error "Pilihan tidak valid! Silakan pilih 1-6"
            sleep 2
            ;;
    esac
    
    echo ""
    read -p "Tekan Enter untuk kembali ke menu utama..."
done