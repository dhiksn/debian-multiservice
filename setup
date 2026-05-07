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
DOMAIN_NAME="techcorp.local"
DHCP_INTERFACE=""
DHCP_PREFIX="24"
DHCP_NETMASK="255.255.255.0"
DHCP_RANGE_START=""
DHCP_RANGE_END=""
DHCP_ROUTER=""
DHCP_DNS=""
SYSTEM_UPDATED=false

# Fungsi untuk membaca input dengan aman
safe_read() {
    local prompt="$1"
    local var_name="$2"
    local input=""
    printf "%s" "$prompt" >&2
    if ! IFS= read -r input < /dev/tty; then
        input=""
    fi
    eval "$var_name='$input'"
}

# Fungsi untuk membaca pilihan menu
menu_read() {
    local input=""
    printf "%s" "$1" >&2
    if ! IFS= read -r input < /dev/tty; then
        input=""
    fi
    echo "$input"
}

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

# Fungsi untuk menghitung network address
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

# Fungsi logging
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

# Banner
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

# Cek root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Script ini harus dijalankan sebagai root!"
        exit 1
    fi
}

# Update system opsional
system_update() {
    if [[ "$SYSTEM_UPDATED" == true ]]; then
        log_info "System sudah diupdate sebelumnya"
        return 0
    fi
    
    echo ""
    echo -e "${YELLOW}Apakah Anda ingin mengupdate sistem terlebih dahulu?${NC}"
    echo -e "${CYAN}  (Jika sudah pernah update, pilih 'n' untuk mempercepat proses)${NC}"
    printf "${GREEN}Update sistem? (y/n, default: n): ${NC}"
    read do_update < /dev/tty
    
    if [[ "$do_update" =~ ^[Yy]$ ]]; then
        log_step "Mengupdate sistem..."
        apt update -y
        apt upgrade -y
        apt autoremove -y
        apt autoclean
        log_info "Update sistem selesai"
        SYSTEM_UPDATED=true
    else
        log_info "Melewati upgrade (hanya sync package list)"
        apt update -y 2>/dev/null
    fi
}

# Get interfaces
get_interfaces() {
    ip -o -4 addr show up scope global | awk '{print $2 "|" $4}'
}

# Pilih IP
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
        printf "${GREEN}Pilih interface [1-%d] (default 1): ${NC}" "${#interfaces[@]}"
        read choice < /dev/tty
        
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

# Pilih interface DHCP
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
        printf "${GREEN}Pilih interface [1-%d]: ${NC}" "${#interfaces[@]}"
        read choice < /dev/tty
        
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
                log_warning "Tidak ada IP terdeteksi, menggunakan default"
            fi
            return 0
        fi
        
        log_error "Pilihan tidak valid."
    done
}

# Konfigurasi range DHCP
configure_dhcp_range() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}Konfigurasi DHCP Server${NC}"
    echo -e "${CYAN}========================================${NC}"
    
    printf "${GREEN}Prefix network (1-32, default: $DHCP_PREFIX): ${NC}"
    read prefix_input < /dev/tty
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
    
    printf "${GREEN}Range awal (default: 100): ${NC}"
    read range_start < /dev/tty
    printf "${GREEN}Range akhir (default: 200): ${NC}"
    read range_end < /dev/tty
    
    [[ -z "$range_start" ]] && range_start=100
    [[ -z "$range_end" ]] && range_end=200
    
    local network_prefix="${DHCP_SUBNET%.*}"
    DHCP_RANGE_START="${network_prefix}.${range_start}"
    DHCP_RANGE_END="${network_prefix}.${range_end}"
    
    echo ""
    printf "${GREEN}Gateway (default: $DHCP_ROUTER): ${NC}"
    read gateway_input < /dev/tty
    if [[ -n "$gateway_input" ]]; then
        DHCP_ROUTER=$gateway_input
        DHCP_SUBNET=$(get_network_address $DHCP_ROUTER $DHCP_PREFIX)
        network_prefix="${DHCP_SUBNET%.*}"
        DHCP_RANGE_START="${network_prefix}.${range_start}"
        DHCP_RANGE_END="${network_prefix}.${range_end}"
    fi
    
    echo ""
    printf "${GREEN}DNS server (default: 8.8.8.8, 8.8.4.4): ${NC}"
    read dns_input < /dev/tty
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
    
    printf "${GREEN}Konfigurasi sudah benar? (y/n): ${NC}"
    read confirm < /dev/tty
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_warning "Konfigurasi dibatalkan"
        return 1
    fi
    
    return 0
}

# Install Apache2
install_apache() {
    log_step "Menginstall Apache2 Web Server..."
    apt install -y apache2
    APACHE_ACCESS_IP=$(choose_ip "Apache2 Web Server")
    
    cat > /var/www/html/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html>
<head><title>TechCorp</title>
<style>
body{font-family:Arial;background:#0a0a1a;color:#fff;text-align:center;padding:50px}
h1{color:#2196F3}
</style>
</head>
<body>
<h1>⚡ TECHCORP</h1>
<p>Multi-Service Installer | Apache2 + vsftpd + OpenSSH + DNS + DHCP</p>
<p>Server berjalan dengan baik!</p>
<hr>
<p>&copy; 2025 TechCorp Indonesia</p>
</body>
</html>
HTMLEOF
    
    chown -R www-data:www-data /var/www/html/
    systemctl enable apache2
    systemctl restart apache2
    log_info "✅ Apache2 berhasil diinstall! Akses: http://${APACHE_ACCESS_IP}"
}

# Install FTP
install_ftp() {
    log_step "Menginstall vsftpd FTP Server..."
    apt install -y vsftpd
    
    cat > /etc/vsftpd.conf << 'FTPEOF'
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
chroot_local_user=YES
allow_writeable_chroot=YES
pam_service_name=vsftpd
FTPEOF
    
    if ! id "admin" &>/dev/null; then
        useradd -m -s /bin/bash admin
        echo "admin:123" | chpasswd
    fi
    
    systemctl restart vsftpd
    systemctl enable vsftpd
    log_info "✅ vsftpd berhasil! User: admin | Pass: 123"
}

# Install SSH
install_ssh() {
    log_step "Menginstall OpenSSH Server..."
    apt install -y openssh-server
    
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
    systemctl enable sshd
    log_info "✅ OpenSSH berhasil! Private key: /home/admin/.ssh/id_rsa"
}

# Install DNS
install_dns() {
    log_step "Menginstall DNS Server (Bind9)..."
    apt install -y bind9 bind9utils dnsutils
    DNS_IP=$(choose_ip "DNS Server")
    
    printf "${GREEN}Nama domain (default: techcorp.local): ${NC}"
    read DOMAIN_NAME < /dev/tty
    [[ -z "$DOMAIN_NAME" ]] && DOMAIN_NAME="techcorp.local"
    
    cat > /etc/bind/named.conf.options << OPTIONSEOF
options {
    directory "/var/cache/bind";
    forwarders { 8.8.8.8; 8.8.4.4; };
    allow-query { any; };
    recursion yes;
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
FORWARDEOF
    
    chown -R bind:bind /etc/bind/
    systemctl restart bind9
    systemctl enable bind9
    log_info "✅ DNS Server berhasil! Domain: $DOMAIN_NAME | IP: $DNS_IP"
}

# Install DHCP
install_dhcp() {
    log_step "Menginstall DHCP Server (isc-dhcp-server)..."
    apt install -y isc-dhcp-server
    choose_dhcp_interface
    configure_dhcp_range || return 1
    
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
    systemctl enable isc-dhcp-server
    
    log_info "✅ DHCP Server berhasil! Interface: $DHCP_INTERFACE | Subnet: $DHCP_SUBNET/$DHCP_PREFIX"
    log_info "   Range: $DHCP_RANGE_START - $DHCP_RANGE_END"
}

# Install WordPress
install_wordpress() {
    log_step "Menginstall WordPress..."
    if ! systemctl is-active --quiet apache2; then
        log_error "Apache2 harus diinstall terlebih dahulu!"
        return 1
    fi
    
    apt install -y php php-mysql php-curl php-gd php-mbstring php-xml php-zip mariadb-server wget
    systemctl start mariadb
    systemctl enable mariadb
    
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
    log_info "✅ WordPress berhasil! URL: http://${APACHE_ACCESS_IP}/wordpress"
}

# Install semua basic
install_all_basic() {
    system_update
    install_apache
    install_ftp
    install_ssh
    install_wordpress
    echo ""
    log_info "✅ SEMUA SERVICE BASIC BERHASIL DIINSTALL!"
}

# Install semua complete
install_all_complete() {
    system_update
    install_apache
    install_ftp
    install_ssh
    install_dns
    install_dhcp
    install_wordpress
    echo ""
    log_info "✅ SEMUA SERVICE COMPLETE BERHASIL DIINSTALL!"
}

# Menu
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
    printf "${GREEN}Pilih menu (1-9): ${NC}"
}

# ==================== MAIN ====================
check_root

while true; do
    show_banner
    show_menu
    read choice < /dev/tty
    
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
            echo ""
            log_info "Terima kasih telah menggunakan TechCorp Installer!"
            exit 0
            ;;
        *) 
            echo ""
            log_error "Pilihan tidak valid! Masukkan angka 1-9"
            sleep 2
            ;;
    esac
    
    echo ""
    printf "${YELLOW}Tekan Enter untuk kembali ke menu...${NC}"
    read < /dev/tty
done