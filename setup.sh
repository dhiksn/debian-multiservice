#!/bin/bash

# =====================================================
# Script: Multi-Service Installer for Debian
# Author: TechCorp
# Description: Install and configure Apache2, vsftpd, OpenSSH, BIND9 and WordPress
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

# ─── Trap: Reset terminal on exit/interrupt ───────────────────
trap 'tput sgr0; echo ""' EXIT INT TERM

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

get_port_80_listener() {
    ss -tulpn 2>/dev/null | awk '/:80[[:space:]]/ && /LISTEN/ {print; exit}'
}

# Fungsi untuk memilih IP Address dari interface yang aktif
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

choose_access_ip() {
    APACHE_ACCESS_IP=$(select_ip "Pilih interface untuk akses Apache2:")
    [[ -n "$APACHE_ACCESS_IP" ]]
}

# Fungsi untuk menampilkan banner
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
    echo -e "${CYAN}${BOLD}====================================================================${NC}"
    echo -e "${YELLOW}${BOLD}           Multi-Service Installer | Apache2 + vsftpd + OpenSSH + BIND9${NC}"
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
    apt install apache2 -y

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
            <h1>TechCorp</h1>
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
                    <h3>Web Development</h3>
                    <p>Membangun website modern, responsif, dan scalable dengan teknologi terbaru.</p>
                </div>
                <div class="service-card">
                    <h3>Cybersecurity</h3>
                    <p>Perlindungan sistem dan data dari ancaman siber dengan solusi keamanan terbaik.</p>
                </div>
                <div class="service-card">
                    <h3>Network Solutions</h3>
                    <p>Infrastruktur jaringan yang handal dan aman untuk mendukung operasional bisnis.</p>
                </div>
            </div>
            
            <div class="contact">
                <h3>Hubungi Kami</h3>
                <p>Email: info@techcorp.com</p>
                <p>Telepon: (021) 1234-5678</p>
                <p>Alamat: Jl. Teknologi No. 123, Jakarta Selatan</p>
            </div>
        </div>
        <footer>
            <p>&copy; 2024 TechCorp. All rights reserved. | Powered by Apache2 on Debian</p>
        </footer>
    </div>
</body>
</html>
HTMLEOF
    
    chown -R www-data:www-data /var/www/html/
    chmod -R 755 /var/www/html/

    log_info "Mengatur ServerName Apache2..."
    SERVER_NAME="$(hostname -f 2>/dev/null || hostname)"
    if [[ -z "$SERVER_NAME" || "$SERVER_NAME" == "(none)" ]]; then
        SERVER_NAME="localhost"
    fi
    cat > /etc/apache2/conf-available/servername.conf << APACHECONF
ServerName $SERVER_NAME
APACHECONF
    a2enconf servername >/dev/null 2>&1 || true

    log_info "Memvalidasi konfigurasi Apache2..."
    if ! apache2ctl configtest; then
        log_error "Konfigurasi Apache2 tidak valid. Periksa output configtest di atas."
        return 1
    fi

    log_info "Menjalankan dan mengaktifkan service Apache2..."
    if ! systemctl enable apache2; then
        log_error "Gagal mengaktifkan service Apache2."
        return 1
    fi
    PORT_80_LISTENER="$(get_port_80_listener)"
    if [[ -n "$PORT_80_LISTENER" && "$PORT_80_LISTENER" != *"apache2"* ]]; then
        log_error "Port 80 sudah dipakai proses lain: $PORT_80_LISTENER"
        if [[ "$PORT_80_LISTENER" == *"docker-proxy"* ]]; then
            log_warning "Terdeteksi Docker memakai port 80. Stop container yang publish port 80 atau pindahkan Apache ke port lain."
        fi
        return 1
    fi
    if ! systemctl restart apache2; then
        log_error "Apache2 gagal dijalankan. Coba cek: systemctl status apache2 --no-pager && journalctl -xeu apache2.service"
        systemctl status apache2 --no-pager || true
        return 1
    fi

    choose_access_ip || return 1

    log_info "Status Apache2:"
    systemctl status apache2 --no-pager | head -5
    log_info "Apache2 berhasil diinstall dan berjalan di port 80"
    log_info "Apache2 dapat diakses di: http://${APACHE_ACCESS_IP}"
}

# Fungsi untuk install vsftpd
install_ftp() {
    log_step "Menginstall vsftpd FTP Server..."
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
    
    log_info "Membuat user admin untuk FTP..."
    useradd -m -s /bin/bash admin
    echo "admin:123" | chpasswd
    
    chmod 755 /home/admin
    
    systemctl restart vsftpd
    systemctl enable vsftpd
    
    log_info "vsftpd berhasil dikonfigurasi"
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
    
    log_info "Membuat contoh SSH key pair..."
    ssh-keygen -t rsa -b 4096 -f /home/admin/.ssh/id_rsa -N "" -C "admin@techcorp"
    
    cp /home/admin/.ssh/id_rsa.pub /home/admin/.ssh/authorized_keys
    chmod 600 /home/admin/.ssh/authorized_keys
    
    chown -R admin:admin /home/admin/.ssh
    
    systemctl restart sshd
    systemctl enable sshd
    
    log_info "SSH Server berhasil dikonfigurasi dengan key-based authentication"
    log_warning "Password authentication telah dinonaktifkan"
    log_info "Private key disimpan di: /home/admin/.ssh/id_rsa"
}

# Fungsi untuk install DNS Server (BIND9)
install_dns() {
    log_step "Menginstall BIND9 DNS Server..."
    apt install bind9 bind9utils bind9-doc -y

    echo -ne "${CYAN}Masukkan nama domain custom (default: techcorp.com): ${NC}"
    read -r DNS_DOMAIN < /dev/tty
    if [[ -z "$DNS_DOMAIN" ]]; then
        DNS_DOMAIN="techcorp.com"
    fi

    DNS_IP=$(select_ip "Pilih IP Address untuk DNS Server:")
    if [[ -z "$DNS_IP" ]]; then
        log_error "Gagal mendapatkan IP Address untuk DNS."
        return 1
    fi

    log_info "Konfigurasi DNS untuk domain $DNS_DOMAIN dengan IP $DNS_IP"

    # Ambil 3 oktet pertama untuk reverse zone
    IFS='.' read -r o1 o2 o3 o4 <<< "$DNS_IP"
    REVERSE_ZONE="${o3}.${o2}.${o1}.in-addr.arpa"
    
    # Configure named.conf.options
    cat > /etc/bind/named.conf.options << EOF
options {
    directory "/var/cache/bind";
    recursion yes;
    allow-query { any; };
    forwarders {
        8.8.8.8;
        8.8.4.4;
    };
    dnssec-validation auto;
    listen-on-v6 { any; };
};
EOF

    # Configure named.conf.local
    cat > /etc/bind/named.conf.local << EOF
zone "$DNS_DOMAIN" {
    type master;
    file "/etc/bind/db.$DNS_DOMAIN";
};

zone "$REVERSE_ZONE" {
    type master;
    file "/etc/bind/db.reverse";
};
EOF

    # Create Forward Zone File
    cat > /etc/bind/db.$DNS_DOMAIN << EOF
;
; BIND data file for $DNS_DOMAIN
;
\$TTL    604800
@       IN      SOA     ns1.$DNS_DOMAIN. admin.$DNS_DOMAIN. (
                              3         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      ns1.$DNS_DOMAIN.
@       IN      A       $DNS_IP
ns1     IN      A       $DNS_IP
www     IN      A       $DNS_IP
EOF

    # Create Reverse Zone File
    cat > /etc/bind/db.reverse << EOF
;
; BIND reverse data file for $REVERSE_ZONE
;
\$TTL    604800
@       IN      SOA     ns1.$DNS_DOMAIN. admin.$DNS_DOMAIN. (
                              3         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      ns1.$DNS_DOMAIN.
$o4      IN      PTR     ns1.$DNS_DOMAIN.
$o4      IN      PTR     www.$DNS_DOMAIN.
EOF

    log_info "Memeriksa konfigurasi BIND9..."
    named-checkconf
    named-checkzone $DNS_DOMAIN /etc/bind/db.$DNS_DOMAIN
    named-checkzone $REVERSE_ZONE /etc/bind/db.reverse

    log_info "Restarting BIND9..."
    systemctl restart bind9
    systemctl enable bind9

    log_info "DNS Server berhasil diinstall dan dikonfigurasi!"
    log_info "Domain: $DNS_DOMAIN"
    log_info "IP Address: $DNS_IP"
}

# Fungsi untuk install WordPress
install_wordpress() {
    log_step "Menginstall WordPress..."
    
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
    wget https://wordpress.org/latest.tar.gz
    tar -xzf latest.tar.gz
    
    mkdir -p /var/www/html/wordpress
    cp -r /tmp/wordpress/* /var/www/html/wordpress/
    
    cp /var/www/html/wordpress/wp-config-sample.php /var/www/html/wordpress/wp-config.php
    sed -i 's/database_name_here/wordpress/g' /var/www/html/wordpress/wp-config.php
    sed -i 's/username_here/wpuser/g' /var/www/html/wordpress/wp-config.php
    sed -i 's/password_here/wp123456/g' /var/www/html/wordpress/wp-config.php
    
    chown -R www-data:www-data /var/www/html/wordpress/
    chmod -R 755 /var/www/html/wordpress/
    
    systemctl restart apache2
    
    rm -rf /tmp/wordpress*
    
    log_info "WordPress berhasil diinstall"
    log_info "Akses WordPress di: http://localhost/wordpress"
    log_info "Database: wordpress | User: wpuser | Password: wp123456"
}

# Fungsi untuk install semua service
install_all() {
    log_step "Memulai instalasi semua service..."
    update_system
    install_dns
    install_apache
    install_ftp
    install_ssh
    install_wordpress
    log_info "Semua service berhasil diinstall!"
    log_info "Apache: http://localhost"
    log_info "FTP: ftp://localhost (user: admin, pass: 123)"
    log_info "SSH: ssh admin@localhost (gunakan private key)"
    log_info "DNS: $DNS_DOMAIN -> $DNS_IP"
    log_info "WordPress: http://localhost/wordpress"
}

# Fungsi untuk menampilkan menu utama
show_menu() {
    echo ""
    echo -e "${YELLOW}${BOLD}========================================${NC}"
    echo -e "${YELLOW}${BOLD}           MENU INSTALASI              ${NC}"
    echo -e "${YELLOW}${BOLD}========================================${NC}"
    echo -e "${CYAN} 1.${NC} Install Semua Service"
    echo -e "${CYAN} 2.${NC} Install Apache2 (Web Server)"
    echo -e "${CYAN} 3.${NC} Install FTP (vsftpd)"
    echo -e "${CYAN} 4.${NC} Install SSH (Secure Server)"
    echo -e "${CYAN} 5.${NC} Install DNS Server (BIND9)"
    echo -e "${CYAN} 6.${NC} Install WordPress (Optional)"
    echo -e "${CYAN} 7.${NC} Exit"
    echo ""
    echo -ne "${GREEN}Pilih menu (1-7): ${NC}"
}

prompt_menu_choice() {
    if ! IFS= read -r choice < /dev/tty; then
        echo ""
        log_error "Gagal membaca input dari terminal."
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
            install_all
            ;;
        2)
            echo ""
            install_apache
            ;;
        3)
            echo ""
            install_ftp
            ;;
        4)
            echo ""
            install_ssh
            ;;
        5)
            echo ""
            install_dns
            ;;
        6)
            echo ""
            install_wordpress
            ;;
        7)
            echo ""
            log_info "Terima kasih telah menggunakan TechCorp Multi-Service Installer!"
            echo -e "${GREEN}Script by TechCorp - All rights reserved${NC}"
            tput sgr0
            exit 0
            ;;
        *)
            log_error "Pilihan tidak valid! Silakan pilih 1-7"
            sleep 2
            ;;
    esac
    
    echo ""
    read -r -p "Tekan Enter untuk kembali ke menu utama..." < /dev/tty
    clear
done
