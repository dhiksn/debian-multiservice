#!/bin/bash
# ============================================================
# install.sh - Multi-Service Installer for Debian
# Services: Apache2, vsftpd, OpenSSH, BIND9, DHCP, WordPress (optional)
# ============================================================

# ─── Color Definitions ───────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ─── Trap: Reset terminal on exit/interrupt ───────────────────
trap 'tput sgr0; echo ""' EXIT INT TERM

# ─── Logging Helper ──────────────────────────────────────────
log_info()    { echo -e "${GREEN}[INFO]${NC}  $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() { echo -e "\n${CYAN}${BOLD}══════════════════════════════════════${NC}"; echo -e "${CYAN}${BOLD}  $1${NC}"; echo -e "${CYAN}${BOLD}══════════════════════════════════════${NC}\n"; }

# ─── Root Check ──────────────────────────────────────────────
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
    echo -e "${CYAN}${BOLD}  ┌─────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}${BOLD}  │       Multi-Service Installer | Apache2+vsftpd+OpenSSH         │${NC}"
    echo -e "${CYAN}${BOLD}  │              + BIND9 DNS Server + DHCP Server                  │${NC}"
    echo -e "${CYAN}${BOLD}  │                    Target OS: Debian Latest                    │${NC}"
    echo -e "${CYAN}${BOLD}  └─────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ─── Helper Functions ────────────────────────────────────────
get_port_80_listener() {
    ss -tulpn 2>/dev/null | awk '/:80[[:space:]]/ && /LISTEN/ {print; exit}'
}

# Fungsi untuk membaca input dari terminal (bekerja meskipun dipipe)
read_input() {
    local prompt="$1"
    local default="$2"
    local input=""
    
    # Pastikan input dari terminal
    exec < /dev/tty
    
    # Tampilkan prompt
    if [[ -n "$prompt" ]]; then
        echo -n "$prompt" > /dev/tty
    fi
    
    # Baca input
    if ! IFS= read -r input < /dev/tty; then
        echo ""
        return 1
    fi
    
    # Jika input kosong dan ada default, gunakan default
    if [[ -z "$input" ]] && [[ -n "$default" ]]; then
        echo "$default"
    else
        echo "$input"
    fi
    return 0
}

# Fungsi untuk memilih IP Address dari interface yang aktif
select_ip() {
    local prompt_msg="$1"
    local interfaces=()
    local line=""
    local idx=1
    local choice=""
    local selected_ip=""
    
    # Kumpulkan semua interface yang aktif
    while IFS= read -r line; do
        interfaces+=("$line")
    done < <(ip -o -4 addr show up scope global 2>/dev/null | awk '{print $2 "|" $4}')
    
    # Jika tidak ada interface, gunakan hostname -I
    if [[ ${#interfaces[@]} -eq 0 ]]; then
        selected_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
        if [[ -z "$selected_ip" ]]; then
            selected_ip="127.0.0.1"
        fi
        echo "$selected_ip"
        return 0
    fi
    
    # Tampilkan daftar interface
    echo -e "${CYAN}${prompt_msg}${NC}" > /dev/tty
    for line in "${interfaces[@]}"; do
        local iface_name="${line%%|*}"
        local iface_ip="${line##*|}"
        iface_ip="${iface_ip%%/*}"
        echo -e "  ${YELLOW}${idx}.${NC} ${iface_name} -> ${iface_ip}" > /dev/tty
        idx=$((idx + 1))
    done
    
    # Minta user memilih
    while true; do
        # Gunakan read_input langsung dengan prompt yang jelas
        exec < /dev/tty
        echo -n -e "${CYAN}Pilih nomor interface [1-${#interfaces[@]}] (default 1): ${NC}" > /dev/tty
        read -r choice < /dev/tty
        
        # Jika user langsung enter, pilih default 1
        if [[ -z "$choice" ]]; then
            choice="1"
        fi
        
        # Validasi input
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#interfaces[@]} )); then
            local selected_line="${interfaces[$((choice - 1))]}"
            selected_ip="${selected_line##*|}"
            selected_ip="${selected_ip%%/*}"
            echo "$selected_ip"
            return 0
        else
            echo -e "${RED}[ERROR] Pilihan tidak valid! Masukkan angka 1-${#interfaces[@]}.${NC}" > /dev/tty
        fi
    done
}

choose_access_ip() {
    APACHE_ACCESS_IP=$(select_ip "Pilih interface untuk akses Apache2:")
    [[ -n "$APACHE_ACCESS_IP" ]]
}

# Fungsi untuk memilih interface untuk DHCP Server
select_dhcp_interface() {
    DHCP_INTERFACE_NAME=""
    local interfaces=()
    local line=""
    local idx=1
    local choice=""
    
    # Kumpulkan semua interface yang aktif
    while IFS= read -r line; do
        interfaces+=("$line")
    done < <(ip -o -4 addr show up scope global 2>/dev/null | awk '{print $2 "|" $4}')
    
    if [[ ${#interfaces[@]} -eq 0 ]]; then
        DHCP_INTERFACE_NAME="eth0"
        echo "$DHCP_INTERFACE_NAME"
        return 0
    fi
    
    echo -e "${CYAN}Pilih interface untuk DHCP Server:${NC}" > /dev/tty
    for line in "${interfaces[@]}"; do
        local iface_name="${line%%|*}"
        local iface_ip="${line##*|}"
        iface_ip="${iface_ip%%/*}"
        echo -e "  ${YELLOW}${idx}.${NC} ${iface_name} -> ${iface_ip}" > /dev/tty
        idx=$((idx + 1))
    done
    
    while true; do
        exec < /dev/tty
        echo -n -e "${CYAN}Pilih nomor interface [1-${#interfaces[@]}] (default 1): ${NC}" > /dev/tty
        read -r choice < /dev/tty
        
        if [[ -z "$choice" ]]; then
            choice="1"
        fi
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#interfaces[@]} )); then
            local selected_line="${interfaces[$((choice - 1))]}"
            DHCP_INTERFACE_NAME="${selected_line%%|*}"
            echo "$DHCP_INTERFACE_NAME"
            return 0
        else
            echo -e "${RED}[ERROR] Pilihan tidak valid! Masukkan angka 1-${#interfaces[@]}.${NC}" > /dev/tty
        fi
    done
}

# Fungsi untuk mendapatkan network dari IP
get_network_from_ip() {
    local ip="$1"
    echo "$ip" | awk -F. '{print $1"."$2"."$3".0"}'
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

# ─── System Update ───────────────────────────────────────────
system_update() {
    log_section "System Update & Upgrade"
    log_info "Memperbarui daftar paket..."
    apt update -y
    log_info "Mengupgrade paket yang sudah terinstall..."
    apt upgrade -y
    log_info "Membersihkan cache paket..."
    apt autoremove -y
    apt clean
    log_info "System update selesai."
}

# ─── Apache2 Installation ────────────────────────────────────
install_apache() {
    log_section "Instalasi Apache2 Web Server"

    log_info "Menginstall apache2..."
    apt install -y apache2

    log_info "Membuat halaman index.html..."
    cat > /var/www/html/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TechCorp - Solusi Teknologi Terdepan</title>
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
                <div class="service-card">
                    <div class="icon">🌐</div>
                    <h3>Web Development</h3>
                    <p>Pengembangan website dan aplikasi web modern.</p>
                </div>
                <div class="service-card">
                    <div class="icon">🔒</div>
                    <h3>Cybersecurity</h3>
                    <p>Perlindungan menyeluruh terhadap ancaman siber.</p>
                </div>
                <div class="service-card">
                    <div class="icon">☁️</div>
                    <h3>Cloud Solutions</h3>
                    <p>Solusi cloud computing dan infrastruktur IT.</p>
                </div>
            </div>
        </div>
        <div class="section" id="contact">
            <h2>Kontak</h2>
            <div class="contact-info">
                <p>🏢 <span>Perusahaan:</span> TechCorp Indonesia</p>
                <p>📍 <span>Alamat:</span> Jl. Teknologi No. 1, Jakarta Selatan</p>
                <p>📧 <span>Email:</span> info@techcorp.id</p>
                <p>📞 <span>Telepon:</span> +62 21 1234 5678</p>
            </div>
        </div>
    </div>
    <footer>
        <p>&copy; 2025 <span>TechCorp Indonesia</span>. All Rights Reserved.</p>
    </footer>
</body>
</html>
HTMLEOF

    log_info "Mengatur permission file web..."
    chown -R www-data:www-data /var/www/html
    chmod -R 755 /var/www/html

    log_info "Mengatur ServerName Apache2..."
    SERVER_NAME="$(hostname -f 2>/dev/null || hostname)"
    [[ -z "$SERVER_NAME" || "$SERVER_NAME" == "(none)" ]] && SERVER_NAME="localhost"
    
    cat > /etc/apache2/conf-available/servername.conf << APACHECONF
ServerName $SERVER_NAME
APACHECONF
    a2enconf servername >/dev/null 2>&1 || true

    log_info "Memvalidasi konfigurasi Apache2..."
    if ! apache2ctl configtest 2>/dev/null; then
        log_error "Konfigurasi Apache2 tidak valid."
        return 1
    fi

    log_info "Menjalankan dan mengaktifkan service Apache2..."
    systemctl enable apache2
    systemctl restart apache2

    choose_access_ip || return 1

    log_info "Mengkonfigurasi firewall untuk port 80..."
    if command -v ufw &> /dev/null; then
        ufw allow 80/tcp
        log_info "UFW: Port 80 dibuka."
    fi

    log_info "✅ Apache2 berhasil diinstall! Akses: http://${APACHE_ACCESS_IP}"
}

# ─── vsftpd Installation ─────────────────────────────────────
install_ftp() {
    log_section "Instalasi FTP Server (vsftpd)"

    log_info "Menginstall vsftpd..."
    apt install -y vsftpd

    log_info "Membuat backup konfigurasi vsftpd..."
    cp /etc/vsftpd.conf /etc/vsftpd.conf.bak 2>/dev/null || true

    log_info "Mengkonfigurasi vsftpd..."
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
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
userlist_enable=YES
userlist_file=/etc/vsftpd.userlist
userlist_deny=NO
ftpd_banner=Welcome to TechCorp FTP Server
FTPEOF

    log_info "Membuat user FTP: admin..."
    if ! id "admin" &>/dev/null; then
        useradd -m -s /bin/bash admin
        echo "admin:123" | chpasswd
        log_info "User 'admin' berhasil dibuat dengan password: 123"
    fi

    echo "admin" > /etc/vsftpd.userlist

    log_info "Menjalankan dan mengaktifkan service vsftpd..."
    systemctl restart vsftpd
    systemctl enable vsftpd

    if command -v ufw &> /dev/null; then
        ufw allow 20/tcp
        ufw allow 21/tcp
    fi

    log_info "✅ vsftpd berhasil diinstall! User: admin | Password: 123"
}

# ─── OpenSSH Installation ────────────────────────────────────
install_ssh() {
    log_section "Instalasi SSH Server (OpenSSH)"

    log_info "Menginstall openssh-server..."
    apt install -y openssh-server

    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak 2>/dev/null || true

    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

    if ! id "admin" &>/dev/null; then
        useradd -m -s /bin/bash admin
        echo "admin:123" | chpasswd
    fi

    mkdir -p /home/admin/.ssh
    chmod 700 /home/admin/.ssh

    cat > /home/admin/.ssh/authorized_keys << 'KEYEOF'
# Ganti dengan public key Anda untuk keamanan lebih baik
# ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC0ExamplePlaceholderReplaceWithYourActualPublicKey== admin@techcorp
KEYEOF

    chown -R admin:admin /home/admin/.ssh
    chmod 600 /home/admin/.ssh/authorized_keys

    systemctl restart ssh
    systemctl enable ssh

    if command -v ufw &> /dev/null; then
        ufw allow 22/tcp
    fi

    log_info "✅ OpenSSH berhasil dikonfigurasi!"
    log_info "   User: admin | Password: 123"
    log_warn "   Untuk keamanan, segera ganti password dan tambahkan public key!"
}

# ─── BIND9 DNS Installation ──────────────────────────────────
install_dns() {
    log_section "Instalasi DNS Server (BIND9)"

    log_info "Menginstall bind9..."
    apt install -y bind9 bind9utils dnsutils

    DNS_IP=$(select_ip "Pilih IP Address untuk DNS Server")
    [[ -z "$DNS_IP" ]] && DNS_IP=$(hostname -I | awk '{print $1}')
    
    log_info "DNS Server akan menggunakan IP: ${DNS_IP}"

    DOMAIN_NAME=$(read_input "Masukkan nama domain (contoh: techcorp.local): " "techcorp.local")
    [[ -z "$DOMAIN_NAME" ]] && DOMAIN_NAME="techcorp.local"

    INTEGRATE=$(read_input "Integrasi dengan IP Apache? (y/n) [default y]: " "y")
    
    if [[ "$INTEGRATE" == "y" ]] || [[ "$INTEGRATE" == "Y" ]] || [[ -z "$INTEGRATE" ]]; then
        if [[ -z "$APACHE_ACCESS_IP" ]]; then
            WEB_IP=$(select_ip "Pilih IP untuk web server")
        else
            WEB_IP="$APACHE_ACCESS_IP"
        fi
        log_info "DNS akan mengarahkan ${DOMAIN_NAME} ke IP: ${WEB_IP}"
    else
        WEB_IP=$(read_input "Masukkan IP web server: " "$DNS_IP")
        [[ -z "$WEB_IP" ]] && WEB_IP="$DNS_IP"
    fi

    cat > /etc/bind/named.conf.options << BINDOPT
options {
    directory "/var/cache/bind";
    listen-on { ${DNS_IP}; 127.0.0.1; };
    listen-on-v6 { none; };
    allow-query { any; };
    recursion yes;
    forwarders {
        8.8.8.8;
        8.8.4.4;
    };
    dnssec-validation auto;
};
BINDOPT

    cat > /etc/bind/named.conf.local << BINDLOCAL
zone "${DOMAIN_NAME}" {
    type master;
    file "/etc/bind/db.${DOMAIN_NAME}";
};
BINDLOCAL

    cat > "/etc/bind/db.${DOMAIN_NAME}" << FORWARDZONE
;
; BIND data file for ${DOMAIN_NAME}
;
\$TTL    604800
@       IN      SOA     ns1.${DOMAIN_NAME}. admin.${DOMAIN_NAME}. (
                      $(date +%Y%m%d%H) ; Serial
                     604800              ; Refresh
                      86400              ; Retry
                    2419200              ; Expire
                     604800 )            ; Negative Cache TTL
;
@       IN      NS      ns1.${DOMAIN_NAME}.
@       IN      A       ${WEB_IP}
ns1     IN      A       ${DNS_IP}
www     IN      A       ${WEB_IP}
FORWARDZONE

    systemctl restart named
    systemctl enable named

    if command -v ufw &> /dev/null; then
        ufw allow 53/tcp
        ufw allow 53/udp
    fi

    log_info "✅ BIND9 berhasil diinstall!"
    log_info "   Domain: ${DOMAIN_NAME} -> ${WEB_IP}"
    log_info "   DNS Server IP: ${DNS_IP}"
    log_info "   Testing: dig @${DNS_IP} ${DOMAIN_NAME}"
}

# ─── DHCP Server Installation ─────────────────────────────────
install_dhcp() {
    log_section "Instalasi DHCP Server"

    log_info "Menginstall isc-dhcp-server..."
    apt install -y isc-dhcp-server

    DHCP_INTERFACE=$(select_dhcp_interface)
    [[ -z "$DHCP_INTERFACE" ]] && DHCP_INTERFACE="eth0"
    
    INTERFACE_IP=$(ip -o -4 addr show | grep "$DHCP_INTERFACE" | awk '{print $4}' | cut -d/ -f1 | head -1)
    NETWORK_ADDR=$(get_network_from_ip "$INTERFACE_IP")
    
    IFS=. read -r n1 n2 n3 n4 <<< "$NETWORK_ADDR"
    DEFAULT_START="${n1}.${n2}.${n3}.100"
    DEFAULT_END="${n1}.${n2}.${n3}.200"
    
    echo -e "${CYAN}Masukkan range DHCP${NC}"
    DHCP_START=$(read_input "Range mulai (default ${DEFAULT_START}): " "$DEFAULT_START")
    DHCP_END=$(read_input "Range akhir (default ${DEFAULT_END}): " "$DEFAULT_END")
    DHCP_GATEWAY=$(read_input "Gateway (default ${n1}.${n2}.${n3}.1): " "${n1}.${n2}.${n3}.1")
    DHCP_DNS=$(read_input "DNS Server (default ${INTERFACE_IP},8.8.8.8): " "${INTERFACE_IP},8.8.8.8")
    
    [[ -z "$DHCP_START" ]] && DHCP_START="$DEFAULT_START"
    [[ -z "$DHCP_END" ]] && DHCP_END="$DEFAULT_END"
    [[ -z "$DHCP_GATEWAY" ]] && DHCP_GATEWAY="${n1}.${n2}.${n3}.1"
    [[ -z "$DHCP_DNS" ]] && DHCP_DNS="${INTERFACE_IP},8.8.8.8"

    cat > /etc/dhcp/dhcpd.conf << DHCPCONF
option domain-name "techcorp.local";
option domain-name-servers ${DHCP_DNS};
default-lease-time 86400;
max-lease-time 172800;
authoritative;

subnet ${NETWORK_ADDR} netmask 255.255.255.0 {
    range ${DHCP_START} ${DHCP_END};
    option routers ${DHCP_GATEWAY};
    option subnet-mask 255.255.255.0;
    option domain-name-servers ${DHCP_DNS};
}
DHCPCONF

    cat > /etc/default/isc-dhcp-server << DHCPDEFAULT
INTERFACESv4="${DHCP_INTERFACE}"
INTERFACESv6=""
DHCPDEFAULT

    systemctl restart isc-dhcp-server
    systemctl enable isc-dhcp-server

    if command -v ufw &> /dev/null; then
        ufw allow 67/udp
    fi

    log_info "✅ DHCP Server berhasil diinstall!"
    log_info "   Interface: ${DHCP_INTERFACE}"
    log_info "   Range: ${DHCP_START} - ${DHCP_END}"
    log_info "   Gateway: ${DHCP_GATEWAY}"
}

# ─── WordPress Installation ──────────────────────────────────
install_wordpress() {
    log_section "Instalasi WordPress"

    log_info "Menginstall PHP dan dependensi..."
    apt install -y php php-mysql php-curl php-gd php-mbstring php-xml \
                   php-zip libapache2-mod-php wget unzip mariadb-server

    systemctl start mariadb
    systemctl enable mariadb

    mysql -u root << 'SQLEOF'
CREATE DATABASE IF NOT EXISTS wordpress_db;
CREATE USER IF NOT EXISTS 'wp_user'@'localhost' IDENTIFIED BY 'WpTechCorp@2024';
GRANT ALL PRIVILEGES ON wordpress_db.* TO 'wp_user'@'localhost';
FLUSH PRIVILEGES;
SQLEOF

    cd /tmp
    wget -q https://wordpress.org/latest.tar.gz
    tar -xzf latest.tar.gz
    mv wordpress /var/www/html/
    rm -f latest.tar.gz

    cp /var/www/html/wordpress/wp-config-sample.php /var/www/html/wordpress/wp-config.php
    sed -i "s/database_name_here/wordpress_db/" /var/www/html/wordpress/wp-config.php
    sed -i "s/username_here/wp_user/" /var/www/html/wordpress/wp-config.php
    sed -i "s/password_here/WpTechCorp@2024/" /var/www/html/wordpress/wp-config.php

    chown -R www-data:www-data /var/www/html/wordpress
    systemctl restart apache2

    log_info "✅ WordPress berhasil diinstall!"
    log_info "   URL: http://$(hostname -I | awk '{print $1}')/wordpress"
    log_info "   DB Name: wordpress_db | User: wp_user | Pass: WpTechCorp@2024"
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
    
    echo ""
    echo -e "${GREEN}${BOLD}  ┌──────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${GREEN}${BOLD}  │                    RINGKASAN INSTALASI                        │${NC}"
    echo -e "${GREEN}${BOLD}  ├──────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${GREEN}${BOLD}  │${NC}  🌐 Apache2    : http://$(hostname -I | awk '{print $1}')                      ${GREEN}${BOLD}│${NC}"
    echo -e "${GREEN}${BOLD}  │${NC}  📁 FTP        : ftp://$(hostname -I | awk '{print $1}') (admin/123)          ${GREEN}${BOLD}│${NC}"
    echo -e "${GREEN}${BOLD}  │${NC}  🔒 SSH        : ssh admin@$(hostname -I | awk '{print $1}') (pass: 123)      ${GREEN}${BOLD}│${NC}"
    echo -e "${GREEN}${BOLD}  │${NC}  🌐 DNS        : DNS Server aktif di port 53                                 ${GREEN}${BOLD}│${NC}"
    echo -e "${GREEN}${BOLD}  │${NC}  📡 DHCP       : DHCP Server aktif                                           ${GREEN}${BOLD}│${NC}"
    echo -e "${GREEN}${BOLD}  │${NC}  📝 WordPress  : http://$(hostname -I | awk '{print $1}')/wordpress          ${GREEN}${BOLD}│${NC}"
    echo -e "${GREEN}${BOLD}  └──────────────────────────────────────────────────────────────┘${NC}"
}

# ─── Main Program ────────────────────────────────────────────
main() {
    check_root
    show_banner

    while true; do
        show_menu
        
        # Tampilkan prompt pilihan
        echo -n -e "${CYAN}Pilih opsi [1-8]: ${NC}"
        
        # Baca input dari terminal
        exec < /dev/tty
        read -r CHOICE
        
        if [[ -z "$CHOICE" ]]; then
            echo -e "\n${RED}[ERROR] Gagal membaca input.${NC}"
            continue
        fi
        
        case $CHOICE in
            1) install_all ;;
            2) system_update; install_apache ;;
            3) system_update; install_ftp ;;
            4) system_update; install_ssh ;;
            5) system_update; install_dns ;;
            6) system_update; install_dhcp ;;
            7) system_update; install_wordpress ;;
            8) 
                echo -e "\n${CYAN}${BOLD}Terima kasih! Sampai jumpa.${NC}\n"
                exit 0
                ;;
            *)
                echo -e "${RED}[ERROR] Pilihan tidak valid!${NC}"
                ;;
        esac

        echo ""
        echo -n -e "${YELLOW}Tekan Enter untuk kembali ke menu...${NC}"
        exec < /dev/tty
        read -r
        clear
        show_banner
    done
}

# ─── Entry Point ─────────────────────────────────────────────
main "$@"
