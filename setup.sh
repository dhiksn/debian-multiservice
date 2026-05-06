#!/bin/bash

# =====================================================
# Script: Multi-Service Installer for Debian
# Author: TechCorp
# Description: Install and configure Apache2, vsftpd, OpenSSH, DNS Server, and WordPress
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

# Variabel global
APACHE_ACCESS_IP=""
DNS_FORWARDERS="8.8.8.8; 8.8.4.4;"
DOMAIN_NAME=""

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

# Fungsi untuk mendapatkan daftar interface dan IP
get_interfaces() {
    ip -o -4 addr show up scope global | awk '{print $2 "|" $4}'
}

# Fungsi untuk memilih IP dari interface
choose_ip() {
    local service_name=$1
    local interfaces=()
    local idx=1
    local choice=""
    
    while IFS= read -r line; do
        interfaces+=("$line")
    done < <(get_interfaces)
    
    if [[ ${#interfaces[@]} -eq 0 ]]; then
        echo "$(hostname -I | awk '{print $1}')"
        return 0
    fi
    
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}Pilih IP Address untuk $service_name:${NC}"
    echo -e "${CYAN}========================================${NC}"
    for line in "${interfaces[@]}"; do
        local iface="${line%%|*}"
        local ip_addr="${line##*|}"
        ip_addr="${ip_addr%%/*}"
        echo -e "  ${YELLOW}${idx}.${NC} $iface -> $ip_addr"
        idx=$((idx + 1))
    done
    
    while true; do
        echo -ne "${GREEN}Pilih interface [1-${#interfaces[@]}] (default 1): ${NC}"
        if ! IFS= read -r choice < /dev/tty; then
            choice=""
        fi
        
        if [[ -z "$choice" ]]; then
            choice=1
        fi
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#interfaces[@]} )); then
            local selected="${interfaces[$((choice - 1))]}"
            local selected_ip="${selected##*|}"
            echo "${selected_ip%%/*}"
            return 0
        fi
        
        log_error "Pilihan tidak valid."
    done
}

# Fungsi untuk mengecek port 80
get_port_80_listener() {
    ss -tulpn 2>/dev/null | awk '/:80[[:space:]]/ && /LISTEN/ {print; exit}'
}

# Fungsi untuk menampilkan banner
show_banner() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo "â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—"
    echo "â•‘                                                                              â•‘"
    echo "â•‘    â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•— â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—â–ˆâ–ˆâ•—  â–ˆâ–ˆâ•— â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•— â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•— â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•— â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—         â•‘"
    echo "â•‘    â•šâ•â•â–ˆâ–ˆâ•”â•â•â•â–ˆâ–ˆâ•”â•â•â•â•â•â–ˆâ–ˆâ•”â•â•â•â•â•â–ˆâ–ˆâ•‘  â–ˆâ–ˆâ•‘â–ˆâ–ˆâ•”â•â•â•â•â•â–ˆâ–ˆâ•”â•â•â•â–ˆâ–ˆâ•—â–ˆâ–ˆâ•”â•â•â–ˆâ–ˆâ•—â–ˆâ–ˆâ•”â•â•â–ˆâ–ˆâ•—        â•‘"
    echo "â•‘       â–ˆâ–ˆâ•‘   â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—  â–ˆâ–ˆâ•‘     â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•‘â–ˆâ–ˆâ•‘     â–ˆâ–ˆâ•‘   â–ˆâ–ˆâ•‘â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•”â•â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•”â•        â•‘"
    echo "â•‘       â–ˆâ–ˆâ•‘   â–ˆâ–ˆâ•”â•â•â•  â–ˆâ–ˆâ•‘     â–ˆâ–ˆâ•”â•â•â–ˆâ–ˆâ•‘â–ˆâ–ˆâ•‘     â–ˆâ–ˆâ•‘   â–ˆâ–ˆâ•‘â–ˆâ–ˆâ•”â•â•â–ˆâ–ˆâ•—â–ˆâ–ˆâ•”â•â•â•â•         â•‘"
    echo "â•‘       â–ˆâ–ˆâ•‘   â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—â•šâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—â–ˆâ–ˆâ•‘  â–ˆâ–ˆâ•‘â•šâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—â•šâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•”â•â–ˆâ–ˆâ•‘  â–ˆâ–ˆâ•‘â–ˆâ–ˆâ•‘             â•‘"
    echo "â•‘       â•šâ•â•   â•šâ•â•â•â•â•â•â• â•šâ•â•â•â•â•â•â•šâ•â•  â•šâ•â• â•šâ•â•â•â•â•â• â•šâ•â•â•â•â•â• â•šâ•â•  â•šâ•â•â•šâ•â•             â•‘"
    echo "â•‘                                                                              â•‘"
    echo "â•‘    â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•— â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•— â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•— â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—                                           â•‘"
    echo "â•‘   â–ˆâ–ˆâ•”â•â•â•â•â•â–ˆâ–ˆâ•”â•â•â•â–ˆâ–ˆâ•—â–ˆâ–ˆâ•”â•â•â–ˆâ–ˆâ•—â–ˆâ–ˆâ•”â•â•â–ˆâ–ˆâ•—                                          â•‘"
    echo "â•‘   â–ˆâ–ˆâ•‘     â–ˆâ–ˆâ•‘   â–ˆâ–ˆâ•‘â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•”â•â–ˆâ–ˆâ•‘  â–ˆâ–ˆâ•‘                                          â•‘"
    echo "â•‘   â–ˆâ–ˆâ•‘     â–ˆâ–ˆâ•‘   â–ˆâ–ˆâ•‘â–ˆâ–ˆâ•”â•â•â–ˆâ–ˆâ•—â–ˆâ–ˆâ•‘  â–ˆâ–ˆâ•‘                                          â•‘"
    echo "â•‘   â•šâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—â•šâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•”â•â–ˆâ–ˆâ•‘  â–ˆâ–ˆâ•‘â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•”â•                                          â•‘"
    echo "â•‘    â•šâ•â•â•â•â•â• â•šâ•â•â•â•â•â• â•šâ•â•  â•šâ•â•â•šâ•â•â•â•â•â•                                           â•‘"
    echo "â•‘                                                                              â•‘"
    echo "â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•"
    echo -e "${NC}"
    echo -e "${CYAN}${BOLD}â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${NC}"
    echo -e "${YELLOW}${BOLD}              Multi-Service Installer | Apache2 + vsftpd + OpenSSH + DNS${NC}"
    echo -e "${CYAN}${BOLD}â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${NC}"
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
    
    if systemctl is-active --quiet apache2 2>/dev/null; then
        log_warning "Apache2 sudah terinstall dan berjalan"
        read -p "Apakah ingin reinstall? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Melewati instalasi Apache2"
            return 0
        fi
    fi
    
    apt install apache2 -y
    
    APACHE_ACCESS_IP=$(choose_ip "Apache2 Web Server")
    
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
            <h1>ðŸ¢ TechCorp</h1>
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
                    <h3>ðŸ’» Web Development</h3>
                    <p>Membangun website modern, responsif, dan scalable dengan teknologi terbaru.</p>
                </div>
                <div class="service-card">
                    <h3>ðŸ”’ Cybersecurity</h3>
                    <p>Perlindungan sistem dan data dari ancaman siber dengan solusi keamanan terbaik.</p>
                </div>
                <div class="service-card">
                    <h3>ðŸŒ Network Solutions</h3>
                    <p>Infrastruktur jaringan yang handal dan aman untuk mendukung operasional bisnis.</p>
                </div>
            </div>
            
            <div class="contact">
                <h3>ðŸ“ž Hubungi Kami</h3>
                <p>Email: info@techcorp.com</p>
                <p>Telepon: (021) 1234-5678</p>
                <p>Alamat: Jl. Teknologi No. 123, Jakarta Selatan</p>
                <p>DNS Server: ns1.techcorp.local</p>
            </div>
        </div>
        <footer>
            <p>&copy; 2025 TechCorp. All rights reserved. | Powered by Apache2 on Debian</p>
        </footer>
    </div>
</body>
</html>
HTMLEOF
    
    chown -R www-data:www-data /var/www/html/
    chmod -R 755 /var/www/html/
    
    cat > /etc/apache2/sites-available/000-default.conf << APACHECONF
<VirtualHost $APACHE_ACCESS_IP:80>
    ServerAdmin webmaster@localhost
    ServerName ${APACHE_ACCESS_IP}
    DocumentRoot /var/www/html
    
    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
APACHECONF
    
    PORT_80_LISTENER="$(get_port_80_listener)"
    if [[ -n "$PORT_80_LISTENER" && "$PORT_80_LISTENER" != *"apache2"* ]]; then
        log_error "Port 80 sudah dipakai proses lain: $PORT_80_LISTENER"
        return 1
    fi
    
    systemctl enable apache2
    systemctl restart apache2
    
    log_info "Apache2 berhasil diinstall dan berjalan di port 80"
    log_info "Apache2 dapat diakses di: http://${APACHE_ACCESS_IP}"
}

# Fungsi untuk install vsftpd
install_ftp() {
    log_step "Menginstall vsftpd FTP Server..."
    
    if systemctl is-active --quiet vsftpd 2>/dev/null; then
        log_warning "vsftpd sudah terinstall dan berjalan"
        read -p "Apakah ingin reinstall? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Melewati instalasi vsftpd"
            return 0
        fi
    fi
    
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
    
    if id "admin" &>/dev/null; then
        log_warning "User admin sudah ada"
        read -p "Reset password admin? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "admin:123" | chpasswd
            log_info "Password admin direset menjadi 123"
        fi
    else
        log_info "Membuat user admin untuk FTP..."
        useradd -m -s /bin/bash admin
        echo "admin:123" | chpasswd
    fi
    
    chmod 755 /home/admin
    
    systemctl restart vsftpd
    systemctl enable vsftpd
    
    FTP_IP=$(choose_ip "FTP Server")
    
    log_info "vsftpd berhasil dikonfigurasi"
    log_info "FTP Server: ftp://${FTP_IP}"
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
    
    if [[ ! -f /home/admin/.ssh/id_rsa ]]; then
        log_info "Membuat contoh SSH key pair..."
        ssh-keygen -t rsa -b 4096 -f /home/admin/.ssh/id_rsa -N "" -C "admin@techcorp"
    fi
    
    cp /home/admin/.ssh/id_rsa.pub /home/admin/.ssh/authorized_keys
    chmod 600 /home/admin/.ssh/authorized_keys
    
    chown -R admin:admin /home/admin/.ssh
    
    systemctl restart sshd
    systemctl enable sshd
    
    SSH_IP=$(choose_ip "SSH Server")
    
    log_info "SSH Server berhasil dikonfigurasi dengan key-based authentication"
    log_warning "Password authentication telah dinonaktifkan"
    log_info "SSH Server: ssh admin@${SSH_IP}"
    log_info "Private key disimpan di: /home/admin/.ssh/id_rsa"
}

# Fungsi untuk install DNS Server (Bind9)
install_dns() {
    log_step "Menginstall DNS Server (Bind9)..."
    
    if systemctl is-active --quiet bind9 2>/dev/null; then
        log_warning "Bind9 sudah terinstall dan berjalan"
        read -p "Apakah ingin reinstall? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Melewati instalasi DNS Server"
            return 0
        fi
    fi
    
    apt install bind9 bind9utils bind9-doc dnsutils -y
    
    DNS_IP=$(choose_ip "DNS Server")
    
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}Masukkan nama domain yang diinginkan${NC}"
    echo -e "${CYAN}Contoh: techcorp.local, mycompany.com${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo -ne "${GREEN}Domain name: ${NC}"
    read -p "" DOMAIN_NAME
    
    if [[ -z "$DOMAIN_NAME" ]]; then
        DOMAIN_NAME="techcorp.local"
        log_info "Menggunakan domain default: $DOMAIN_NAME"
    fi
    
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}Masukkan DNS Forwarders (DNS upstream)${NC}"
    echo -e "${CYAN}Default: 8.8.8.8 8.8.4.4 (Google DNS)${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo -ne "${GREEN}Forwarders (pisahkan dengan spasi): ${NC}"
    read -p "" FORWARDERS_INPUT
    
    if [[ -n "$FORWARDERS_INPUT" ]]; then
        DNS_FORWARDERS=""
        for fwd in $FORWARDERS_INPUT; do
            DNS_FORWARDERS="${DNS_FORWARDERS} ${fwd};"
        done
    fi
    
    cat > /etc/bind/named.conf.options << OPTIONSEOF
options {
    directory "/var/cache/bind";
    
    forwarders {
        $DNS_FORWARDERS
    };
    
    allow-query { any; };
    recursion yes;
    dnssec-validation auto;
    listen-on { $DNS_IP; 127.0.0.1; };
    listen-on-v6 { none; };
    version "DNS Server TechCorp";
    rate-limit {
        responses-per-second 10;
        slip 2;
    };
};
OPTIONSEOF
    
    cat > /etc/bind/named.conf.local << LOCALSEOF
zone "$DOMAIN_NAME" {
    type master;
    file "/etc/bind/db.$DOMAIN_NAME";
    allow-update { none; };
};

REVERSE_IP=\$(echo $DNS_IP | awk -F. '{print \$3"."\$2"."\$1}')
zone "\${REVERSE_IP}.in-addr.arpa" {
    type master;
    file "/etc/bind/db.reverse";
    allow-update { none; };
};
LOCALSEOF
    
    SERIAL=$(date +%Y%m%d%S)
    cat > /etc/bind/db.$DOMAIN_NAME << FORWARDEOF
;
; BIND data file for $DOMAIN_NAME
;
\$TTL    604800
@       IN      SOA     ns1.$DOMAIN_NAME. admin.$DOMAIN_NAME. (
                    $SERIAL     ; Serial
                    604800      ; Refresh
                    86400       ; Retry
                    2419200     ; Expire
                    604800 )    ; Negative Cache TTL
;
@       IN      NS      ns1.$DOMAIN_NAME.
@       IN      A       $DNS_IP
@       IN      MX 10   mail.$DOMAIN_NAME.

ns1     IN      A       $DNS_IP
ns2     IN      A       $DNS_IP
www     IN      A       $DNS_IP
web     IN      A       $DNS_IP
ftp     IN      A       $DNS_IP
mail    IN      A       $DNS_IP
ssh     IN      A       $DNS_IP
wp      IN      A       $DNS_IP
wordpress IN    A       $DNS_IP

files   IN      CNAME   www
dev     IN      CNAME   www
FORWARDEOF
    
    REVERSE_IP=$(echo $DNS_IP | awk -F. '{print $3"."$2"."$1}')
    LAST_OCTET=$(echo $DNS_IP | awk -F. '{print $4}')
    
    cat > /etc/bind/db.reverse << REVERSEEOF
;
; BIND reverse data file for $DOMAIN_NAME
;
\$TTL    604800
@       IN      SOA     ns1.$DOMAIN_NAME. admin.$DOMAIN_NAME. (
                    $SERIAL     ; Serial
                    604800      ; Refresh
                    86400       ; Retry
                    2419200     ; Expire
                    604800 )    ; Negative Cache TTL
;
@       IN      NS      ns1.$DOMAIN_NAME.
$LAST_OCTET     IN      PTR     ns1.$DOMAIN_NAME.
$LAST_OCTET     IN      PTR     www.$DOMAIN_NAME.
$LAST_OCTET     IN      PTR     ftp.$DOMAIN_NAME.
$LAST_OCTET     IN      PTR     mail.$DOMAIN_NAME.
$LAST_OCTET     IN      PTR     ssh.$DOMAIN_NAME.
REVERSEEOF
    
    chown -R bind:bind /etc/bind/
    chmod 644 /etc/bind/db.$DOMAIN_NAME
    chmod 644 /etc/bind/db.reverse
    
    log_info "Memvalidasi konfigurasi DNS..."
    if ! named-checkconf; then
        log_error "Konfigurasi bind9 tidak valid"
        return 1
    fi
    
    if ! named-checkzone $DOMAIN_NAME /etc/bind/db.$DOMAIN_NAME; then
        log_error "Forward zone tidak valid"
        return 1
    fi
    
    systemctl restart bind9
    systemctl enable bind9
    
    cp /etc/resolv.conf /etc/resolv.conf.bak
    cat > /etc/resolv.conf << RESOLVEOF
nameserver $DNS_IP
nameserver 8.8.8.8
search $DOMAIN_NAME
RESOLVEOF
    
    echo ""
    log_info "DNS Server (Bind9) berhasil diinstall dan dikonfigurasi"
    log_info "=========================================="
    log_info "Domain: $DOMAIN_NAME"
    log_info "DNS Server IP: $DNS_IP"
    log_info "Forwarders: $DNS_FORWARDERS"
    log_info "=========================================="
    log_info "Record yang tersedia:"
    log_info "  - ns1.$DOMAIN_NAME -> $DNS_IP"
    log_info "  - www.$DOMAIN_NAME -> $DNS_IP"
    log_info "  - ftp.$DOMAIN_NAME -> $DNS_IP"
    log_info "  - mail.$DOMAIN_NAME -> $DNS_IP"
    log_info "  - ssh.$DOMAIN_NAME -> $DNS_IP"
    log_info "  - wp.$DOMAIN_NAME -> $DNS_IP"
    log_info "=========================================="
    log_info "Testing DNS: dig @$DNS_IP www.$DOMAIN_NAME"
}

# Fungsi untuk install WordPress
install_wordpress() {
    log_step "Menginstall WordPress..."
    
    if ! systemctl is-active --quiet apache2 2>/dev/null; then
        log_error "Apache2 harus diinstall terlebih dahulu sebelum WordPress"
        log_info "Silakan install Apache2 terlebih dahulu (Menu 3)"
        return 1
    fi
    
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
    wget -q https://wordpress.org/latest.tar.gz
    tar -xzf latest.tar.gz
    
    mkdir -p /var/www/html/wordpress
    cp -r /tmp/wordpress/* /var/www/html/wordpress/
    
    cp /var/www/html/wordpress/wp-config-sample.php /var/www/html/wordpress/wp-config.php
    sed -i 's/database_name_here/wordpress/g' /var/www/html/wordpress/wp-config.php
    sed -i 's/username_here/wpuser/g' /var/www/html/wordpress/wp-config.php
    sed -i 's/password_here/wp123456/g' /var/www/html/wordpress/wp-config.php
    
    KEYS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
    if [[ -n "$KEYS" ]]; then
        sed -i "/AUTH_KEY/d" /var/www/html/wordpress/wp-config.php
        sed -i "/SECURE_AUTH_KEY/d" /var/www/html/wordpress/wp-config.php
        sed -i "/LOGGED_IN_KEY/d" /var/www/html/wordpress/wp-config.php
        sed -i "/NONCE_KEY/d" /var/www/html/wordpress/wp-config.php
        sed -i "/AUTH_SALT/d" /var/www/html/wordpress/wp-config.php
        sed -i "/SECURE_AUTH_SALT/d" /var/www/html/wordpress/wp-config.php
        sed -i "/LOGGED_IN_SALT/d" /var/www/html/wordpress/wp-config.php
        sed -i "/NONCE_SALT/d" /var/www/html/wordpress/wp-config.php
        sed -i "/table_prefix/i $KEYS" /var/www/html/wordpress/wp-config.php
    fi
    
    chown -R www-data:www-data /var/www/html/wordpress/
    chmod -R 755 /var/www/html/wordpress/
    
    systemctl restart apache2
    
    rm -rf /tmp/wordpress*
    
    WEB_IP=$(choose_ip "WordPress")
    
    log_info "WordPress berhasil diinstall"
    log_info "Akses WordPress: http://${WEB_IP}/wordpress"
    log_info "Database: wordpress | User: wpuser | Password: wp123456"
}

# Fungsi untuk install semua service (tanpa DNS)
install_all_basic() {
    log_step "Memulai instalasi semua service basic..."
    update_system
    install_apache
    install_ftp
    install_ssh
    install_wordpress
    echo ""
    log_info "=========================================="
    log_info "Semua service basic berhasil diinstall!"
    log_info "=========================================="
    log_info "Apache: http://${APACHE_ACCESS_IP}"
    log_info "FTP: ftp://${APACHE_ACCESS_IP} (user: admin, pass: 123)"
    log_info "SSH: ssh admin@${APACHE_ACCESS_IP} (gunakan private key)"
    log_info "WordPress: http://${APACHE_ACCESS_IP}/wordpress"
    log_info "=========================================="
}

# Fungsi untuk install semua service lengkap dengan DNS
install_all_complete() {
    log_step "Memulai instalasi semua service lengkap dengan DNS..."
    update_system
    install_apache
    install_ftp
    install_ssh
    install_dns
    install_wordpress
    
    echo ""
    log_info "=========================================="
    log_info "SEMUA SERVICE BERHASIL DIINSTALL!"
    log_info "=========================================="
    log_info "Apache: http://${APACHE_ACCESS_IP}"
    log_info "FTP: ftp://${APACHE_ACCESS_IP} (user: admin, pass: 123)"
    log_info "SSH: ssh admin@${APACHE_ACCESS_IP} (gunakan private key)"
    log_info "WordPress: http://${APACHE_ACCESS_IP}/wordpress"
    log_info "=========================================="
    log_info "DNS Server Information:"
    log_info "  DNS Server IP: ${DNS_IP}"
    log_info "  Domain: ${DOMAIN_NAME}"
    log_info "=========================================="
}

# Fungsi untuk menampilkan menu utama
show_menu() {
    echo ""
    echo -e "${YELLOW}${BOLD}========================================${NC}"
    echo -e "${YELLOW}${BOLD}          MENU INSTALASI               ${NC}"
    echo -e "${YELLOW}${BOLD}========================================${NC}"
    echo -e "${GREEN}1.${NC} Install Semua Service (Basic: Apache2 + FTP + SSH + WP)"
    echo -e "${GREEN}2.${NC} Install Semua Service (Complete: + DNS Server)"
    echo -e "${CYAN}3.${NC} Install Apache2 (Web Server)"
    echo -e "${CYAN}4.${NC} Install FTP (vsftpd)"
    echo -e "${CYAN}5.${NC} Install SSH (Secure Server)"
    echo -e "${CYAN}6.${NC} Install DNS Server (Bind9)"
    echo -e "${CYAN}7.${NC} Install WordPress (Optional)"
    echo -e "${RED}8.${NC} Exit"
    echo -e "${YELLOW}========================================${NC}"
    echo ""
    echo -ne "${BOLD}${GREEN}Pilih menu (1-8): ${NC}"
}

# Fungsi untuk membaca input menu
prompt_menu_choice() {
    if ! IFS= read -r choice < /dev/tty; then
        echo ""
        log_error "Gagal membaca input"
        exit 1
    fi
}

# ==================== MAIN PROGRAM ====================

check_root

while true; do
    show_banner
    show_menu
    prompt_menu_choice
    
    case $choice in
        1)
            echo ""
            install_all_basic
            ;;
        2)
            echo ""
            install_all_complete
            ;;
        3)
            echo ""
            install_apache
            ;;
        4)
            echo ""
            install_ftp
            ;;
        5)
            echo ""
            install_ssh
            ;;
        6)
            echo ""
            install_dns
            ;;
        7)
            echo ""
            install_wordpress
            ;;
        8)
            echo ""
            log_info "Terima kasih telah menggunakan TechCorp Multi-Service Installer!"
            echo -e "${GREEN}========================================${NC}"
            echo -e "${GREEN}Script by TechCorp - All rights reserved${NC}"
            echo -e "${GREEN}Version: 2.0 - With DNS Server Support${NC}"
            echo -e "${GREEN}========================================${NC}"
            exit 0
            ;;
        *)
            log_error "Pilihan tidak valid! Silakan pilih 1-8"
            sleep 2
            ;;
    esac
    
    echo ""
    read -p "Tekan Enter untuk kembali ke menu utama..." < /dev/tty
done