#!/bin/bash

# =====================================================
# Script: Multi-Service Installer for Debian
# Author: TechCorp
# Description: Install and configure Apache2, vsftpd, OpenSSH, DNS Server, DHCP Server, and WordPress
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
DHCP_INTERFACE=""
DHCP_PREFIX="24"
DHCP_NETMASK="255.255.255.0"
DHCP_RANGE_START=""
DHCP_RANGE_END=""
DHCP_ROUTER=""
DHCP_DNS=""
SYSTEM_UPDATED=false

# Fungsi untuk konversi prefix ke netmask
prefix_to_netmask() {
    local prefix=$1
    local mask=0
    for i in $(seq 1 $prefix); do
        mask=$(( (mask << 1) | 1 ))
    done
    for i in $(seq $((prefix + 1)) 32); do
        mask=$((mask << 1))
    done
    printf "%d.%d.%d.%d" \
        $(( (mask >> 24) & 255 )) \
        $(( (mask >> 16) & 255 )) \
        $(( (mask >> 8) & 255 )) \
        $(( mask & 255 ))
}

# Fungsi untuk menghitung network address dari IP dan prefix
get_network_address() {
    local ip=$1
    local prefix=$2
    IFS=. read -r i1 i2 i3 i4 <<< "$ip"
    local ip_int=$(( (i1 << 24) + (i2 << 16) + (i3 << 8) + i4 ))
    local mask_int=0
    for i in $(seq 1 $prefix); do
        mask_int=$(( (mask_int << 1) | 1 ))
    done
    for i in $(seq $((prefix + 1)) 32); do
        mask_int=$((mask_int << 1))
    done
    local network_int=$((ip_int & mask_int))
    printf "%d.%d.%d.%d" \
        $(( (network_int >> 24) & 255 )) \
        $(( (network_int >> 16) & 255 )) \
        $(( (network_int >> 8) & 255 )) \
        $(( network_int & 255 ))
}

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

# Fungsi untuk update system (opsional)
system_update() {
    if [[ "$SYSTEM_UPDATED" == true ]]; then
        log_info "System sudah diupdate sebelumnya, melewati..."
        return 0
    fi
    
    echo ""
    echo -e "${YELLOW}Apakah Anda ingin mengupdate sistem terlebih dahulu?${NC}"
    echo -e "${CYAN}  (Jika sudah pernah update, pilih 'n' untuk mempercepat proses)${NC}"
    echo -ne "${GREEN}Update sistem? (y/n, default: n): ${NC}"
    read -p "" do_update
    
    if [[ "$do_update" =~ ^[Yy]$ ]]; then
        log_step "Mengupdate sistem..."
        apt update -y
        apt upgrade -y
        apt autoremove -y
        apt autoclean
        log_info "Update sistem selesai"
        SYSTEM_UPDATED=true
    else
        log_info "Melewati update sistem (menggunakan paket yang sudah ada)"
        # Tetap lakukan apt update ringan untuk sync package list
        apt update -y 2>/dev/null
    fi
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

# Fungsi untuk memilih interface untuk DHCP
choose_dhcp_interface() {
    local interfaces=()
    local idx=1
    local choice=""
    
    while IFS= read -r line; do
        interfaces+=("$line")
    done < <(ip -o link show | awk -F': ' '{print $2}' | grep -v lo)
    
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}Pilih interface untuk DHCP Server:${NC}"
    echo -e "${CYAN}========================================${NC}"
    for iface in "${interfaces[@]}"; do
        local ip_addr=$(ip -4 addr show $iface 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
        local prefix=$(ip -4 addr show $iface 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | head -1 | cut -d'/' -f2)
        if [[ -n "$ip_addr" ]]; then
            echo -e "  ${YELLOW}${idx}.${NC} $iface -> $ip_addr/${prefix:-24}"
        else
            echo -e "  ${YELLOW}${idx}.${NC} $iface -> (no IP assigned)"
        fi
        idx=$((idx + 1))
    done
    
    while true; do
        echo -ne "${GREEN}Pilih interface [1-${#interfaces[@]}]: ${NC}"
        if ! IFS= read -r choice < /dev/tty; then
            choice=""
        fi
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#interfaces[@]} )); then
            DHCP_INTERFACE="${interfaces[$((choice - 1))]}"
            
            local interface_info=$(ip -4 addr show $DHCP_INTERFACE 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | head -1)
            if [[ -n "$interface_info" ]]; then
                local interface_ip=$(echo $interface_info | cut -d'/' -f1)
                local detected_prefix=$(echo $interface_info | cut -d'/' -f2)
                DHCP_PREFIX="${detected_prefix:-24}"
                DHCP_NETMASK=$(prefix_to_netmask $DHCP_PREFIX)
                DHCP_SUBNET=$(get_network_address $interface_ip $DHCP_PREFIX)
                DHCP_ROUTER=$interface_ip
                log_info "Mendeteksi subnet: $DHCP_SUBNET/$DHCP_PREFIX"
                log_info "Gateway: $DHCP_ROUTER"
            else
                DHCP_PREFIX="24"
                DHCP_NETMASK="255.255.255.0"
                DHCP_SUBNET="192.168.1.0"
                DHCP_ROUTER="192.168.1.1"
                log_warning "Tidak ada IP terdeteksi, menggunakan default: $DHCP_SUBNET/$DHCP_PREFIX"
            fi
            return 0
        fi
        
        log_error "Pilihan tidak valid."
    done
}

# Fungsi untuk konfigurasi range DHCP
configure_dhcp_range() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}Konfigurasi DHCP Server${NC}"
    echo -e "${CYAN}========================================${NC}"
    
    echo -ne "${GREEN}Masukkan prefix network (1-32, default: $DHCP_PREFIX): ${NC}"
    read -p "" prefix_input
    if [[ -n "$prefix_input" ]] && [[ "$prefix_input" =~ ^[0-9]+$ ]] && (( prefix_input >= 1 && prefix_input <= 32 )); then
        DHCP_PREFIX=$prefix_input
        DHCP_NETMASK=$(prefix_to_netmask $DHCP_PREFIX)
        if [[ -n "$DHCP_ROUTER" ]]; then
            DHCP_SUBNET=$(get_network_address $DHCP_ROUTER $DHCP_PREFIX)
        fi
    fi
    
    echo -e "${CYAN}Subnet: $DHCP_SUBNET/$DHCP_PREFIX${NC}"
    echo ""
    
    echo -e "${YELLOW}Masukkan range IP (cukup angka akhir saja)${NC}"
    echo -e "${YELLOW}Contoh: 100-200 -> ${DHCP_SUBNET%.*}.100 - ${DHCP_SUBNET%.*}.200${NC}"
    
    echo -ne "${GREEN}Range awal (contoh: 100): ${NC}"
    read -p "" range_start
    echo -ne "${GREEN}Range akhir (contoh: 200): ${NC}"
    read -p "" range_end
    
    if [[ -z "$range_start" ]]; then
        range_start=100
    fi
    if [[ -z "$range_end" ]]; then
        range_end=200
    fi
    
    local network_prefix="${DHCP_SUBNET%.*}"
    DHCP_RANGE_START="${network_prefix}.${range_start}"
    DHCP_RANGE_END="${network_prefix}.${range_end}"
    
    echo ""
    echo -ne "${GREEN}Gateway (default: $DHCP_ROUTER): ${NC}"
    read -p "" gateway_input
    if [[ -n "$gateway_input" ]]; then
        DHCP_ROUTER=$gateway_input
        DHCP_SUBNET=$(get_network_address $DHCP_ROUTER $DHCP_PREFIX)
        network_prefix="${DHCP_SUBNET%.*}"
        DHCP_RANGE_START="${network_prefix}.${range_start}"
        DHCP_RANGE_END="${network_prefix}.${range_end}"
    fi
    
    echo ""
    echo -ne "${GREEN}DNS server (default: 8.8.8.8, 8.8.4.4): ${NC}"
    read -p "" dns_input
    if [[ -n "$dns_input" ]]; then
        DHCP_DNS=$dns_input
    else
        DHCP_DNS="8.8.8.8, 8.8.4.4"
    fi
    
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${YELLOW}Ringkasan Konfigurasi DHCP:${NC}"
    echo -e "  Interface: $DHCP_INTERFACE"
    echo -e "  Subnet: $DHCP_SUBNET/$DHCP_PREFIX"
    echo -e "  Range: $DHCP_RANGE_START - $DHCP_RANGE_END"
    echo -e "  Gateway: $DHCP_ROUTER"
    echo -e "  DNS: $DHCP_DNS"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    echo -ne "${GREEN}Konfigurasi sudah benar? (y/n): ${NC}"
    read -p "" confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_warning "Konfigurasi dibatalkan"
        return 1
    fi
    
    return 0
}

# Fungsi untuk mengecek port 80
get_port_80_listener() {
    ss -tulpn 2>/dev/null | awk '/:80[[:space:]]/ && /LISTEN/ {print; exit}'
}

# ─── Banner ──────────────────────────────────────────────────
show_banner() {
    clear
    echo -e "${BLUE}${BOLD}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║    ████████╗███████╗ ██████╗██╗  ██╗ ██████╗ ██████╗ ██████╗ ██████╗         ║
║    ╚══██╔══╝██╔════╝██╔════╝██║  ██║██╔════╝██╔═══██╗██╔══██╗██╔══██╗        ║
║       ██║   █████╗  ██║     ███████║██║     ██║   ██║██████╔╝██████╔╝        ║
║       ██║   ██╔══╝  ██║     ██╔══██║██║     ██║   ██║██╔══██╗██╔═══╝         ║
║       ██║   ███████╗╚██████╗██║  ██║╚██████╗╚██████╔╝██║  ██║██║             ║
║       ╚═╝   ╚══════╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝             ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "${CYAN}${BOLD}====================================================================${NC}"
    echo -e "${YELLOW}${BOLD}      Multi-Service Installer | Apache2 + vsftpd + OpenSSH + DNS + DHCP${NC}"
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
    
    # Install tanpa upgrade paket yang sudah ada
    apt install -y --no-upgrade apache2 2>/dev/null || apt install -y apache2
    
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
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #0a0a1a; color: #e0e0e0; }
        header { background: linear-gradient(135deg, #1a1a3e, #0d47a1); padding: 60px 20px; text-align: center; border-bottom: 3px solid #2196F3; }
        header h1 { font-size: 3.5em; color: #2196F3; letter-spacing: 4px; text-shadow: 0 0 20px rgba(33,150,243,0.5); }
        header p { font-size: 1.2em; color: #90CAF9; margin-top: 10px; }
        nav { background: #0d1b2a; padding: 15px; text-align: center; position: sticky; top: 0; z-index: 100; }
        nav a { color: #2196F3; text-decoration: none; margin: 0 20px; font-weight: bold; font-size: 1em; transition: color 0.3s; }
        nav a:hover { color: #64B5F6; }
        .container { max-width: 1100px; margin: 0 auto; padding: 40px 20px; }
        .section { margin-bottom: 60px; }
        .section h2 { font-size: 2em; color: #2196F3; border-left: 5px solid #2196F3; padding-left: 15px; margin-bottom: 20px; }
        .about-text { font-size: 1.1em; line-height: 1.8; color: #b0bec5; }
        .services-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 25px; margin-top: 20px; }
        .service-card { background: #0d1b2a; border: 1px solid #1565C0; border-radius: 12px; padding: 30px; text-align: center; transition: transform 0.3s, box-shadow 0.3s; }
        .service-card:hover { transform: translateY(-8px); box-shadow: 0 10px 30px rgba(33,150,243,0.3); }
        .service-card .icon { font-size: 3em; margin-bottom: 15px; }
        .service-card h3 { color: #2196F3; font-size: 1.3em; margin-bottom: 10px; }
        .service-card p { color: #90A4AE; line-height: 1.6; }
        .contact-info { background: #0d1b2a; border-radius: 12px; padding: 30px; border: 1px solid #1565C0; }
        .contact-info p { margin: 12px 0; font-size: 1.05em; color: #b0bec5; }
        .contact-info span { color: #2196F3; font-weight: bold; }
        footer { background: #050510; text-align: center; padding: 25px; color: #546E7A; border-top: 1px solid #1565C0; }
        footer span { color: #2196F3; }
    </style>
</head>
<body>
    <header>
        <h1>⚡ TECHCORP</h1>
        <p>Solusi Teknologi Terdepan untuk Bisnis Modern</p>
    </header>
    <nav>
        <a href="#about">Tentang Kami</a>
        <a href="#services">Layanan</a>
        <a href="#contact">Kontak</a>
    </nav>
    <div class="container">
        <div class="section" id="about">
            <h2>Tentang Kami</h2>
            <p class="about-text">
                <strong style="color:#2196F3">TechCorp</strong> adalah perusahaan teknologi terkemuka yang berdedikasi
                untuk memberikan solusi digital inovatif kepada klien kami.
            </p>
        </div>
        <div class="section" id="services">
            <h2>Layanan Kami</h2>
            <div class="services-grid">
                <div class="service-card"><div class="icon">🌐</div><h3>Web Development</h3><p>Pengembangan website modern.</p></div>
                <div class="service-card"><div class="icon">🔒</div><h3>Cybersecurity</h3><p>Perlindungan dari ancaman siber.</p></div>
                <div class="service-card"><div class="icon">📡</div><h3>Network Solutions</h3><p>Infrastruktur jaringan handal.</p></div>
                <div class="service-card"><div class="icon">🖥️</div><h3>DHCP Server</h3><p>Manajemen IP address otomatis.</p></div>
            </div>
        </div>
        <div class="section" id="contact">
            <h2>Kontak</h2>
            <div class="contact-info">
                <p>🏢 TechCorp Indonesia | 📧 info@techcorp.id | 📞 +62 21 1234 5678</p>
            </div>
        </div>
    </div>
    <footer><p>&copy; 2025 TechCorp Indonesia. All Rights Reserved.</p></footer>
</body>
</html>
HTMLEOF
    
    chown -R www-data:www-data /var/www/html/
    chmod -R 755 /var/www/html/
    
    systemctl enable apache2 2>/dev/null
    systemctl restart apache2
    
    log_info "✅ Apache2 berhasil diinstall!"
    log_info "   Akses: http://${APACHE_ACCESS_IP}"
}

# Fungsi untuk install vsftpd
install_ftp() {
    log_step "Menginstall vsftpd FTP Server..."
    
    if systemctl is-active --quiet vsftpd 2>/dev/null; then
        log_warning "vsftpd sudah terinstall"
        read -p "Apakah ingin reinstall? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Melewati instalasi vsftpd"
            return 0
        fi
    fi
    
    apt install -y --no-upgrade vsftpd 2>/dev/null || apt install -y vsftpd
    
    cp /etc/vsftpd.conf /etc/vsftpd.conf.bak 2>/dev/null
    
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
allow_writeable_chroot=YES
FTPEOF
    
    if ! id "admin" &>/dev/null; then
        log_info "Membuat user admin..."
        useradd -m -s /bin/bash admin
        echo "admin:123" | chpasswd
    fi
    
    systemctl restart vsftpd
    systemctl enable vsftpd 2>/dev/null
    
    log_info "✅ vsftpd berhasil diinstall!"
    log_info "   User: admin | Password: 123"
}

# Fungsi untuk install SSH Server
install_ssh() {
    log_step "Menginstall OpenSSH Server..."
    
    apt install -y --no-upgrade openssh-server 2>/dev/null || apt install -y openssh-server
    
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak 2>/dev/null
    
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    
    mkdir -p /home/admin/.ssh
    chmod 700 /home/admin/.ssh
    
    if [[ ! -f /home/admin/.ssh/id_rsa ]]; then
        ssh-keygen -t rsa -b 4096 -f /home/admin/.ssh/id_rsa -N "" -C "admin@techcorp"
    fi
    
    cp /home/admin/.ssh/id_rsa.pub /home/admin/.ssh/authorized_keys
    chmod 600 /home/admin/.ssh/authorized_keys
    chown -R admin:admin /home/admin/.ssh
    
    systemctl restart sshd
    systemctl enable sshd 2>/dev/null
    
    log_info "✅ OpenSSH berhasil dikonfigurasi!"
    log_info "   Private key: /home/admin/.ssh/id_rsa"
}

# Fungsi untuk install DNS Server
install_dns() {
    log_step "Menginstall DNS Server (Bind9)..."
    
    apt install -y --no-upgrade bind9 bind9utils dnsutils 2>/dev/null || apt install -y bind9 bind9utils dnsutils
    
    DNS_IP=$(choose_ip "DNS Server")
    
    echo ""
    echo -ne "${GREEN}Nama domain (contoh: techcorp.local): ${NC}"
    read -p "" DOMAIN_NAME
    [[ -z "$DOMAIN_NAME" ]] && DOMAIN_NAME="techcorp.local"
    
    cat > /etc/bind/named.conf.options << OPTIONSEOF
options {
    directory "/var/cache/bind";
    forwarders { 8.8.8.8; 8.8.4.4; };
    allow-query { any; };
    recursion yes;
    dnssec-validation auto;
    listen-on { $DNS_IP; 127.0.0.1; };
    listen-on-v6 { none; };
};
OPTIONSEOF
    
    cat > /etc/bind/named.conf.local << LOCALSEOF
zone "$DOMAIN_NAME" {
    type master;
    file "/etc/bind/db.$DOMAIN_NAME";
};
LOCALSEOF
    
    SERIAL=$(date +%Y%m%d%S)
    cat > /etc/bind/db.$DOMAIN_NAME << FORWARDEOF
\$TTL    604800
@       IN      SOA     ns1.$DOMAIN_NAME. admin.$DOMAIN_NAME. ($SERIAL 604800 86400 2419200 604800)
@       IN      NS      ns1.$DOMAIN_NAME.
@       IN      A       $DNS_IP
ns1     IN      A       $DNS_IP
www     IN      A       $DNS_IP
ftp     IN      A       $DNS_IP
FORWARDEOF
    
    chown -R bind:bind /etc/bind/
    systemctl restart bind9
    systemctl enable bind9 2>/dev/null
    
    log_info "✅ DNS Server berhasil diinstall!"
    log_info "   Domain: $DOMAIN_NAME | IP: $DNS_IP"
}

# Fungsi untuk install DHCP Server
install_dhcp() {
    log_step "Menginstall DHCP Server (isc-dhcp-server)..."
    
    apt install -y --no-upgrade isc-dhcp-server 2>/dev/null || apt install -y isc-dhcp-server
    
    choose_dhcp_interface
    if ! configure_dhcp_range; then
        return 1
    fi
    
    cat > /etc/dhcp/dhcpd.conf << DHPCEOF
option domain-name "$DOMAIN_NAME";
option domain-name-servers $DHCP_DNS;
default-lease-time 600;
max-lease-time 7200;

subnet $DHCP_SUBNET netmask $DHCP_NETMASK {
    range $DHCP_RANGE_START $DHCP_RANGE_END;
    option routers $DHCP_ROUTER;
    option subnet-mask $DHCP_NETMASK;
    option domain-name-servers $DHCP_DNS;
    option domain-name "$DOMAIN_NAME";
    authoritative;
}
DHPCEOF
    
    echo "INTERFACESv4=\"$DHCP_INTERFACE\"" > /etc/default/isc-dhcp-server
    
    systemctl restart isc-dhcp-server
    systemctl enable isc-dhcp-server 2>/dev/null
    
    log_info "✅ DHCP Server berhasil diinstall!"
    log_info "   Interface: $DHCP_INTERFACE | Subnet: $DHCP_SUBNET/$DHCP_PREFIX"
    log_info "   Range: $DHCP_RANGE_START - $DHCP_RANGE_END"
}

# Fungsi untuk install WordPress
install_wordpress() {
    log_step "Menginstall WordPress..."
    
    if ! systemctl is-active --quiet apache2 2>/dev/null; then
        log_error "Apache2 harus diinstall terlebih dahulu!"
        return 1
    fi
    
    apt install -y --no-upgrade php php-mysql php-curl php-gd php-mbstring php-xml php-zip mariadb-server wget 2>/dev/null || \
    apt install -y php php-mysql php-curl php-gd php-mbstring php-xml php-zip mariadb-server wget
    
    systemctl start mariadb
    systemctl enable mariadb 2>/dev/null
    
    mysql << 'SQLEOF'
CREATE DATABASE IF NOT EXISTS wordpress;
CREATE USER IF NOT EXISTS 'wpuser'@'localhost' IDENTIFIED BY 'wp123456';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'localhost';
FLUSH PRIVILEGES;
SQLEOF
    
    cd /tmp
    wget -q https://wordpress.org/latest.tar.gz
    tar -xzf latest.tar.gz
    mkdir -p /var/www/html/wordpress
    cp -r /tmp/wordpress/* /var/www/html/wordpress/
    
    cp /var/www/html/wordpress/wp-config-sample.php /var/www/html/wordpress/wp-config.php
    sed -i "s/database_name_here/wordpress/" /var/www/html/wordpress/wp-config.php
    sed -i "s/username_here/wpuser/" /var/www/html/wordpress/wp-config.php
    sed -i "s/password_here/wp123456/" /var/www/html/wordpress/wp-config.php
    
    chown -R www-data:www-data /var/www/html/wordpress/
    systemctl restart apache2
    rm -rf /tmp/wordpress*
    
    log_info "✅ WordPress berhasil diinstall!"
    log_info "   URL: http://${APACHE_ACCESS_IP}/wordpress"
}

# Fungsi untuk install semua service basic
install_all_basic() {
    system_update
    install_apache
    install_ftp
    install_ssh
    install_wordpress
    
    echo ""
    log_info "=========================================="
    log_info "✅ SEMUA SERVICE BASIC BERHASIL DIINSTALL!"
    log_info "=========================================="
    log_info "Apache: http://${APACHE_ACCESS_IP}"
    log_info "FTP: ftp://${APACHE_ACCESS_IP} (admin/123)"
    log_info "SSH: ssh admin@${APACHE_ACCESS_IP}"
    log_info "WordPress: http://${APACHE_ACCESS_IP}/wordpress"
    log_info "=========================================="
}

# Fungsi untuk install semua service complete
install_all_complete() {
    system_update
    install_apache
    install_ftp
    install_ssh
    install_dns
    install_dhcp
    install_wordpress
    
    echo ""
    log_info "=========================================="
    log_info "✅ SEMUA SERVICE COMPLETE BERHASIL DIINSTALL!"
    log_info "=========================================="
    log_info "Apache: http://${APACHE_ACCESS_IP}"
    log_info "FTP: ftp://${APACHE_ACCESS_IP} (admin/123)"
    log_info "SSH: ssh admin@${APACHE_ACCESS_IP}"
    log_info "DNS: $DOMAIN_NAME @ $DNS_IP"
    log_info "DHCP: $DHCP_INTERFACE ($DHCP_SUBNET/$DHCP_PREFIX)"
    log_info "WordPress: http://${APACHE_ACCESS_IP}/wordpress"
    log_info "=========================================="
}

# Menu utama
show_menu() {
    echo ""
    echo -e "${YELLOW}${BOLD}========================================${NC}"
    echo -e "${YELLOW}${BOLD}          MENU INSTALASI               ${NC}"
    echo -e "${YELLOW}${BOLD}========================================${NC}"
    echo -e "${GREEN}1.${NC} Install Semua Service (Basic)"
    echo -e "${GREEN}2.${NC} Install Semua Service (Complete + DNS + DHCP)"
    echo -e "${CYAN}3.${NC} Install Apache2"
    echo -e "${CYAN}4.${NC} Install FTP"
    echo -e "${CYAN}5.${NC} Install SSH"
    echo -e "${CYAN}6.${NC} Install DNS Server"
    echo -e "${CYAN}7.${NC} Install DHCP Server"
    echo -e "${CYAN}8.${NC} Install WordPress"
    echo -e "${RED}9.${NC} Exit"
    echo -e "${YELLOW}========================================${NC}"
    echo -ne "${GREEN}Pilih menu (1-9): ${NC}"
}

# Main program
check_root

while true; do
    show_banner
    show_menu
    read -r choice
    
    case $choice in
        1) install_all_basic ;;
        2) install_all_complete ;;
        3) system_update; install_apache ;;
        4) system_update; install_ftp ;;
        5) system_update; install_ssh ;;
        6) system_update; install_dns ;;
        7) system_update; install_dhcp ;;
        8) system_update; install_wordpress ;;
        9) 
            log_info "Terima kasih telah menggunakan TechCorp Installer!"
            exit 0
            ;;
        *) log_error "Pilihan tidak valid!"; sleep 1 ;;
    esac
    
    echo ""
    read -p "Tekan Enter untuk kembali ke menu..." < /dev/tty
done