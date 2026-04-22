# TechCorp Multi-Service Installer

Script otomatis untuk instalasi dan konfigurasi multi-service di Debian Linux. Sekarang dilengkapi dengan dukungan **DNS Server (BIND9)** kustom.

## Services yang Diinstall
- **BIND9 DNS Server** - DNS Master Zone dengan domain kustom dan pemilihan IP interface.
- **Apache2** - Web Server dengan halaman profil TechCorp yang modern.
- **vsftpd** - FTP Server aman dengan user isolated.
- **OpenSSH** - SSH Server dengan pengamanan key-based authentication.
- **WordPress** - CMS WordPress terbaru dengan database MariaDB (opsional).

---

## Quick Install

### Linux (Debian)
Gunakan perintah satu baris ini untuk instalasi cepat:
```bash
curl -s https://dhiksn.github.io/debian-multiservice/install | sudo bash
```

atau menggunakan versi `setup.sh`:
```bash
curl -s https://dhiksn.github.io/debian-multiservice/setup | sudo bash
```

### Manual Installation
```bash
# Clone repo
git clone https://github.com/dhiksn/debian-multiservice.git
cd debian-multiservice

# Jalankan script
chmod +x install.sh
sudo bash install.sh
```

---

## Menu Instalasi (Update v2.0)

Script ini menyediakan menu interaktif yang mudah digunakan:
```
╔══════════════════════════════════╗
║         MENU INSTALASI           ║
╠══════════════════════════════════╣
║  1. Install Semua Service        ║
║  2. Install Apache2 (Web Server) ║
║  3. Install FTP (vsftpd)         ║
║  4. Install SSH (Secure Server)  ║
║  5. Install DNS Server (BIND9)   ║
║  6. Install WordPress            ║
║  7. Exit                         ║
╚══════════════════════════════════╝
```

---

## Kredensial & Detail Service

> ⚠️ **PENTING:** Segera ganti password default setelah instalasi selesai untuk alasan keamanan!

| Service | User | Password / Auth | Keterangan |
| :--- | :--- | :--- | :--- |
| **DNS (BIND9)** | - | - | Domain Kustom (Default: `techcorp.com`) |
| **FTP (vsftpd)** | `admin` | `123` | Direktori: `/home/admin/ftp/upload` |
| **SSH Server** | `admin` | `Key-Based` | Password login dinonaktifkan secara default |
| **WordPress** | `wp_user` | `WpTechCorp@2024` | Nama DB: `wordpress_db` |
| **MariaDB** | `wp_user` | `WpTechCorp@2024` | User database lokal |
| **Apache2** | - | - | Port: 80 |

### Fitur Baru: IP Selection
Saat menginstall **DNS** atau **Apache**, script akan mendeteksi interface jaringan aktif dan meminta Anda memilih IP mana yang akan digunakan. Ini sangat berguna jika server Anda memiliki lebih dari satu interface (misal: IP Lokal dan IP Publik).

---

## Requirements
- Debian Linux (10, 11, atau 12)
- Akses root atau user dengan hak `sudo`
- Koneksi internet aktif

---

## Repository & Kontribusi
- GitHub: [dhiksn/debian-multiservice](https://github.com/dhiksn/debian-multiservice)
- Pages: [Documentation](https://dhiksn.github.io/debian-multiservice)

---

## License
MIT License - **TechCorp Indonesia**
