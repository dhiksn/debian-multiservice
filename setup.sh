#!/bin/bash

# =====================================================
# Script: Multi-Service Installer for Debian
# Author: TechCorp
# =====================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

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

# Logging
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
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

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Script harus dijalankan sebagai root!"
        exit 1
    fi
}

# Update system (opsional)
system_update() {
    if [[ "$SYSTEM_UPDATED" == true ]]; then
        return 0
    fi
    
    echo ""
    printf "${YELLOW}Update sistem? (y/n, default n): ${NC}"
    read do_update < /dev/tty
    
    if [[ "$do_update" =~ ^[Yy]$ ]]; then
        log_step "Mengupdate sistem..."
        apt update -y -qq
        apt upgrade -y -qq
        SYSTEM_UPDATED=true
    else
        apt update -y -qq 2>/dev/null
    fi
}

# Pilih IP
choose_ip() {
    local service_name=$1
    local interfaces=()
    local idx=1
    local choice=""
    
    while IFS= read -r line; do
        interfaces+=("$line")
    done < <(ip -o -4 addr show up scope global | awk '{print $2 "|" $4}')
    
    if [[ ${#interfaces[@]} -eq 0 ]]; then
        echo "$(hostname -I | awk '{print $1}')"
        return 0
    fi
    
    echo ""
    echo -e "${CYAN}Pilih IP Address untuk $service_name:${NC}"
    for line in "${interfaces[@]}"; do
        echo -e "  ${YELLOW}${idx}.${NC} ${line%%|*} -> ${line##*|}"
        idx=$((idx + 1))
    done
    
    while true; do
        printf "${GREEN}Pilih [1-%d]: ${NC}" "${#interfaces[@]}"
        read choice < /dev/tty
        if [[ -z "$choice" ]]; then
            choice=1
        fi
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#interfaces[@]} )); then
            local selected="${interfaces[$((choice - 1))]}"
            echo "${selected##*|%%/*}"
            return 0
        fi
        log_error "Pilihan tidak valid."
    done
}

# ==================== INSTALL SERVICES ====================

install_apache() {
    log_step "Install Apache2..."
    
    # CEK SUDAH TERINSTALL?
    if command -v apache2 &> /dev/null; then
        log_info "Apache2 sudah terinstall, melewati..."
        APACHE_ACCESS_IP=$(hostname -I | awk '{print $1}')
        return 0
    fi
    
    apt install -y -qq apache2
    APACHE_ACCESS_IP=$(choose_ip "Apache2")
    
    cat > /var/www/html/index.html << HTML
<!DOCTYPE html>
<html><head><title>TechCorp</title>
<style>body{font-family:Arial;background:#0a0a1a;color:#fff;text-align:center;padding:50px}
h1{color:#2196F3}</style>
</head>
<body>
<h1>⚡ TECHCORP</h1>
<p>Multi-Service Installer | Apache2 + vsftpd + OpenSSH + DNS + DHCP</p>
<p>Server berjalan dengan baik!</p>
<hr><p>&copy; 2025 TechCorp Indonesia</p>
</body></html>
HTML
    
    chown -R www-data:www-data /var/www/html/
    systemctl enable apache2 -q
    systemctl restart apache2
    log_info "✅ Apache2 selesai! http://${APACHE_ACCESS_IP}"
}

install_ftp() {
    log_step "Install vsftpd..."
    
    if command -v vsftpd &> /dev/null; then
        log_info "vsftpd sudah terinstall, melewati..."
        return 0
    fi
    
    apt install -y -qq vsftpd
    
    cat > /etc/vsftpd.conf << EOF
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
chroot_local_user=YES
allow_writeable_chroot=YES
EOF
    
    if ! id "admin" &>/dev/null; then
        useradd -m -s /bin/bash admin
        echo "admin:123" | chpasswd
    fi
    
    systemctl restart vsftpd
    systemctl enable vsftpd -q
    log_info "✅ vsftpd selesai! User: admin | Pass: 123"
}

install_ssh() {
    log_step "Install OpenSSH..."
    
    if ! command -v sshd &> /dev/null; then
        apt install -y -qq openssh-server
    fi
    
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    
    mkdir -p /home/admin/.ssh
    chmod 700 /home/admin/.ssh
    
    if [[ ! -f /home/admin/.ssh/id_rsa ]]; then
        ssh-keygen -t rsa -b 4096 -f /home/admin/.ssh/id_rsa -N "" -q
    fi
    
    cp /home/admin/.ssh/id_rsa.pub /home/admin/.ssh/authorized_keys
    chmod 600 /home/admin/.ssh/authorized_keys
    chown -R admin:admin /home/admin/.ssh
    
    systemctl restart sshd
    systemctl enable sshd -q
    log_info "✅ OpenSSH selesai!"
}

install_dns() {
    log_step "Install DNS Server..."
    
    if ! command -v named &> /dev/null; then
        apt install -y -qq bind9 bind9utils
    fi
    
    DNS_IP=$(choose_ip "DNS")
    printf "${GREEN}Domain name (default: techcorp.local): ${NC}"
    read DOMAIN_NAME < /dev/tty
    [[ -z "$DOMAIN_NAME" ]] && DOMAIN_NAME="techcorp.local"
    
    cat > /etc/bind/named.conf.options << EOF
options {
    directory "/var/cache/bind";
    forwarders { 8.8.8.8; 8.8.4.4; };
    allow-query { any; };
    recursion yes;
    listen-on { $DNS_IP; 127.0.0.1; };
    listen-on-v6 { none; };
};
EOF
    
    cat > /etc/bind/named.conf.local << EOF
zone "$DOMAIN_NAME" { type master; file "/etc/bind/db.$DOMAIN_NAME"; };
EOF
    
    SERIAL=$(date +%Y%m%d%S)
    cat > /etc/bind/db.$DOMAIN_NAME << EOF
\$TTL 604800
@ IN SOA ns1.$DOMAIN_NAME. admin.$DOMAIN_NAME. ($SERIAL 604800 86400 2419200 604800)
@ IN NS ns1.$DOMAIN_NAME.
@ IN A $DNS_IP
ns1 IN A $DNS_IP
www IN A $DNS_IP
EOF
    
    chown -R bind:bind /etc/bind/
    systemctl restart bind9
    systemctl enable bind9 -q
    log_info "✅ DNS selesai! Domain: $DOMAIN_NAME"
}

install_dhcp() {
    log_step "Install DHCP Server..."
    
    if ! command -v dhcpd &> /dev/null; then
        apt install -y -qq isc-dhcp-server
    fi
    
    # Pilih interface
    local idx=1
    local interfaces=()
    while IFS= read -r line; do
        interfaces+=("$line")
    done < <(ip -o link show | awk -F': ' '{print $2}' | grep -v lo)
    
    echo ""
    echo -e "${CYAN}Pilih interface DHCP:${NC}"
    for iface in "${interfaces[@]}"; do
        echo "  ${YELLOW}${idx}.${NC} $iface"
        idx=$((idx + 1))
    done
    
    printf "${GREEN}Pilih [1-%d]: ${NC}" "${#interfaces[@]}"
    read choice < /dev/tty
    DHCP_INTERFACE="${interfaces[$((choice-1))]}"
    
    # Dapatkan IP dari interface
    local interface_ip=$(ip -4 addr show $DHCP_INTERFACE 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
    if [[ -n "$interface_ip" ]]; then
        DHCP_SUBNET="${interface_ip%.*}.0"
        DHCP_ROUTER=$interface_ip
    else
        DHCP_SUBNET="192.168.1.0"
        DHCP_ROUTER="192.168.1.1"
    fi
    
    printf "${GREEN}Range IP (contoh: 100-200): ${NC}"
    read range < /dev/tty
    range_start=$(echo $range | cut -d'-' -f1)
    range_end=$(echo $range | cut -d'-' -f2)
    [[ -z "$range_start" ]] && range_start=100
    [[ -z "$range_end" ]] && range_end=200
    
    DHCP_RANGE_START="${DHCP_SUBNET%.*}.${range_start}"
    DHCP_RANGE_END="${DHCP_SUBNET%.*}.${range_end}"
    
    cat > /etc/dhcp/dhcpd.conf << EOF
default-lease-time 600;
max-lease-time 7200;
subnet $DHCP_SUBNET netmask 255.255.255.0 {
    range $DHCP_RANGE_START $DHCP_RANGE_END;
    option routers $DHCP_ROUTER;
    option domain-name-servers 8.8.8.8, 8.8.4.4;
    authoritative;
}
EOF
    
    echo "INTERFACESv4=\"$DHCP_INTERFACE\"" > /etc/default/isc-dhcp-server
    systemctl restart isc-dhcp-server
    systemctl enable isc-dhcp-server -q
    
    log_info "✅ DHCP selesai! $DHCP_SUBNET -> $DHCP_RANGE_START - $DHCP_RANGE_END"
}

install_wordpress() {
    log_step "Install WordPress..."
    
    if ! systemctl is-active --quiet apache2; then
        log_error "Apache2 harus diinstall dulu!"
        return 1
    fi
    
    # Cek sudah terinstall?
    if [[ -d /var/www/html/wordpress ]]; then
        log_info "WordPress sudah terinstall, melewati..."
        return 0
    fi
    
    apt install -y -qq php php-mysql php-curl php-gd php-mbstring php-xml php-zip mariadb-server wget
    
    systemctl start mariadb
    systemctl enable mariadb -q
    
    mysql << EOF
CREATE DATABASE IF NOT EXISTS wordpress;
CREATE USER IF NOT EXISTS 'wpuser'@'localhost' IDENTIFIED BY 'wp123456';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'localhost';
FLUSH PRIVILEGES;
EOF
    
    cd /tmp
    wget -q https://wordpress.org/latest.tar.gz
    tar -xzf latest.tar.gz
    cp -r /tmp/wordpress/* /var/www/html/wordpress/
    
    cp /var/www/html/wordpress/wp-config-sample.php /var/www/html/wordpress/wp-config.php
    sed -i "s/database_name_here/wordpress/" /var/www/html/wordpress/wp-config.php
    sed -i "s/username_here/wpuser/" /var/www/html/wordpress/wp-config.php
    sed -i "s/password_here/wp123456/" /var/www/html/wordpress/wp-config.php
    
    chown -R www-data:www-data /var/www/html/wordpress/
    systemctl restart apache2
    rm -rf /tmp/wordpress*
    
    log_info "✅ WordPress selesai! /wordpress"
}

# ==================== MENU ====================

install_all_basic() {
    system_update
    install_apache
    install_ftp
    install_ssh
    install_wordpress
    echo ""
    log_info "✅ SEMUA BASIC SELESAI!"
}

install_all_complete() {
    system_update
    install_apache
    install_ftp
    install_ssh
    install_dns
    install_dhcp
    install_wordpress
    echo ""
    log_info "✅ SEMUA COMPLETE SELESAI!"
}

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
    printf "${GREEN}Pilih (1-9): ${NC}"
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
        9) echo ""; log_info "Terima kasih!"; exit 0 ;;
        *) echo ""; log_error "Pilihan tidak valid!"; sleep 1 ;;
    esac
    
    echo ""
    printf "${YELLOW}Tekan Enter...${NC}"
    read < /dev/tty
done