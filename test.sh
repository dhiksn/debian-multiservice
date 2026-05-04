#!/bin/bash

# =====================================================
# Script: TechCorp Server Setup Script
# Author: TechCorp
# Description: Network Configuration + Multi-Service Installer
# Version: 1.0
# =====================================================

# Warna untuk tampilan
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'
UNDERLINE='\033[4m'

# File konfigurasi network
NETWORK_CONFIG="/etc/network/interfaces"
DNS_CONFIG="/etc/resolv.conf"

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
    echo -e "${CYAN}[STEP]${NC} ${BOLD}$1${NC}"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} ${BOLD}$1${NC}"
}

# Fungsi untuk menampilkan separator
print_separator() {
    echo -e "${BLUE}------------------------------------------------------------${NC}"
}

# Fungsi untuk menampilkan banner
show_banner() {
    clear
    echo -e "${BLUE}${BOLD}"
    cat << "EOF"
â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•— â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—â–ˆâ–ˆâ•—  â–ˆâ–ˆâ•— â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•— â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•— â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•— â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•— 
â•šâ•â•â–ˆâ–ˆâ•”â•â•â•â–ˆâ–ˆâ•”â•â•â•â•â•â–ˆâ–ˆâ•”â•â•â•â•â•â–ˆâ–ˆâ•‘  â–ˆâ–ˆâ•‘â–ˆâ–ˆâ•”â•â•â•â–ˆâ–ˆâ•—â–ˆâ–ˆâ•”â•â•â–ˆâ–ˆâ•—â–ˆâ–ˆâ•”â•â•â–ˆâ–ˆâ•—â–ˆâ–ˆâ•”â•â•â–ˆâ–ˆâ•—
   â–ˆâ–ˆâ•‘   â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—  â–ˆâ–ˆâ•‘     â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•‘â–ˆâ–ˆâ•‘   â–ˆâ–ˆâ•‘â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•”â•â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•”â•â–ˆâ–ˆâ•‘  â–ˆâ–ˆâ•‘
   â–ˆâ–ˆâ•‘   â–ˆâ–ˆâ•”â•â•â•  â–ˆâ–ˆâ•‘     â–ˆâ–ˆâ•”â•â•â–ˆâ–ˆâ•‘â–ˆâ–ˆâ•‘   â–ˆâ–ˆâ•‘â–ˆâ–ˆâ•”â•â•â–ˆâ–ˆâ•—â–ˆâ–ˆâ•”â•â•â•â• â–ˆâ–ˆâ•‘  â–ˆâ–ˆâ•‘
   â–ˆâ–ˆâ•‘   â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—â•šâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—â–ˆâ–ˆâ•‘  â–ˆâ–ˆâ•‘â•šâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•”â•â–ˆâ–ˆâ•‘  â–ˆâ–ˆâ•‘â–ˆâ–ˆâ•‘     â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•”â•
   â•šâ•â•   â•šâ•â•â•â•â•â•â• â•šâ•â•â•â•â•â•â•šâ•â•  â•šâ•â• â•šâ•â•â•â•â•â• â•šâ•â•  â•šâ•â•â•šâ•â•     â•šâ•â•â•â•â•â• 
EOF
    echo -e "${NC}"
    print_separator
    echo -e "${CYAN}${BOLD}     Multi-Service Installer | Apache2 + FTP + SSH + Network Setup${NC}"
    print_separator
    echo ""
}

# Fungsi untuk cek root privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Script ini harus dijalankan sebagai root!"
        echo -e "${YELLOW}Gunakan: sudo ./test.sh${NC}"
        exit 1
    fi
}

# Fungsi untuk update sistem
update_system() {
    log_step "Mengupdate sistem..."
    apt update -y
    apt upgrade -y
    apt autoremove -y
    apt clean
    log_success "Update sistem selesai"
}

# =====================================================
# FUNGSI NETWORK SETUP
# =====================================================

setup_network() {
    log_step "Konfigurasi Network Static IP"
    echo ""
    
    # Input dari user
    echo -e "${YELLOW}Masukkan konfigurasi network:${NC}"
    echo ""
    
    read -p "   IP Address (contoh: 192.168.1.100): " ip_address
    read -p "   Netmask (contoh: 255.255.255.0): " netmask
    read -p "   Gateway (contoh: 192.168.1.1): " gateway
    read -p "   DNS Server (contoh: 8.8.8.8): " dns_server
    
    # Validasi input tidak kosong
    if [[ -z "$ip_address" || -z "$netmask" || -z "$gateway" || -z "$dns_server" ]]; then
        log_error "Semua field harus diisi!"
        return 1
    fi
    
    # Backup konfigurasi network yang ada
    cp $NETWORK_CONFIG ${NETWORK_CONFIG}.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null
    log_info "Backup konfigurasi network disimpan"
    
    # Identifikasi interface utama (biasanya eth0 atau ens33)
    main_interface=$(ip route | grep default | awk '{print $5}' | head -n1)
    if [[ -z "$main_interface" ]]; then
        main_interface="eth0"
    fi
    log_info "Menggunakan interface: $main_interface"
    
    # Konfigurasi static IP di /etc/network/interfaces
    log_step "Mengkonfigurasi static IP..."
    cat > $NETWORK_CONFIG << EOF
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto $main_interface
iface $main_interface inet static
    address $ip_address
    netmask $netmask
    gateway $gateway
    dns-nameservers $dns_server
EOF
    
    # Konfigurasi DNS di /etc/resolv.conf
    log_step "Mengkonfigurasi DNS..."
    cat > $DNS_CONFIG << EOF
# DNS Configuration - TechCorp Setup
nameserver $dns_server
nameserver 8.8.4.4
EOF
    
    # Restart network service
    log_step "Merestart network service..."
    systemctl restart networking
    
    log_success "Konfigurasi network selesai!"
    echo ""
    log_info "Informasi network baru:"
    echo -e "   ${CYAN}IP Address:${NC} $ip_address"
    echo -e "   ${CYAN}Gateway:${NC} $gateway"
    echo -e "   ${CYAN}DNS:${NC} $dns_server"
    echo ""
    log_warning "Jika SSH terputus, reconnect dengan IP baru: $ip_address"
}

# =====================================================
# FUNGSI APACHE2
# =====================================================

install_apache() {
    log_step "Menginstall Apache2 Web Server..."
    
    # Install Apache2
    apt install apache2 -y
    
    # Enable dan start service
    systemctl enable apache2
    systemctl start apache2
    
    # Cek status
    if systemctl is-active --quiet apache2; then
        log_success "Apache2 berjalan"
    else
        log_error "Apache2 gagal berjalan"
        return 1
    fi
    
    # Membuat halaman web custom
    log_step "Membuat halaman web perusahaan..."
    
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
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
            min-height: 100vh;
            color: #333;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 60px 40px;
            text-align: center;
            border-radius: 15px;
            margin-bottom: 30px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
        }
        
        .header h1 {
            font-size: 3.5em;
            margin-bottom: 10px;
        }
        
        .header p {
            font-size: 1.2em;
            opacity: 0.95;
        }
        
        .company-desc {
            background: white;
            padding: 40px;
            border-radius: 15px;
            margin-bottom: 30px;
            box-shadow: 0 5px 20px rgba(0,0,0,0.1);
        }
        
        .company-desc h2 {
            color: #667eea;
            margin-bottom: 20px;
            font-size: 1.8em;
        }
        
        .company-desc p {
            line-height: 1.8;
            font-size: 1.1em;
            color: #555;
        }
        
        .services {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 25px;
            margin-bottom: 30px;
        }
        
        .service-card {
            background: white;
            padding: 30px;
            border-radius: 15px;
            text-align: center;
            transition: all 0.3s ease;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
        }
        
        .service-card:hover {
            transform: translateY(-10px);
            box-shadow: 0 15px 35px rgba(0,0,0,0.2);
        }
        
        .service-icon {
            font-size: 3em;
            margin-bottom: 15px;
        }
        
        .service-card h3 {
            color: #667eea;
            margin-bottom: 15px;
            font-size: 1.5em;
        }
        
        .service-card p {
            color: #666;
            line-height: 1.6;
        }
        
        .contact {
            background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
            padding: 40px;
            border-radius: 15px;
            text-align: center;
        }
        
        .contact h3 {
            color: #333;
            margin-bottom: 20px;
            font-size: 1.8em;
        }
        
        .contact-info {
            display: flex;
            justify-content: center;
            gap: 30px;
            flex-wrap: wrap;
            margin-top: 20px;
        }
        
        .contact-item {
            background: white;
            padding: 15px 25px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        
        footer {
            text-align: center;
            padding: 30px;
            color: white;
            margin-top: 30px;
        }
        
        @media (max-width: 768px) {
            .header h1 { font-size: 2em; }
            .services { grid-template-columns: 1fr; }
            .contact-info { flex-direction: column; align-items: center; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>TechCorp Indonesia</h1>
            <p>Inovasi Teknologi untuk Masa Depan yang Lebih Baik</p>
        </div>
        
        <div class="company-desc">
            <h2>Tentang TechCorp</h2>
            <p>
                TechCorp adalah perusahaan teknologi terkemuka di Indonesia yang berdedikasi untuk 
                memberikan solusi digital terbaik bagi bisnis Anda. Dengan pengalaman lebih dari 
                satu dekade, kami telah membantu ribuan klien dalam mentransformasi ide-ide brilian 
                menjadi realitas digital yang mengesankan. Tim profesional kami yang berdedikasi 
                siap membantu Anda menghadapi tantangan teknologi di era digital ini.
            </p>
        </div>
        
        <h2 style="text-align: center; color: white; margin-bottom: 20px;">Layanan Unggulan Kami</h2>
        <div class="services">
            <div class="service-card">
                <div class="service-icon">Web Dev</div>
                <h3>Web Development</h3>
                <p>Pengembangan website modern, responsif, dan scalable menggunakan teknologi terkini seperti React, Laravel, dan Node.js.</p>
            </div>
            <div class="service-card">
                <div class="service-icon">Network</div>
                <h3>Network Engineering</h3>
                <p>Desain dan implementasi infrastruktur jaringan yang handal, aman, dan optimal untuk mendukung operasional bisnis Anda.</p>
            </div>
            <div class="service-card">
                <div class="service-icon">Security</div>
                <h3>Cybersecurity</h3>
                <p>Solusi keamanan siber komprehensif melindungi aset digital Anda dari berbagai ancaman dan serangan siber.</p>
            </div>
        </div>
        
        <div class="contact">
            <h3>Hubungi Kami</h3>
            <div class="contact-info">
                <div class="contact-item">Email: info@techcorp.co.id</div>
                <div class="contact-item">Telp: (021) 1234-5678</div>
                <div class="contact-item">Alamat: Jl. Teknologi No. 123, Jakarta Selatan</div>
            </div>
        </div>
        
        <footer>
            <p>&copy; 2024 TechCorp Indonesia. All rights reserved.</p>
            <p style="font-size: 0.9em; margin-top: 10px;">Powered by Apache2 on Debian Server</p>
        </footer>
    </div>
</body>
</html>
HTMLEOF
    
    # Set permission yang benar
    chown -R www-data:www-data /var/www/html/
    chmod -R 755 /var/www/html/
    
    log_success "Apache2 berhasil diinstall!"
    log_info "Website dapat diakses di: http://$ip_address atau http://localhost"
}

# =====================================================
# FUNGSI FTP (vsftpd)
# =====================================================

install_ftp() {
    log_step "Menginstall vsftpd FTP Server..."
    
    # Install vsftpd
    apt install vsftpd -y
    
    # Backup konfigurasi asli
    cp /etc/vsftpd.conf /etc/vsftpd.conf.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null
    
    # Membuat konfigurasi baru
    log_step "Mengkonfigurasi vsftpd..."
    
    cat > /etc/vsftpd.conf << 'FTPEOF'
# TechCorp vsftpd Configuration
# Listen options
listen=YES
listen_ipv6=NO

# Anonymous access
anonymous_enable=NO

# Local user access
local_enable=YES
write_enable=YES
local_umask=022

# Security settings
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES

# Chroot settings
chroot_local_user=YES
allow_writeable_chroot=YES

# Passive mode settings
pasv_enable=YES
pasv_min_port=30000
pasv_max_port=31000

# Banner
ftpd_banner=Welcome to TechCorp FTP Service!

# Logging
xferlog_file=/var/log/vsftpd.log
log_ftp_protocol=YES

# Performance
idle_session_timeout=600
data_connection_timeout=120
FTPEOF
    
    # Membuat user admin untuk FTP
    log_step "Membuat user FTP: admin"
    
    # Cek apakah user sudah ada
    if id "admin" &>/dev/null; then
        log_warning "User admin sudah ada, mengupdate password..."
    else
        useradd -m -s /bin/bash admin
        log_info "User admin berhasil dibuat"
    fi
    
    # Set password
    echo "admin:123" | chpasswd
    
    # Set permission home directory
    chmod 755 /home/admin
    
    # Restart service
    systemctl restart vsftpd
    systemctl enable vsftpd
    
    # Cek status
    if systemctl is-active --quiet vsftpd; then
        log_success "vsftpd berjalan dengan baik"
    else
        log_error "vsftpd gagal berjalan"
        return 1
    fi
    
    log_success "FTP Server berhasil dikonfigurasi!"
    echo ""
    log_info "Informasi FTP:"
    echo -e "   ${CYAN}Server:${NC} ftp://$ip_address"
    echo -e "   ${CYAN}Username:${NC} admin"
    echo -e "   ${CYAN}Password:${NC} 123"
}

# =====================================================
# FUNGSI SSH SERVER
# =====================================================

install_ssh() {
    log_step "Menginstall dan mengkonfigurasi OpenSSH Server..."
    
    # Install SSH server
    apt install openssh-server -y
    
    # Backup konfigurasi asli
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null
    
    # Konfigurasi SSH dengan security hardening
    log_step "Menerapkan konfigurasi SSH hardening..."
    
    cat > /etc/ssh/sshd_config << 'SSHEOF'
# TechCorp SSH Server Configuration - Hardened Security

# Network
Port 22
Protocol 2
AddressFamily inet
ListenAddress 0.0.0.0

# Host Keys
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Authentication
LoginGraceTime 30s
PermitRootLogin no
StrictModes yes
MaxAuthTries 3
MaxSessions 5

# Key-based authentication (Password disabled for security)
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
AuthenticationMethods publickey

# Security
IgnoreRhosts yes
HostbasedAuthentication no
PermitUserEnvironment no

# Session
X11Forwarding no
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
ClientAliveInterval 300
ClientAliveCountMax 2

# SFTP
Subsystem sftp /usr/lib/openssh/sftp-server -f AUTHPRIV -l INFO

# Allow specific users only
AllowUsers admin
SSHEOF
    
    # Membuat user admin jika belum ada
    if ! id "admin" &>/dev/null; then
        useradd -m -s /bin/bash admin
        echo "admin:123" | chpasswd
        log_info "User admin dibuat untuk SSH"
    fi
    
    # Setup SSH keys
    log_step "Mengkonfigurasi SSH key-based authentication..."
    
    # Membuat .ssh directory untuk user admin
    mkdir -p /home/admin/.ssh
    chmod 700 /home/admin/.ssh
    
    # Generate contoh key pair
    if [[ ! -f /home/admin/.ssh/id_rsa ]]; then
        ssh-keygen -t rsa -b 4096 -f /home/admin/.ssh/id_rsa -N "" -C "techcorp-admin@$(hostname)"
        log_info "SSH key pair berhasil digenerate"
    fi
    
    # Setup authorized_keys
    cat /home/admin/.ssh/id_rsa.pub > /home/admin/.ssh/authorized_keys
    chmod 600 /home/admin/.ssh/authorized_keys
    
    # Set ownership yang benar
    chown -R admin:admin /home/admin/.ssh
    
    # Tampilkan public key
    log_info "SSH Public Key:"
    echo -e "${CYAN}"
    cat /home/admin/.ssh/id_rsa.pub
    echo -e "${NC}"
    
    # Restart SSH service
    systemctl restart sshd
    systemctl enable sshd
    
    # Cek status
    if systemctl is-active --quiet sshd; then
        log_success "SSH Server berjalan dengan konfigurasi hardened"
    else
        log_error "SSH Server gagal berjalan"
        return 1
    fi
    
    log_success "SSH Server berhasil dikonfigurasi!"
    echo ""
    log_info "Informasi SSH:"
    echo -e "   ${CYAN}Server:${NC} ssh://$ip_address:22"
    echo -e "   ${CYAN}Username:${NC} admin"
    echo -e "   ${CYAN}Private Key:${NC} /home/admin/.ssh/id_rsa"
    echo -e "   ${YELLOW}IMPORTANT:${NC} Password authentication telah dinonaktifkan!"
    echo -e "   ${YELLOW}IMPORTANT:${NC} Root login dinonaktifkan!"
}

# =====================================================
# FUNGSI INSTALL SEMUA SERVICE
# =====================================================

install_all() {
    log_step "Memulai instalasi semua service..."
    print_separator
    
    update_system
    echo ""
    
    setup_network
    echo ""
    
    install_apache
    echo ""
    
    install_ftp
    echo ""
    
    install_ssh
    echo ""
    
    print_separator
    log_success "Semua service berhasil diinstall!"
    print_separator
    
    echo ""
    echo -e "${GREEN}${BOLD}============================================================${NC}"
    echo -e "${GREEN}${BOLD}                 INFORMASI SERVICE                      ${NC}"
    echo -e "${GREEN}${BOLD}============================================================${NC}"
    echo ""
    echo -e "${CYAN}Web Server:${NC} http://$ip_address"
    echo -e "${CYAN}FTP Server:${NC} ftp://$ip_address (admin:123)"
    echo -e "${CYAN}SSH Server:${NC} ssh://$ip_address:22 (key-based)"
    echo ""
    echo -e "${YELLOW}Catatan Penting:${NC}"
    echo -e "  - FTP Password: ${GREEN}123${NC}"
    echo -e "  - SSH Private Key: ${GREEN}/home/admin/.ssh/id_rsa${NC}"
    echo -e "  - Backup konfigurasi disimpan di /etc/*.backup.*"
    echo ""
}

# =====================================================
# FUNGSI MENU UTAMA
# =====================================================

show_menu() {
    echo ""
    print_separator
    echo -e "${YELLOW}${BOLD}â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—${NC}"
    echo -e "${YELLOW}${BOLD}â•‘                      MENU UTAMA                        â•‘${NC}"
    echo -e "${YELLOW}${BOLD}â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${NC}"
    echo ""
    echo -e "  ${CYAN}1.${NC} Setup Network (IP & DNS)"
    echo -e "  ${CYAN}2.${NC} Install Apache2 (Web Server)"
    echo -e "  ${CYAN}3.${NC} Install FTP (vsftpd)"
    echo -e "  ${CYAN}4.${NC} Install SSH (Secure Server)"
    echo -e "  ${CYAN}5.${NC} Install Semua Service"
    echo -e "  ${CYAN}6.${NC} Exit"
    echo ""
    print_separator
    echo -ne "${GREEN}Pilih menu [1-6]: ${NC}"
}

# =====================================================
# MAIN PROGRAM
# =====================================================

# Cek root privileges
check_root

# Loop utama
while true; do
    show_banner
    
    # Tampilkan IP saat ini
    current_ip=$(ip route get 1 | awk '{print $NF;exit}' 2>/dev/null)
    if [[ -n "$current_ip" ]]; then
        echo -e "   ${WHITE}Current IP Address:${NC} ${GREEN}$current_ip${NC}"
    fi
    echo ""
    
    show_menu
    read choice
    
    case $choice in
        1)
            echo ""
            setup_network
            ;;
        2)
            echo ""
            update_system
            echo ""
            install_apache
            ;;
        3)
            echo ""
            update_system
            echo ""
            install_ftp
            ;;
        4)
            echo ""
            update_system
            echo ""
            install_ssh
            ;;
        5)
            echo ""
            install_all
            ;;
        6)
            echo ""
            echo -e "${GREEN}Terima kasih telah menggunakan TechCorp Server Setup Script!${NC}"
            echo -e "${CYAN}Script by TechCorp - Solusi Teknologi Terpercaya${NC}"
            echo ""
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
