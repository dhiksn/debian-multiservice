# TechCorp Multi-Service Installer

Script otomatis untuk instalasi dan konfigurasi multi-service di Debian Linux.

## Services yang Diinstall
- **Apache2** - Web Server dengan halaman profil TechCorp
- **vsftpd** - FTP Server dengan user `admin`
- **OpenSSH** - SSH Server dengan key-based authentication
- **WordPress** - CMS dengan MariaDB (opsional)

---

## Quick Install

### Linux (Debian)
```bash
curl -s https://<username>.github.io/<repo>/install | sudo bash
```

atau kalau mau versi `dwa/`:
```bash
curl -s https://<username>.github.io/<repo>/dwa/setup | sudo bash
```

### Manual
```bash
# Clone repo
git clone https://github.com/<username>/<repo>.git
cd <repo>

# Jalankan script
chmod +x install.sh
sudo bash install.sh
```

---

## Generate Script (Windows)

Kalau mau generate ulang `install.sh` dari PowerShell:
```powershell
.\Generate-SetupScript.ps1
```

Atau untuk versi `dwa/setup.sh`:
```powershell
.\dwa\Generate-DebianSetup.ps1
```

---

## Menu Instalasi

```
╔══════════════════════════════════╗
║         MENU INSTALASI           ║
╠══════════════════════════════════╣
║  1. Install Semua Service        ║
║  2. Install Apache2 (Web Server) ║
║  3. Install FTP (vsftpd)         ║
║  4. Install SSH (Secure Server)  ║
║  5. Install WordPress            ║
║  6. Exit                         ║
╚══════════════════════════════════╝
```

---

## Kredensial Default

> ⚠️ Ganti semua kredensial default setelah instalasi!

| Service    | User    | Password         |
|------------|---------|------------------|
| FTP        | admin   | 123              |
| SSH        | admin   | key-based auth   |
| WordPress  | wp_user | WpTechCorp@2024  |
| MariaDB    | wp_user | WpTechCorp@2024  |

---

## Requirements
- Debian Linux (latest)
- Akses root / sudo
- Koneksi internet

---

## License
MIT License - TechCorp Indonesia
