#!/bin/bash
# ============================================================
# install.sh - Multi-Service Installer for Debian
# Services: Apache2, vsftpd, OpenSSH, BIND9, DHCP, WordPress
# ============================================================

# ─── Color Definitions ───────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Global Variables ────────────────────────────────────────
DNS_SERVER_IP=""
DOMAIN_NAME=""
RECORDS_FILE="/tmp/dns_records.txt"

# ─── Trap ────────────────────────────────────────────────────
trap 'tput sgr0; echo ""' EXIT INT TERM

# ─── Logging Helper ──────────────────────────────────────────
log_info()    { echo -e "${GREEN}[INFO]${NC}  $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() { echo -e "\n${CYAN}${BOLD}══════════════════════════════════════${NC}"; echo -e "${CYAN}${BOLD}  $1${NC}"; echo -e "${CYAN}${BOLD}══════════════════════════════════════${NC}\n"; }

# ─── Helper Functions ────────────────────────────────────────
select_ip() {
    local prompt_msg="$1"
    local interfaces=()
    local line=""
    local idx=1
    local choice=""
    local selected_if=""
    local selected_ip=""

    while IFS= read -r line; do
        interfaces+=("$line")
    done < <(ip -o -4 addr show up scope global | awk '{print $2 "|" $4}')

    if [[ ${#interfaces[@]} -eq 0 ]]; then
        selected_ip="$(hostname -I | awk '{print $1}')"
        echo "$selected_ip"
        return 0
    fi

    echo -e "${CYAN}${prompt_msg}${NC}" >&2
    for line in "${interfaces[@]}"; do
        echo -e "  ${YELLOW}${idx}.${NC} ${line%%|*} -> ${line##*|}" >&2
        idx=$((idx + 1))
    done

    while true; do
        printf "\033[0;36m%s [1-%d] (default 1): \033[0m" "Pilih interface" "${#interfaces[@]}" >&2
        if ! IFS= read -r choice < /dev/tty; then
            echo "" >&2
            return 1
        fi

        if [[ -z "$choice" ]]; then
            choice=1
        fi

        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#interfaces[@]} )); then
            selected_if="${interfaces[$((choice - 1))]}"
            selected_ip="${selected_if##*|}"
            selected_ip="${selected_ip%%/*}"
            echo "$selected_ip"
            return 0
        fi

        log_error "Pilihan interface tidak valid." >&2
    done
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Script ini harus dijalankan sebagai root. Gunakan: sudo bash install.sh"
        exit 1
    fi
}

# ─── Banner ──────────────────────────────────────────────────
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
    echo -e "${CYAN}${BOLD}  ┌─────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}${BOLD}  │ Multi-Service Installer | Apache2+vsftpd+OpenSSH+DNS+DHCP │${NC}"
    echo -e "${CYAN}${BOLD}  │              Target OS: Debian Latest                      │${NC}"
    echo -e "${CYAN}${BOLD}  └─────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ─── Menu ────────────────────────────────────────────────────
show_menu() {
    echo -e "${BOLD}${YELLOW}  ╔════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${YELLOW}  ║           MENU INSTALASI               ║${NC}"
    echo -e "${BOLD}${YELLOW}  ╠════════════════════════════════════════╣${NC}"
    echo -e "${BOLD}${YELLOW}  ║${NC}  1. Install Semua Service               ${BOLD}${YELLOW}║${NC}"
    echo -e "${BOLD}${YELLOW}  ║${NC}  2. Install Apache2 (Web Server)        ${BOLD}${YELLOW}║${NC}"
    echo -e "${BOLD}${YELLOW}  ║${NC}  3. Install FTP (vsftpd)                ${BOLD}${YELLOW}║${NC}"
    echo -e "${BOLD}${YELLOW}  ║${NC}  4. Install SSH (Secure Server)         ${BOLD}${YELLOW}║${NC}"
    echo -e "${BOLD}${YELLOW}  ║${NC}  5. Install DNS Server (BIND9)          ${BOLD}${YELLOW}║${NC}"
    echo -e "${BOLD}${YELLOW}  ║${NC}  6. Install DHCP Server                 ${BOLD}${YELLOW}║${NC}"
    echo -e "${BOLD}${YELLOW}  ║${NC}  7. Install WordPress                   ${BOLD}${YELLOW}║${NC}"
    echo -e "${BOLD}${YELLOW}  ║${NC}  8. Manajemen DNS Records               ${BOLD}${YELLOW}║${NC}"
    echo -e "${BOLD}${YELLOW}  ║${NC}  9. Konfigurasi DNS Client              ${BOLD}${YELLOW}║${NC}"
    echo -e "${BOLD}${YELLOW}  ║${NC}  10. Exit                               ${BOLD}${YELLOW}║${NC}"
    echo -e "${BOLD}${YELLOW}  ╚════════════════════════════════════════╝${NC}"
    echo ""
}

prompt_menu_choice() {
    while true; do
        printf "\033[0;36mPilih opsi [1-10]: \033[0m"
        if ! IFS= read -r CHOICE < /dev/tty; then
            echo ""
            log_error "Gagal membaca input dari terminal."
            return 1
        fi

        case "$CHOICE" in
            [1-9]|10)
                return 0
                ;;
            *)
                log_error "Pilihan tidak valid. Masukkan angka 1-10."
                ;;
        esac
    done
}

# ─── System Update ───────────────────────────────────────────
system_update() {
    log_section "System Update & Upgrade"
    log_info "Memperbarui daftar paket..."
    apt update -y
    log_info "Mengupgrade paket yang sudah terinstall..."
    apt upgrade -y
    apt autoremove -y
    apt clean
    log_info "System update selesai."
}

# ─── Apache2 Installation (simplified) ───────────────────────
install_apache() {
    log_section "Instalasi Apache2 Web Server"
    apt install -y apache2
    cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head><title>TechCorp</title></head>
<body><h1>Welcome to TechCorp Server</h1></body>
</html>
EOF
    systemctl enable apache2
    systemctl restart apache2
    log_info "✅ Apache2 berhasil diinstall!"
}

# ─── vsftpd Installation (simplified) ────────────────────────
install_ftp() {
    log_section "Instalasi FTP Server"
    apt install -y vsftpd
    systemctl enable vsftpd
    systemctl restart vsftpd
    log_info "✅ vsftpd berhasil diinstall!"
}

# ─── OpenSSH Installation (simplified) ───────────────────────
install_ssh() {
    log_section "Instalasi SSH Server"
    apt install -y openssh-server
    systemctl enable ssh
    systemctl restart ssh
    log_info "✅ OpenSSH berhasil diinstall!"
}

# ─── DNS Server Installation with Custom Records ─────────────
add_dns_record() {
    local zone_file="/etc/bind/db.$DOMAIN_NAME"
    
    echo ""
    echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}              TAMBAH DNS RECORD                          ${NC}"
    echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Tipe Record yang tersedia:${NC}"
    echo "  1. A Record      (Domain -> IP Address)"
    echo "  2. CNAME Record  (Alias -> Domain)"
    echo "  3. MX Record     (Mail Exchange)"
    echo "  4. TXT Record    (Text verification)"
    echo "  5. NS Record     (Name Server)"
    echo "  6. Selesai / Keluar"
    echo ""
    
    while true; do
        printf "\033[0;36mPilih tipe record [1-6]: \033[0m"
        read -r record_type
        
        case $record_type in
            1)
                echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                read -p "Subdomain (contoh: www / @ untuk root): " subdomain
                read -p "IP Address target: " ip_address
                
                if [[ "$subdomain" == "@" ]] || [[ -z "$subdomain" ]]; then
                    echo "@       IN      A       $ip_address" >> $zone_file
                    log_info "Record A: $DOMAIN_NAME -> $ip_address"
                else
                    echo "$subdomain       IN      A       $ip_address" >> $zone_file
                    log_info "Record A: $subdomain.$DOMAIN_NAME -> $ip_address"
                fi
                ;;
            2)
                echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                read -p "Alias (contoh: www): " alias
                read -p "Target domain (contoh: @ atau server.$DOMAIN_NAME): " target
                echo "$alias       IN      CNAME       $target" >> $zone_file
                log_info "Record CNAME: $alias.$DOMAIN_NAME -> $target"
                ;;
            3)
                echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                read -p "Priority (0-65535): " priority
                read -p "Mail server (contoh: mail.$DOMAIN_NAME): " mail_server
                echo "@       IN      MX      $priority      $mail_server" >> $zone_file
                log_info "Record MX: priority $priority -> $mail_server"
                ;;
            4)
                echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                read -p "Subdomain (contoh: @ / _dmarc): " subdomain
                read -p "TXT value: " txt_value
                echo "$subdomain       IN      TXT     \"$txt_value\"" >> $zone_file
                log_info "Record TXT ditambahkan"
                ;;
            5)
                echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                read -p "Name server (contoh: ns1): " ns_name
                read -p "IP Address: " ns_ip
                echo "$ns_name       IN      NS      $ns_ip" >> $zone_file
                log_info "Record NS: $ns_name -> $ns_ip"
                ;;
            6)
                log_info "Selesai menambah record."
                break
                ;;
            *)
                log_error "Pilihan tidak valid!"
                continue
                ;;
        esac
        
        # Update serial number
        local serial=$(grep -oP '\d{10}' $zone_file | head -1)
        local new_serial=$((serial + 1))
        sed -i "s/$serial/$new_serial/" $zone_file
        
        # Reload BIND
        systemctl reload named
        echo ""
        echo -e "${GREEN}✅ Record ditambahkan dan BIND9 direload!${NC}"
        echo ""
        read -p "Tekan Enter untuk lanjut..."
        echo ""
    done
}

install_dns() {
    log_section "Instalasi DNS Server (BIND9)"

    # Pilih IP
    DNS_SERVER_IP=$(select_ip "Pilih interface untuk DNS Server:")
    if [[ -z "$DNS_SERVER_IP" ]]; then
        log_error "Gagal memilih IP address."
        return 1
    fi
    
    # Input domain
    echo -e "\n${CYAN}══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}              KONFIGURASI DOMAIN                           ${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
    echo ""
    read -p "$(echo -e "${YELLOW}Masukkan domain name (contoh: techcorp.local): ${NC}")" DOMAIN_NAME
    if [[ -z "$DOMAIN_NAME" ]]; then
        DOMAIN_NAME="techcorp.local"
        log_info "Menggunakan domain default: $DOMAIN_NAME"
    fi

    log_info "Installing BIND9..."
    apt install -y bind9 bind9utils bind9-doc dnsutils

    # Konfigurasi options
    cat > /etc/bind/named.conf.options << EOF
options {
    directory "/var/cache/bind";
    listen-on port 53 { $DNS_SERVER_IP; 127.0.0.1; };
    listen-on-v6 { none; };
    allow-query { any; };
    allow-transfer { none; };
    recursion yes;
    dnssec-validation auto;
    querylog yes;
    forwarders {
        8.8.8.8;
        8.8.4.4;
    };
};
EOF

    # Forward zone
    local serial=$(date +%Y%m%d%H)
    cat > /etc/bind/db.$DOMAIN_NAME << EOF
;
; BIND data file for $DOMAIN_NAME
;
\$ORIGIN $DOMAIN_NAME.
\$TTL    604800
@       IN      SOA     ns1.$DOMAIN_NAME. admin.$DOMAIN_NAME. (
                  $serial         ; Serial
                  604800          ; Refresh
                  86400           ; Retry
                  2419200         ; Expire
                  604800 )        ; Negative Cache TTL
;
@       IN      NS      ns1.$DOMAIN_NAME.
@       IN      NS      ns2.$DOMAIN_NAME.
@       IN      A       $DNS_SERVER_IP
;
ns1     IN      A       $DNS_SERVER_IP
ns2     IN      A       $DNS_SERVER_IP
EOF

    # Tambahkan default records
    cat >> /etc/bind/db.$DOMAIN_NAME << EOF
;
; Default Records
www     IN      A       $DNS_SERVER_IP
mail    IN      A       $DNS_SERVER_IP
ftp     IN      A       $DNS_SERVER_IP
admin   IN      A       $DNS_SERVER_IP
;
EOF

    # Reverse zone
    local reverse_net=$(echo "$DNS_SERVER_IP" | awk -F. '{print $3"."$2"."$1}')
    local last_octet=$(echo "$DNS_SERVER_IP" | awk -F. '{print $4}')
    
    cat > /etc/bind/db.$reverse_net << EOF
;
; BIND reverse data file
;
\$TTL    604800
@       IN      SOA     ns1.$DOMAIN_NAME. admin.$DOMAIN_NAME. (
                  $serial         ; Serial
                  604800          ; Refresh
                  86400           ; Retry
                  2419200         ; Expire
                  604800 )        ; Negative Cache TTL
;
@       IN      NS      ns1.$DOMAIN_NAME.
@       IN      NS      ns2.$DOMAIN_NAME.
;
$last_octet  IN      PTR     ns1.$DOMAIN_NAME.
$last_octet  IN      PTR     $DOMAIN_NAME.
$last_octet  IN      PTR     www.$DOMAIN_NAME.
EOF

    # Add zones to named.conf.local
    cat >> /etc/bind/named.conf.local << EOF

zone "$DOMAIN_NAME" {
    type master;
    file "/etc/bind/db.$DOMAIN_NAME";
    allow-query { any; };
};

zone "$reverse_net.in-addr.arpa" {
    type master;
    file "/etc/bind/db.$reverse_net";
    allow-query { any; };
};
EOF

    # Validate
    named-checkconf
    named-checkzone $DOMAIN_NAME /etc/bind/db.$DOMAIN_NAME
    
    # Start service
    systemctl restart named
    systemctl enable named

    # Firewall
    if command -v ufw &> /dev/null; then
        ufw allow 53/tcp
        ufw allow 53/udp
    fi

    log_info "✅ DNS Server berhasil diinstall!"
    echo ""
    echo -e "${GREEN}${BOLD}  ┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${GREEN}${BOLD}  │           DNS CONFIGURATION                    │${NC}"
    echo -e "${GREEN}${BOLD}  ├─────────────────────────────────────────────────┤${NC}"
    echo -e "${GREEN}${BOLD}  │${NC}  Domain        : $DOMAIN_NAME                    ${GREEN}${BOLD}│${NC}"
    echo -e "${GREEN}${BOLD}  │${NC}  DNS Server IP : $DNS_SERVER_IP                   ${GREEN}${BOLD}│${NC}"
    echo -e "${GREEN}${BOLD}  │${NC}  Web           : http://$DNS_SERVER_IP           ${GREEN}${BOLD}│${NC}"
    echo -e "${GREEN}${BOLD}  │${NC}  Test command  : dig @$DNS_SERVER_IP $DOMAIN_NAME ${GREEN}${BOLD}│${NC}"
    echo -e "${GREEN}${BOLD}  └─────────────────────────────────────────────────┘${NC}"
    echo ""
    
    # Tanya ingin tambah record
    echo -e "${YELLOW}Apakah Anda ingin menambahkan DNS record sekarang?${NC}"
    read -p "(y/n): " add_now
    if [[ "$add_now" == "y" ]] || [[ "$add_now" == "Y" ]]; then
        add_dns_record
    fi
}

# ─── DNS Client Configuration ────────────────────────────────
configure_dns_client() {
    log_section "Konfigurasi DNS Client"
    
    # Get DNS server IP if not set
    if [[ -z "$DNS_SERVER_IP" ]]; then
        DNS_SERVER_IP=$(select_ip "Pilih IP DNS Server yang akan digunakan:")
    fi
    
    if [[ -z "$DNS_SERVER_IP" ]]; then
        log_error "Gagal mendapatkan DNS server IP"
        return 1
    fi
    
    # Get domain name if not set
    if [[ -z "$DOMAIN_NAME" ]]; then
        read -p "$(echo -e "${YELLOW}Masukkan domain name (contoh: techcorp.local): ${NC}")" DOMAIN_NAME
    fi
    
    echo ""
    log_info "Mengkonfigurasi DNS client untuk menggunakan DNS server: $DNS_SERVER_IP"
    
    # Method 1: Edit /etc/resolv.conf (temporary)
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Metode 1: Konfigurasi sementara (hingga reboot)${NC}"
    echo ""
    read -p "Konfigurasi /etc/resolv.conf sekarang? (y/n): " config_now
    if [[ "$config_now" == "y" ]] || [[ "$config_now" == "Y" ]]; then
        # Backup existing resolv.conf
        cp /etc/resolv.conf /etc/resolv.conf.bak
        
        cat > /etc/resolv.conf << EOF
# DNS Configuration by TechCorp Installer
nameserver $DNS_SERVER_IP
search $DOMAIN_NAME
options timeout:2 attempts:3 rotate
EOF
        log_info "/etc/resolv.conf telah dikonfigurasi"
        log_warn "Konfigurasi ini bersifat sementara dan bisa berubah setelah reboot atau network service restart"
    fi
    
    # Method 2: Configure NetworkManager (if installed)
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Metode 2: Konfigurasi NetworkManager (permanen)${NC}"
    echo ""
    
    if command -v nmcli &> /dev/null; then
        read -p "Konfigurasi NetworkManager? (y/n): " config_nm
        if [[ "$config_nm" == "y" ]] || [[ "$config_nm" == "Y" ]]; then
            # Get active connection
            local conn=$(nmcli -t -f NAME,DEVICE con show --active | head -1 | cut -d: -f1)
            if [[ -n "$conn" ]]; then
                nmcli con mod "$conn" ipv4.dns "$DNS_SERVER_IP"
                nmcli con mod "$conn" ipv4.dns-search "$DOMAIN_NAME"
                nmcli con mod "$conn" ipv4.ignore-auto-dns yes
                nmcli con down "$conn" && nmcli con up "$conn"
                log_info "NetworkManager dikonfigurasi untuk connection: $conn"
            else
                log_warn "Tidak ada koneksi aktif yang ditemukan"
            fi
        fi
    else
        log_warn "NetworkManager tidak terinstall, lewati konfigurasi NetworkManager"
    fi
    
    # Method 3: Configure systemd-resolved (if available)
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Metode 3: Konfigurasi systemd-resolved (permanen)${NC}"
    echo ""
    
    if command -v resolvectl &> /dev/null; then
        read -p "Konfigurasi systemd-resolved? (y/n): " config_resolved
        if [[ "$config_resolved" == "y" ]] || [[ "$config_resolved" == "Y" ]]; then
            resolvectl dns set $DNS_SERVER_IP
            resolvectl domain set $DOMAIN_NAME
            log_info "systemd-resolved dikonfigurasi"
        fi
    else
        log_warn "systemd-resolved tidak terinstall"
    fi
    
    # Test DNS
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Testing DNS Resolution${NC}"
    echo ""
    
    log_info "Testing nslookup $DOMAIN_NAME..."
    if command -v nslookup &> /dev/null; then
        if nslookup $DOMAIN_NAME $DNS_SERVER_IP > /dev/null 2>&1; then
            log_info "✅ DNS resolution berhasil"
            nslookup $DOMAIN_NAME $DNS_SERVER_IP
        else
            log_error "❌ DNS resolution gagal"
        fi
    fi
    
    echo ""
    log_info "✅ Konfigurasi DNS client selesai"
    echo ""
    echo -e "${GREEN}Sekarang Anda bisa mengakses:${NC}"
    echo -e "  http://$DOMAIN_NAME"
    echo -e "  http://www.$DOMAIN_NAME"
    echo ""
    echo -e "${YELLOW}Catatan:${NC}"
    echo -e "  1. Pastikan browser Anda tidak menggunakan DNS over HTTPS (DoH)"
    echo -e "  2. Flush DNS cache browser:"
    echo -e "     - Chrome: chrome://net-internals/#dns"
    echo -e "     - Firefox: about:networking#dns"
    echo -e "  3. Flush sistem DNS: systemd-resolve --flush-caches (jika ada)"
}

# ─── DHCP Server Installation ────────────────────────────────
install_dhcp() {
    log_section "Instalasi DHCP Server"
    
    local DHCP_IP=$(select_ip "Pilih interface untuk DHCP Server:")
    local INTERFACE_NAME=$(ip -o -4 addr show | grep "$DHCP_IP" | awk '{print $2}')
    
    apt install -y isc-dhcp-server
    
    cat > /etc/default/isc-dhcp-server << EOF
INTERFACESv4="$INTERFACE_NAME"
INTERFACESv6=""
EOF

    local NETWORK=$(echo "$DHCP_IP" | awk -F. '{print $1"."$2"."$3".0"}')
    cat > /etc/dhcp/dhcpd.conf << EOF
option domain-name "techcorp.local";
option domain-name-servers $DHCP_IP, 8.8.8.8;
default-lease-time 86400;
max-lease-time 172800;
authoritative;

subnet $NETWORK netmask 255.255.255.0 {
    range ${NETWORK%.0}.100 ${NETWORK%.0}.200;
    option routers $DHCP_IP;
    option domain-name-servers $DHCP_IP, 8.8.8.8;
}
EOF

    systemctl restart isc-dhcp-server
    systemctl enable isc-dhcp-server
    
    log_info "✅ DHCP Server berhasil diinstall!"
}

# ─── WordPress Installation ──────────────────────────────────
install_wordpress() {
    log_section "Instalasi WordPress"
    apt install -y php php-mysql mariadb-server wget unzip
    systemctl start mariadb
    systemctl enable mariadb
    
    mysql -u root << EOF
CREATE DATABASE IF NOT EXISTS wordpress_db;
CREATE USER IF NOT EXISTS 'wp_user'@'localhost' IDENTIFIED BY 'WpTechCorp@2024';
GRANT ALL PRIVILEGES ON wordpress_db.* TO 'wp_user'@'localhost';
FLUSH PRIVILEGES;
EOF

    cd /tmp
    wget -q https://wordpress.org/latest.tar.gz
    tar -xzf latest.tar.gz
    mv wordpress /var/www/html/
    chown -R www-data:www-data /var/www/html/wordpress
    
    log_info "✅ WordPress berhasil diinstall!"
}

# ─── Install All Services ────────────────────────────────────
install_all() {
    log_section "Instalasi Semua Service"
    system_update
    install_apache
    install_ftp
    install_ssh
    install_dns
    install_dhcp
    install_wordpress
    configure_dns_client
    
    log_section "Instalasi Selesai"
    echo -e "${GREEN}✅ Semua service berhasil diinstall!${NC}"
    echo -e "${GREEN}🌐 Akses website: http://$DOMAIN_NAME${NC}"
    echo -e "${GREEN}📝 WordPress: http://$DOMAIN_NAME/wordpress${NC}"
}

# ─── Main Program ────────────────────────────────────────────
main() {
    check_root
    show_banner

    while true; do
        show_menu
        prompt_menu_choice || exit 1
        case $CHOICE in
            1) install_all ;;
            2) system_update; install_apache ;;
            3) system_update; install_ftp ;;
            4) system_update; install_ssh ;;
            5) system_update; install_dns ;;
            6) system_update; install_dhcp ;;
            7) system_update; install_wordpress ;;
            8) add_dns_record ;;
            9) configure_dns_client ;;
            10) 
                echo -e "\n${CYAN}${BOLD}Terima kasih telah menggunakan TechCorp Installer. Sampai jumpa!${NC}\n"
                exit 0
                ;;
        esac
        
        echo ""
        read -p "$(echo -e "${YELLOW}Tekan Enter untuk kembali ke menu...${NC}")" < /dev/tty
        clear
        show_banner
    done
}

# ─── Entry Point ─────────────────────────────────────────────
main "$@"