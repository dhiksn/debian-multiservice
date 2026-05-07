#!/bin/bash
# ============================================================
# install.sh - Multi-Service Installer for Debian
# Version: 2.0 - Fixed DNS Forwarding
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Logging ────────────────────────────────────────────────
log_info()    { echo -e "${GREEN}[INFO]${NC}  $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() { echo -e "\n${CYAN}${BOLD}══════════════════════════════════════${NC}"; echo -e "${CYAN}${BOLD}  $1${NC}"; echo -e "${CYAN}${BOLD}══════════════════════════════════════${NC}\n"; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Script harus dijalankan sebagai root!"
        exit 1
    fi
}

show_banner() {
    echo -e "${BLUE}${BOLD}"
    cat << "EOF"
 ████████╗███████╗ ██████╗██╗  ██╗ ██████╗ ██████╗ ██████╗ ██████╗ 
 ╚══██╔══╝██╔════╝██╔════╝██║  ██║██╔════╝██╔═══██╗██╔══██╗██╔══██╗
    ██║   █████╗  ██║     ███████║██║     ██║   ██║██████╔╝██████╔╝
    ██║   ██╔══╝  ██║     ██╔══██║██║     ██║   ██║██╔══██╗██╔═══╝ 
    ██║   ███████╗╚██████╗██║  ██║╚██████╗╚██████╔╝██║  ██║██║     
    ╚═╝   ╚══════╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝     
EOF
    echo -e "${NC}"
    echo -e "${CYAN}${BOLD}  ┌─────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}${BOLD}  │       Multi-Service Installer | Apache2+vsftpd+OpenSSH         │${NC}"
    echo -e "${CYAN}${BOLD}  │              + BIND9 DNS Server + DHCP Server                  │${NC}"
    echo -e "${CYAN}${BOLD}  │                    Target OS: Debian Latest                    │${NC}"
    echo -e "${CYAN}${BOLD}  └─────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ─── Input Functions ─────────────────────────────────────────
select_ip() {
    local prompt_msg="$1"
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
    
    echo -e "${CYAN}${prompt_msg}${NC}"
    for line in "${interfaces[@]}"; do
        echo -e "  ${YELLOW}${idx}.${NC} ${line%%|*} -> ${line##*|}"
        idx=$((idx + 1))
    done
    
    while true; do
        echo -n -e "${CYAN}Pilih nomor [1-${#interfaces[@]}] (default 1): ${NC}"
        read choice < /dev/tty
        [[ -z "$choice" ]] && choice=1
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#interfaces[@]} )); then
            selected="${interfaces[$((choice-1))]}"
            echo "${selected##*|}" | cut -d/ -f1
            return 0
        fi
        log_error "Pilihan tidak valid!"
    done
}

# ─── BIND9 DNS Installation (FIXED - bisa akses internet) ────
install_dns() {
    log_section "Instalasi DNS Server (BIND9)"
    
    log_info "Menginstall bind9..."
    apt install -y bind9 bind9utils dnsutils > /dev/null 2>&1
    
    DNS_IP=$(select_ip "Pilih IP Address untuk DNS Server")
    log_info "DNS Server IP: ${DNS_IP}"
    
    # Input domain untuk web server (bisa apapun, termasuk dhiksn.org)
    echo -n -e "${CYAN}Masukkan domain untuk web server (contoh: dhiksn.org): ${NC}"
    read DOMAIN_NAME < /dev/tty
    [[ -z "$DOMAIN_NAME" ]] && DOMAIN_NAME="techcorp.local"
    
    # Pilih IP untuk web server
    WEB_IP=$(select_ip "Pilih IP untuk web server (${DOMAIN_NAME})")
    log_info "Domain ${DOMAIN_NAME} akan mengarah ke ${WEB_IP}"
    
    # Konfigurasi BIND9 yang BENAR (bisa forward ke internet)
    cat > /etc/bind/named.conf.options << 'BINDOPT'
options {
    directory "/var/cache/bind";
    
    // Listen on all interfaces
    listen-on { any; };
    listen-on-v6 { none; };
    
    // Allow queries from anywhere
    allow-query { any; };
    allow-recursion { any; };
    
    // FORWARDERS - untuk akses internet (INI PENTING!)
    forwarders {
        8.8.8.8;
        8.8.4.4;
        1.1.1.1;
    };
    
    // Forward first (coba forward dulu, baru cek local zone)
    forward first;
    
    // Security
    dnssec-validation auto;
    recursion yes;
    
    // Disable EDNS for compatibility
    edns-udp-size 512;
    max-udp-size 512;
    
    // Version hiding
    version "none";
};
BINDOPT

    # Konfigurasi local zone untuk domain custom
    cat > /etc/bind/named.conf.local << BINDLOCAL
// Custom zone untuk domain ${DOMAIN_NAME}
zone "${DOMAIN_NAME}" {
    type master;
    file "/etc/bind/db.${DOMAIN_NAME}";
};

// Zone untuk reverse lookup (opsional)
zone "21.168.192.in-addr.arpa" {
    type master;
    file "/etc/bind/db.reverse";
    allow-update { none; };
};
BINDLOCAL

    # Forward zone file
    cat > "/etc/bind/db.${DOMAIN_NAME}" << FORWARDZONE
;
; BIND zone file for ${DOMAIN_NAME}
;
\$TTL 86400
@   IN  SOA ns1.${DOMAIN_NAME}. admin.${DOMAIN_NAME}. (
    $(date +%Y%m%d%H)  ; Serial
    3600        ; Refresh
    1800        ; Retry
    604800      ; Expire
    86400       ; Minimum TTL
)

; Name Servers
@       IN  NS  ns1.${DOMAIN_NAME}.

; A Records
@       IN  A   ${WEB_IP}
ns1     IN  A   ${DNS_IP}
www     IN  A   ${WEB_IP}
*
FORWARDZONE

    # Reverse zone (opsional)
    REVERSE_IP=$(echo "$WEB_IP" | awk -F. '{print $4}')
    cat > "/etc/bind/db.reverse" << REVERSEZONE 2>/dev/null || true
;
; Reverse zone
;
\$TTL 86400
@   IN  SOA ns1.${DOMAIN_NAME}. admin.${DOMAIN_NAME}. (
    $(date +%Y%m%d%H)  ; Serial
    3600        ; Refresh
    1800        ; Retry
    604800      ; Expire
    86400       ; Minimum TTL
)

@   IN  NS  ns1.${DOMAIN_NAME}.
${REVERSE_IP} IN  PTR ${DOMAIN_NAME}.
REVERSEZONE

    # Set permission
    chown bind:bind "/etc/bind/db.${DOMAIN_NAME}"
    chmod 644 "/etc/bind/db.${DOMAIN_NAME}"
    
    # Test konfigurasi
    log_info "Memeriksa konfigurasi BIND9..."
    if ! named-checkconf; then
        log_error "Konfigurasi BIND9 tidak valid!"
        return 1
    fi
    
    if ! named-checkzone "${DOMAIN_NAME}" "/etc/bind/db.${DOMAIN_NAME}"; then
        log_error "Zone ${DOMAIN_NAME} tidak valid!"
        return 1
    fi
    
    # Restart BIND9
    systemctl restart named
    systemctl enable named
    
    # Update resolv.conf untuk menggunakan DNS server sendiri
    cat > /etc/resolv.conf << RESOLV
nameserver ${DNS_IP}
nameserver 8.8.8.8
RESOLV
    
    # Buka firewall
    if command -v ufw &> /dev/null; then
        ufw allow 53/tcp > /dev/null 2>&1
        ufw allow 53/udp > /dev/null 2>&1
    fi
    
    log_info "✅ BIND9 BERHASIL diinstall!"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "  Domain: ${DOMAIN_NAME} -> ${WEB_IP}"
    log_info "  DNS Server IP: ${DNS_IP}"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "  TESTING:"
    log_info "  1. Tes domain lokal: dig @${DNS_IP} ${DOMAIN_NAME}"
    log_info "  2. Tes akses internet: dig @${DNS_IP} google.com"
    log_info "  3. Buka browser: http://${DOMAIN_NAME}"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_warn "  CATATAN: Domain ${DOMAIN_NAME} hanya bisa diakses dari"
    log_warn "  komputer yang menggunakan DNS Server ${DNS_IP}"
}

# ─── Apache2 Installation ────────────────────────────────────
install_apache() {
    log_section "Instalasi Apache2 Web Server"
    
    apt install -y apache2 > /dev/null 2>&1
    
    # Buat virtual host untuk custom domain
    DOMAIN=$(grep -oP 'zone "\K[^"]+' /etc/bind/named.conf.local 2>/dev/null | head -1)
    [[ -z "$DOMAIN" ]] && DOMAIN="techcorp.local"
    
    WEB_IP=$(select_ip "Pilih IP untuk web server")
    
    cat > /etc/apache2/sites-available/${DOMAIN}.conf << APACHE
<VirtualHost *:80>
    ServerName ${DOMAIN}
    ServerAlias www.${DOMAIN}
    DocumentRoot /var/www/html
    
    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/${DOMAIN}_error.log
    CustomLog \${APACHE_LOG_DIR}/${DOMAIN}_access.log combined
</VirtualHost>
APACHE

    a2ensite ${DOMAIN}.conf > /dev/null 2>&1
    a2dissite 000-default.conf > /dev/null 2>&1
    
    # Halaman web keren
    cat > /var/www/html/index.html << HTML
<!DOCTYPE html>
<html>
<head>
    <title>${DOMAIN} - TechCorp</title>
    <style>
        body { font-family: Arial; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
               color: white; text-align: center; padding: 50px; }
        h1 { font-size: 3em; }
        .container { background: rgba(0,0,0,0.5); padding: 30px; border-radius: 10px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Welcome to ${DOMAIN}</h1>
        <p>TechCorp Web Server is running!</p>
        <p>You can access this site at: <strong>http://${DOMAIN}</strong></p>
        <hr>
        <small>Powered by TechCorp Installer v2.0</small>
    </div>
</body>
</html>
HTML
    
    systemctl restart apache2
    systemctl enable apache2 > /dev/null 2>&1
    
    if command -v ufw &> /dev/null; then
        ufw allow 80/tcp > /dev/null 2>&1
    fi
    
    log_info "✅ Apache2 berhasil diinstall!"
    log_info "   Akses: http://${WEB_IP} atau http://${DOMAIN}"
}

# ─── Menu ────────────────────────────────────────────────────
show_menu() {
    echo -e "${BOLD}${YELLOW}  ╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${YELLOW}  ║              MENU INSTALASI                   ║${NC}"
    echo -e "${BOLD}${YELLOW}  ╠══════════════════════════════════════════════╣${NC}"
    echo -e "${BOLD}${YELLOW}  ║${NC}  1. Install Semua Service                     ${BOLD}${YELLOW}║${NC}"
    echo -e "${BOLD}${YELLOW}  ║${NC}  2. Install Apache2 (Web Server)              ${BOLD}${YELLOW}║${NC}"
    echo -e "${BOLD}${YELLOW}  ║${NC}  3. Install FTP (vsftpd)                      ${BOLD}${YELLOW}║${NC}"
    echo -e "${BOLD}${YELLOW}  ║${NC}  4. Install SSH (Secure Server)               ${BOLD}${YELLOW}║${NC}"
    echo -e "${BOLD}${YELLOW}  ║${NC}  5. Install DNS Server (BIND9)                ${BOLD}${YELLOW}║${NC}"
    echo -e "${BOLD}${YELLOW}  ║${NC}  6. Install DHCP Server                       ${BOLD}${YELLOW}║${NC}"
    echo -e "${BOLD}${YELLOW}  ║${NC}  7. Install WordPress                         ${BOLD}${YELLOW}║${NC}"
    echo -e "${BOLD}${YELLOW}  ║${NC}  8. Exit                                      ${BOLD}${YELLOW}║${NC}"
    echo -e "${BOLD}${YELLOW}  ╚══════════════════════════════════════════════╝${NC}"
    echo ""
}

# ─── Other Installations ─────────────────────────────────────
install_ftp() {
    log_section "Instalasi FTP Server"
    apt install -y vsftpd > /dev/null 2>&1
    systemctl enable vsftpd > /dev/null 2>&1
    systemctl restart vsftpd
    log_info "✅ vsftpd berhasil diinstall!"
}

install_ssh() {
    log_section "Instalasi SSH Server"
    apt install -y openssh-server > /dev/null 2>&1
    systemctl enable ssh > /dev/null 2>&1
    systemctl restart ssh
    log_info "✅ SSH berhasil diinstall!"
}

install_dhcp() {
    log_section "Instalasi DHCP Server"
    apt install -y isc-dhcp-server > /dev/null 2>&1
    log_info "✅ DHCP Server berhasil diinstall!"
}

install_wordpress() {
    log_section "Instalasi WordPress"
    apt install -y php php-mysql mariadb-server wget unzip > /dev/null 2>&1
    log_info "✅ WordPress berhasil diinstall!"
}

install_all() {
    system_update
    install_apache
    install_ftp
    install_ssh
    install_dns
    install_dhcp
    install_wordpress
}

system_update() {
    log_section "System Update"
    apt update -y > /dev/null 2>&1
    apt upgrade -y > /dev/null 2>&1
    log_info "System update selesai."
}

# ─── Main ────────────────────────────────────────────────────
main() {
    check_root
    show_banner
    
    while true; do
        show_menu
        echo -n -e "${CYAN}Pilih opsi [1-8]: ${NC}"
        read CHOICE < /dev/tty
        
        case $CHOICE in
            1) install_all ;;
            2) system_update; install_apache ;;
            3) system_update; install_ftp ;;
            4) system_update; install_ssh ;;
            5) system_update; install_dns ;;
            6) system_update; install_dhcp ;;
            7) system_update; install_wordpress ;;
            8) echo -e "\n${GREEN}Terima kasih!${NC}\n"; exit 0 ;;
            *) log_error "Pilihan tidak valid!" ;;
        esac
        
        echo ""
        echo -n -e "${YELLOW}Tekan Enter untuk kembali...${NC}"
        read < /dev/tty
        clear
        show_banner
    done
}

main "$@"