# PowerShell Script: generate-setup.ps1
# Fungsi: Generate bash script untuk konfigurasi network dan instalasi service di Debian

$setupScriptContent = @'
#!/bin/bash

# =====================================================
# Script: TechCorp Server Setup Script
# Author: TechCorp
# Description: Network Configuration + Multi-Service Installer
# Version: 2.0
# =====================================================

# Warna untuk tampilan
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

# File konfigurasi
NETWORK_CONFIG="/etc/network/interfaces"
DNS_CONFIG="/etc/resolv.conf"
HOSTS_CONFIG="/etc/hosts"

# Fungsi logging
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

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_separator() {
    echo -e "${BLUE}------------------------------------------------------------${NC}"
}

# Fungsi banner yang lebih sederhana dan kompatibel
show_banner() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo ' ████████╗███████╗ ██████╗██╗  ██╗ ██████╗ ██████╗ ██████╗ ██████╗ '
    echo ' ╚══██╔══╝██╔════╝██╔════╝██║  ██║██╔═══██╗██╔══██╗██╔══██╗██╔══██╗'
    echo '    ██║   █████╗  ██║     ███████║██║   ██║██████╔╝██████╔╝██║  ██║'
    echo '    ██║   ██╔══╝  ██║     ██╔══██║██║   ██║██╔══██╗██╔═══╝ ██║  ██║'
    echo '    ██║   ███████╗╚██████╗██║  ██║╚██████╔╝██║  ██║██║     ██████╔╝'
    echo '    ╚═╝   ╚══════╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═════╝ '
    echo -e "${NC}"
    print_separator
    echo -e "${CYAN}${BOLD}     Multi-Service Installer | Apache2 + FTP + SSH + Network Setup${NC}"
    print_separator
    echo ""
}

# Cek root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Script harus dijalankan sebagai root!"
        echo -e "${YELLOW}Gunakan: sudo ./test.sh${NC}"
        exit 1
    fi
}

# Update sistem
update_system() {
    log_step "Mengupdate sistem..."
    apt update -y
    apt upgrade -y
    apt autoremove -y
    apt clean
    log_success "Update sistem selesai"
}

# =====================================================
# FUNGSI NETWORK SETUP (IP STATIC)
# =====================================================

setup_ip_static() {
    log_step "Konfigurasi IP Static"
    echo ""
    
    echo -e "${YELLOW}Masukkan konfigurasi IP Static:${NC}"
    echo ""
    
    read -p "   IP Address (contoh: 192.168.1.100): " ip_address
    read -p "   Netmask (contoh: 255.255.255.0): " netmask
    read -p "   Gateway (contoh: 192.168.1.1): " gateway
    
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
    log_info "Menggunakan interface: $main_interface"
    
    # Konfigurasi static IP
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
    
    log_success "IP Static berhasil dikonfigurasi!"
    echo -e "   ${CYAN}IP Address:${NC} $ip_address"
    echo -e "   ${CYAN}Gateway:${NC} $gateway"
}

# =====================================================
# FUNGSI DNS SERVER
# =====================================================

setup_dns() {
    log_step "Konfigurasi DNS Server"
    echo ""
    
    echo -e "${YELLOW}Pilih opsi DNS:${NC}"
    echo "   1. Gunakan DNS Public (Google: 8.8.8.8, 8.8.4.4)"
    echo "   2. Gunakan DNS Cloudflare (1.1.1.1, 1.0.0.1)"
    echo "   3. Masukkan DNS manual"
    echo ""
    read -p "Pilih [1-3]: " dns_choice
    
    case $dns_choice in
        1)
            dns1="8.8.8.8"
            dns2="8.8.4.4"
            log_info "Menggunakan DNS Google"
            ;;
        2)
            dns1="1.1.1.1"
            dns2="1.0.0.1"
            log_info "Menggunakan DNS Cloudflare"
            ;;
        3)
            read -p "   DNS Primary: " dns1
            read -p "   DNS Secondary: " dns2
            ;;
        *)
            dns1="8.8.8.8"
            dns2="8.8.4.4"
            ;;
    esac
    
    # Backup
    cp $DNS_CONFIG ${DNS_CONFIG}.backup 2>/dev/null
    
    # Konfigurasi DNS
    cat > $DNS_CONFIG << EOF
nameserver $dns1
nameserver $dns2
EOF
    
    # Update /etc/hosts
    echo -e "\n# TechCorp DNS Configuration" >> $HOSTS_CONFIG
    
    log_success "DNS Server berhasil dikonfigurasi!"
    echo -e "   ${CYAN}DNS Primary:${NC} $dns1"
    echo -e "   ${CYAN}DNS Secondary:${NC} $dns2"
}

# =====================================================
# FUNGSI APACHE2
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
    
    # Dapatkan IP address
    current_ip=$(ip route get 1 | awk '{print $NF;exit}' 2>/dev/null)
    if [[ -z "$current_ip" ]]; then
        current_ip="localhost"
    fi
    
    # Halaman web
    cat > /var/www/html/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TechCorp - Solusi Teknologi Terpercaya</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
            min-height: 100vh;
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
        }
        .header h1 { font-size: 3.5em; margin-bottom: 10px; }
        .company-desc {
            background: white;
            padding: 40px;
            border-radius: 15px;
            margin-bottom: 30px;
        }
        .company-desc h2 { color: #667eea; margin-bottom: 20px; }
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
            transition: transform 0.3s;
        }
        .service-card:hover { transform: translateY(-10px); }
        .service-card h3 { color: #667eea; margin: 15px 0; }
        .contact {
            background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
            padding: 40px;
            border-radius: 15px;
            text-align: center;
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
        }
        footer {
            text-align: center;
            padding: 30px;
            color: white;
        }
        @media (max-width: 768px) {
            .header h1 { font-size: 2em; }
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
                menjadi realitas digital yang mengesankan.
            </p>
        </div>
        
        <h2 style="text-align: center; color: white; margin-bottom: 20px;">Layanan Unggulan Kami</h2>
        <div class="services">
            <div class="service-card">
                <div class="service-icon" style="font-size: 3em;">Web Dev</div>
                <h3>Web Development</h3>
                <p>Pengembangan website modern, responsif, dan scalable menggunakan teknologi terkini.</p>
            </div>
            <div class="service-card">
                <div class="service-icon" style="font-size: 3em;">Network</div>
                <h3>Network Engineering</h3>
                <p>Desain dan implementasi infrastruktur jaringan yang handal dan aman.</p>
            </div>
            <div class="service-card">
                <div class="service-icon" style="font-size: 3em;">Security</div>
                <h3>Cybersecurity</h3>
                <p>Solusi keamanan siber komprehensif melindungi aset digital Anda.</p>
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
    
    chown -R www-data:www-data /var/www/html/
    chmod -R 755 /var/www/html/
    
    log_success "Apache2 berhasil diinstall!"
    log_info "Website: http://$current_ip"
}

# =====================================================
# FUNGSI FTP (vsftpd)
# =====================================================

install_ftp() {
    log_step "Menginstall vsftpd FTP Server..."
    
    apt install vsftpd -y
    
    cp /etc/vsftpd.conf /etc/vsftpd.conf.backup 2>/dev/null
    
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
allow_writeable_chroot=YES
pasv_enable=YES
pasv_min_port=30000
pasv_max_port=31000
ftpd_banner=Welcome to TechCorp FTP Service!
FTPEOF
    
    # Buat user admin
    if id "admin" &>/dev/null; then
        log_warning "User admin sudah ada"
    else
        useradd -m -s /bin/bash admin
        log_info "User admin berhasil dibuat"
    fi
    
    echo "admin:123" | chpasswd
    chmod 755 /home/admin
    
    systemctl restart vsftpd
    systemctl enable vsftpd
    
    # Dapatkan IP
    current_ip=$(ip route get 1 | awk '{print $NF;exit}' 2>/dev/null)
    if [[ -z "$current_ip" ]]; then
        current_ip="localhost"
    fi
    
    log_success "FTP Server berhasil diinstall!"
    echo -e "   ${CYAN}Server:${NC} ftp://$current_ip"
    echo -e "   ${CYAN}Username:${NC} admin"
    echo -e "   ${CYAN}Password:${NC} 123"
}

# =====================================================
# FUNGSI SSH SERVER
# =====================================================

install_ssh() {
    log_step "Menginstall OpenSSH Server dengan konfigurasi hardening..."
    
    apt install openssh-server -y
    
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup 2>/dev/null
    
    cat > /etc/ssh/sshd_config << 'SSHEOF'
Port 22
Protocol 2
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
AuthenticationMethods publickey
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
AllowUsers admin
Subsystem sftp /usr/lib/openssh/sftp-server
SSHEOF
    
    # Buat user admin jika belum ada
    if ! id "admin" &>/dev/null; then
        useradd -m -s /bin/bash admin
        echo "admin:123" | chpasswd
    fi
    
    # Setup SSH keys
    mkdir -p /home/admin/.ssh
    chmod 700 /home/admin/.ssh
    
    if [[ ! -f /home/admin/.ssh/id_rsa ]]; then
        ssh-keygen -t rsa -b 4096 -f /home/admin/.ssh/id_rsa -N "" -C "techcorp-admin"
        log_info "SSH key pair generated"
    fi
    
    cp /home/admin/.ssh/id_rsa.pub /home/admin/.ssh/authorized_keys
    chmod 600 /home/admin/.ssh/authorized_keys
    chown -R admin:admin /home/admin/.ssh
    
    systemctl restart sshd
    systemctl enable sshd
    
    # Dapatkan IP
    current_ip=$(ip route get 1 | awk '{print $NF;exit}' 2>/dev/null)
    
    log_success "SSH Server berhasil diinstall!"
    echo -e "   ${CYAN}Server:${NC} ssh://$current_ip:22"
    echo -e "   ${CYAN}Username:${NC} admin"
    echo -e "   ${CYAN}Private Key:${NC} /home/admin/.ssh/id_rsa"
    echo -e "   ${YELLOW}IMPORTANT: Password authentication DISABLED${NC}"
}

# =====================================================
# FUNGSI INSTALL SEMUA
# =====================================================

install_all() {
    log_step "Instalasi semua service..."
    print_separator
    
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
    
    print_separator
    log_success "Semua service berhasil diinstall!"
    print_separator
    
    current_ip=$(ip route get 1 | awk '{print $NF;exit}' 2>/dev/null)
    echo ""
    echo -e "${GREEN}${BOLD}============================================================${NC}"
    echo -e "${GREEN}${BOLD}                   INFORMASI SERVICE                       ${NC}"
    echo -e "${GREEN}${BOLD}============================================================${NC}"
    echo ""
    echo -e "${CYAN}Web Server:${NC} http://$current_ip"
    echo -e "${CYAN}FTP Server:${NC} ftp://$current_ip (admin:123)"
    echo -e "${CYAN}SSH Server:${NC} ssh://$current_ip:22 (key-based)"
    echo ""
    echo -e "${YELLOW}Credential:${NC}"
    echo -e "  - FTP: admin / 123"
    echo -e "  - SSH Private Key: /home/admin/.ssh/id_rsa"
    echo ""
}

# =====================================================
# FUNGSI MENU UTAMA
# =====================================================

show_menu() {
    echo ""
    print_separator
    echo -e "${YELLOW}${BOLD}                      MENU UTAMA                         ${NC}"
    print_separator
    echo ""
    echo -e "  ${CYAN}1.${NC} Setup IP Static"
    echo -e "  ${CYAN}2.${NC} Setup DNS Server"
    echo -e "  ${CYAN}3.${NC} Install Apache2 (Web Server)"
    echo -e "  ${CYAN}4.${NC} Install FTP (vsftpd)"
    echo -e "  ${CYAN}5.${NC} Install SSH (Secure Server)"
    echo -e "  ${CYAN}6.${NC} Install Semua Service"
    echo -e "  ${CYAN}7.${NC} Exit"
    echo ""
    print_separator
    echo -ne "${GREEN}Pilih menu [1-7]: ${NC}"
}

# =====================================================
# MAIN PROGRAM
# =====================================================

check_root

while true; do
    show_banner
    
    # Tampilkan IP saat ini
    current_ip=$(ip route get 1 | awk '{print $NF;exit}' 2>/dev/null)
    if [[ -n "$current_ip" ]]; then
        echo -e "   ${WHITE}Current IP Address:${NC} ${GREEN}$current_ip${NC}"
    else
        echo -e "   ${WHITE}Current IP Address:${NC} ${RED}Not configured${NC}"
    fi
    echo ""
    
    show_menu
    read choice
    
    case $choice in
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
            echo -e "${GREEN}Terima kasih telah menggunakan TechCorp Server Setup Script!${NC}"
            echo -e "${CYAN}TechCorp - Solusi Teknologi Terpercaya${NC}"
            echo ""
            exit 0
            ;;
        *)
            log_error "Pilihan tidak valid! Silakan pilih 1-7"
            sleep 2
            ;;
    esac
    
    echo ""
    read -p "Tekan Enter untuk kembali ke menu utama..."
done

'@

# Generate file test.sh
$outputPath = ".\test.sh"

if (Test-Path $outputPath) {
    Remove-Item $outputPath -Force
}

# Simpan dengan encoding UTF-8
$setupScriptContent | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "           SCRIPT BERHASIL DIGENERATE                      " -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "File: test.sh" -ForegroundColor Cyan
Write-Host "Size: $([math]::Round((Get-Item $outputPath).Length/1KB, 2)) KB" -ForegroundColor Cyan
Write-Host "Lines: $($setupScriptContent.Split("`n").Count)" -ForegroundColor Cyan
Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host "                   CARA MENGGUNAKAN                         " -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Transfer ke server: scp test.sh user@server:/home/user/" -ForegroundColor White
Write-Host "2. chmod +x test.sh" -ForegroundColor White
Write-Host "3. sudo ./test.sh" -ForegroundColor White
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "                   MENU YANG TERSEDIA                       " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Setup IP Static     - Konfigurasi IP Address static" -ForegroundColor Green
Write-Host "2. Setup DNS Server    - Konfigurasi DNS (Google/Cloudflare/Manual)" -ForegroundColor Green
Write-Host "3. Install Apache2     - Web server dengan halaman custom" -ForegroundColor Green
Write-Host "4. Install FTP         - vsftpd dengan user admin:123" -ForegroundColor Green
Write-Host "5. Install SSH         - SSH hardening dengan key-based auth" -ForegroundColor Green
Write-Host "6. Install Semua       - Install semua service sekaligus" -ForegroundColor Green
Write-Host "7. Exit                - Keluar dari script" -ForegroundColor Green
Write-Host ""
Write-Host "Script siap digunakan!" -ForegroundColor Green