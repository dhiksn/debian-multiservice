#!/bin/bash

# =====================================================
# TechCorp Server Setup Script
# Version: 3.0
# =====================================================

# Warna
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

# File konfigurasi
NETWORK_CONFIG="/etc/network/interfaces"
DNS_CONFIG="/etc/resolv.conf"

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

# Banner function - simple and clean
show_banner() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo "â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—"
    echo "â•‘                                                              â•‘"
    echo "â•‘   â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•— â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—â–ˆâ–ˆâ•—  â–ˆâ–ˆâ•— â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•— â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•— â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—   â•‘"
    echo "â•‘   â•šâ•â•â–ˆâ–ˆâ•”â•â•â•â–ˆâ–ˆâ•”â•â•â•â•â•â–ˆâ–ˆâ•”â•â•â•â•â•â–ˆâ–ˆâ•‘  â–ˆâ–ˆâ•‘â–ˆâ–ˆâ•”â•â•â•â–ˆâ–ˆâ•—â–ˆâ–ˆâ•”â•â•â–ˆâ–ˆâ•—â–ˆâ–ˆâ•”â•â•â–ˆâ–ˆâ•—  â•‘"
    echo "â•‘      â–ˆâ–ˆâ•‘   â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—  â–ˆâ–ˆâ•‘     â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•‘â–ˆâ–ˆâ•‘   â–ˆâ–ˆâ•‘â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•”â•â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•”â•  â•‘"
    echo "â•‘      â–ˆâ–ˆâ•‘   â–ˆâ–ˆâ•”â•â•â•  â–ˆâ–ˆâ•‘     â–ˆâ–ˆâ•”â•â•â–ˆâ–ˆâ•‘â–ˆâ–ˆâ•‘   â–ˆâ–ˆâ•‘â–ˆâ–ˆâ•”â•â•â–ˆâ–ˆâ•—â–ˆâ–ˆâ•”â•â•â•â•   â•‘"
    echo "â•‘      â–ˆâ–ˆâ•‘   â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—â•šâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•—â–ˆâ–ˆâ•‘  â–ˆâ–ˆâ•‘â•šâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ•”â•â–ˆâ–ˆâ•‘  â–ˆâ–ˆâ•‘â–ˆâ–ˆâ•‘       â•‘"
    echo "â•‘      â•šâ•â•   â•šâ•â•â•â•â•â•â• â•šâ•â•â•â•â•â•â•šâ•â•  â•šâ•â• â•šâ•â•â•â•â•â• â•šâ•â•  â•šâ•â•â•šâ•â•       â•‘"
    echo "â•‘                                                              â•‘"
    echo "â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•"
    echo -e "${NC}"
    echo -e "${CYAN}${BOLD}     Multi-Service Installer | Apache2 + FTP + SSH + Network Setup${NC}"
    echo -e "${BLUE}â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${NC}"
    echo ""
}

# Check root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[ERROR] Script harus dijalankan sebagai root!${NC}"
        echo -e "${YELLOW}Gunakan: sudo ./test.sh${NC}"
        exit 1
    fi
}

# Update system
update_system() {
    log_step "Mengupdate sistem..."
    apt update -y
    apt upgrade -y
    apt autoremove -y
    apt clean
    log_success "Update sistem selesai"
}

# =====================================================
# 1. SETUP IP STATIC
# =====================================================
setup_ip_static() {
    log_step "Konfigurasi IP Static"
    echo ""
    
    echo -e "${YELLOW}Masukkan konfigurasi IP Static:${NC}"
    echo -n "   IP Address (contoh: 192.168.1.100): "
    read ip_address
    
    echo -n "   Netmask (contoh: 255.255.255.0): "
    read netmask
    
    echo -n "   Gateway (contoh: 192.168.1.1): "
    read gateway
    
    if [[ -z "$ip_address" || -z "$netmask" || -z "$gateway" ]]; then
        log_error "Semua field harus diisi!"
        return 1
    fi
    
    # Backup
    cp $NETWORK_CONFIG ${NETWORK_CONFIG}.backup 2>/dev/null
    
    # Dapatkan interface
    main_interface=$(ip route | grep default | awk '{print $5}' | head -n1)
    if [[ -z "$main_interface" ]]; then
        main_interface="eth0"
    fi
    
    # Konfigurasi
    cat > $NETWORK_CONFIG << EOF
auto lo
iface lo inet loopback

auto $main_interface
iface $main_interface inet static
    address $ip_address
    netmask $netmask
    gateway $gateway
EOF
    
    systemctl restart networking
    log_success "IP Static berhasil dikonfigurasi"
    echo -e "   ${CYAN}IP:${NC} $ip_address | ${CYAN}Gateway:${NC} $gateway"
}

# =====================================================
# 2. SETUP DNS SERVER
# =====================================================
setup_dns() {
    log_step "Konfigurasi DNS Server"
    echo ""
    
    echo -e "${YELLOW}Pilih DNS Server:${NC}"
    echo "   1. Google DNS (8.8.8.8, 8.8.4.4)"
    echo "   2. Cloudflare DNS (1.1.1.1, 1.0.0.1)"
    echo "   3. Custom DNS"
    echo ""
    echo -n "Pilih [1-3]: "
    read dns_choice
    
    case $dns_choice in
        1)
            dns1="8.8.8.8"
            dns2="8.8.4.4"
            log_info "Menggunakan Google DNS"
            ;;
        2)
            dns1="1.1.1.1"
            dns2="1.0.0.1"
            log_info "Menggunakan Cloudflare DNS"
            ;;
        3)
            echo -n "   DNS Primary: "
            read dns1
            echo -n "   DNS Secondary: "
            read dns2
            ;;
        *)
            dns1="8.8.8.8"
            dns2="8.8.4.4"
            ;;
    esac
    
    # Backup dan konfigurasi
    cp $DNS_CONFIG ${DNS_CONFIG}.backup 2>/dev/null
    cat > $DNS_CONFIG << EOF
nameserver $dns1
nameserver $dns2
EOF
    
    log_success "DNS Server berhasil dikonfigurasi"
    echo -e "   ${CYAN}DNS Primary:${NC} $dns1 | ${CYAN}DNS Secondary:${NC} $dns2"
}

# =====================================================
# 3. INSTALL APACHE2
# =====================================================
install_apache() {
    log_step "Menginstall Apache2 Web Server..."
    
    apt install apache2 -y
    systemctl enable apache2
    systemctl start apache2
    
    if systemctl is-active --quiet apache2; then
        log_success "Apache2 berjalan"
    else
        log_error "Apache2 gagal berjalan"
        return 1
    fi
    
    current_ip=$(ip route get 1 | awk '{print $NF;exit}' 2>/dev/null)
    [[ -z "$current_ip" ]] && current_ip="localhost"
    
    # Halaman web sederhana
    cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>TechCorp Indonesia</title>
    <meta charset="UTF-8">
    <style>
        body { font-family: Arial; margin: 0; padding: 0; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); }
        .container { max-width: 1000px; margin: 50px auto; background: white; border-radius: 10px; overflow: hidden; box-shadow: 0 10px 30px rgba(0,0,0,0.3); }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 40px; text-align: center; }
        .header h1 { margin: 0; font-size: 2.5em; }
        .content { padding: 40px; }
        .services { display: flex; gap: 20px; margin: 30px 0; flex-wrap: wrap; }
        .service { flex: 1; background: #f5f5f5; padding: 20px; border-radius: 8px; text-align: center; }
        .service h3 { color: #667eea; }
        .contact { background: #f5f5f5; padding: 20px; border-radius: 8px; text-align: center; margin-top: 20px; }
        footer { background: #333; color: white; text-align: center; padding: 15px; }
        @media (max-width: 600px) { .services { flex-direction: column; } }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>TechCorp Indonesia</h1>
            <p>Solusi Teknologi untuk Masa Depan</p>
        </div>
        <div class="content">
            <h2>Tentang TechCorp</h2>
            <p>TechCorp adalah perusahaan teknologi terkemuka yang menyediakan solusi digital inovatif untuk bisnis modern.</p>
            
            <div class="services">
                <div class="service">
                    <h3>Web Development</h3>
                    <p>Pengembangan website modern dan responsif</p>
                </div>
                <div class="service">
                    <h3>Network Engineering</h3>
                    <p>Infrastruktur jaringan yang handal</p>
                </div>
                <div class="service">
                    <h3>Cybersecurity</h3>
                    <p>Perlindungan aset digital Anda</p>
                </div>
            </div>
            
            <div class="contact">
                <h3>Hubungi Kami</h3>
                <p>Email: info@techcorp.co.id | Telp: (021) 1234-5678</p>
                <p>Jl. Teknologi No. 123, Jakarta Selatan</p>
            </div>
        </div>
        <footer>
            <p>&copy; 2024 TechCorp Indonesia - Powered by Apache2</p>
        </footer>
    </div>
</body>
</html>
EOF
    
    chown -R www-data:www-data /var/www/html/
    chmod -R 755 /var/www/html/
    
    log_success "Apache2 selesai"
    log_info "Akses: http://$current_ip"
}

# =====================================================
# 4. INSTALL FTP (vsftpd)
# =====================================================
install_ftp() {
    log_step "Menginstall vsftpd FTP Server..."
    
    apt install vsftpd -y
    cp /etc/vsftpd.conf /etc/vsftpd.conf.backup 2>/dev/null
    
    cat > /etc/vsftpd.conf << 'EOF'
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
allow_writeable_chroot=YES
pasv_enable=YES
pasv_min_port=30000
pasv_max_port=31000
ftpd_banner=Welcome to TechCorp FTP
EOF
    
    if ! id "admin" &>/dev/null; then
        useradd -m -s /bin/bash admin
    fi
    echo "admin:123" | chpasswd
    chmod 755 /home/admin
    
    systemctl restart vsftpd
    systemctl enable vsftpd
    
    current_ip=$(ip route get 1 | awk '{print $NF;exit}' 2>/dev/null)
    [[ -z "$current_ip" ]] && current_ip="localhost"
    
    log_success "FTP Server selesai"
    log_info "Server: ftp://$current_ip | User: admin | Pass: 123"
}

# =====================================================
# 5. INSTALL SSH
# =====================================================
install_ssh() {
    log_step "Menginstall OpenSSH Server..."
    
    apt install openssh-server -y
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup 2>/dev/null
    
    cat > /etc/ssh/sshd_config << 'EOF'
Port 22
Protocol 2
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
MaxAuthTries 3
ClientAliveInterval 300
AllowUsers admin
Subsystem sftp /usr/lib/openssh/sftp-server
EOF
    
    if ! id "admin" &>/dev/null; then
        useradd -m -s /bin/bash admin
        echo "admin:123" | chpasswd
    fi
    
    mkdir -p /home/admin/.ssh
    chmod 700 /home/admin/.ssh
    
    if [[ ! -f /home/admin/.ssh/id_rsa ]]; then
        ssh-keygen -t rsa -b 4096 -f /home/admin/.ssh/id_rsa -N "" -C "techcorp"
    fi
    
    cp /home/admin/.ssh/id_rsa.pub /home/admin/.ssh/authorized_keys
    chmod 600 /home/admin/.ssh/authorized_keys
    chown -R admin:admin /home/admin/.ssh
    
    systemctl restart sshd
    systemctl enable sshd
    
    current_ip=$(ip route get 1 | awk '{print $NF;exit}' 2>/dev/null)
    
    log_success "SSH Server selesai"
    log_info "User: admin | Private key: /home/admin/.ssh/id_rsa"
    log_warning "Password authentication telah DINONAKTIFKAN"
}

# =====================================================
# 6. INSTALL SEMUA
# =====================================================
install_all() {
    log_step "Instalasi semua service..."
    echo ""
    
    update_system
    echo ""
    
    setup_ip_static
    echo ""
    
    setup_dns
    echo ""
    
    install_apache
    echo ""
    
    install_ftp
    echo ""
    
    install_ssh
    echo ""
    
    current_ip=$(ip route get 1 | awk '{print $NF;exit}' 2>/dev/null)
    
    echo ""
    echo -e "${GREEN}${BOLD}â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${NC}"
    echo -e "${GREEN}${BOLD}                    INSTALLASI SELESAI                       ${NC}"
    echo -e "${GREEN}${BOLD}â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${NC}"
    echo ""
    echo -e "${CYAN}Web:${NC} http://$current_ip"
    echo -e "${CYAN}FTP:${NC} ftp://$current_ip (admin/123)"
    echo -e "${CYAN}SSH:${NC} ssh://$current_ip (key-based)"
    echo ""
}

# =====================================================
# MENU UTAMA
# =====================================================
show_menu() {
    echo ""
    echo -e "${YELLOW}${BOLD}â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—${NC}"
    echo -e "${YELLOW}${BOLD}â•‘                       MENU UTAMA                         â•‘${NC}"
    echo -e "${YELLOW}${BOLD}â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${NC}"
    echo ""
    echo -e "  ${CYAN}1.${NC} Setup IP Static"
    echo -e "  ${CYAN}2.${NC} Setup DNS Server"
    echo -e "  ${CYAN}3.${NC} Install Apache2 (Web Server)"
    echo -e "  ${CYAN}4.${NC} Install FTP (vsftpd)"
    echo -e "  ${CYAN}5.${NC} Install SSH (Secure Server)"
    echo -e "  ${CYAN}6.${NC} Install Semua Service"
    echo -e "  ${CYAN}7.${NC} Exit"
    echo ""
    echo -e "${BLUE}â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•${NC}"
    echo -n -e "${GREEN}Pilih menu [1-7]: ${NC}"
}

# =====================================================
# MAIN
# =====================================================
check_root

while true; do
    show_banner
    
    # Tampilkan IP
    current_ip=$(ip route get 1 2>/dev/null | awk '{print $NF;exit}')
    if [[ -n "$current_ip" ]]; then
        echo -e "   ${WHITE}Current IP Address:${NC} ${GREEN}$current_ip${NC}"
    else
        echo -e "   ${WHITE}Current IP Address:${NC} ${RED}Not Set${NC}"
    fi
    echo ""
    
    show_menu
    read choice
    
    case "$choice" in
        1)
            echo ""
            setup_ip_static
            ;;
        2)
            echo ""
            setup_dns
            ;;
        3)
            echo ""
            update_system
            echo ""
            install_apache
            ;;
        4)
            echo ""
            update_system
            echo ""
            install_ftp
            ;;
        5)
            echo ""
            update_system
            echo ""
            install_ssh
            ;;
        6)
            echo ""
            install_all
            ;;
        7)
            echo ""
            echo -e "${GREEN}Terima kasih menggunakan TechCorp Setup Script!${NC}"
            echo -e "${CYAN}TechCorp - Solusi Teknologi Terpercaya${NC}"
            echo ""
            exit 0
            ;;
        *)
            echo -e "${RED}[ERROR] Pilihan tidak valid! Silakan pilih 1-7${NC}"
            sleep 2
            ;;
    esac
    
    echo ""
    echo -n "Tekan Enter untuk kembali ke menu utama..."
    read dummy
done
