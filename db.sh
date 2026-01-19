#!/bin/bash
set -e

FLAG="/root/.after-reboot"

if [ ! -f "$FLAG" ]; then
    edit_file() {
    local FILE="$1"

    echo
    echo "=== Membuka $FILE untuk ditinjau ==="
    echo "Tutup nano/pico (CTRL+X) untuk melanjutkan script..."
    echo

    if command -v nano >/dev/null 2>&1; then
        nano "$FILE"
    elif command -v pico >/dev/null 2>&1; then
        pico "$FILE"
    else
        echo "Editor nano/pico tidak ditemukan, dilewati."
        read -p "Tekan ENTER untuk melanjutkan..."
    fi
}

echo "=== TAHAP 1: Konfigurasi awal sistem ==="

echo "=== Update /etc/hosts ==="
sed -i '2c\192.168.20.3        db-20' /etc/hosts
edit_file /etc/hosts

echo "=== Update hostname ==="
echo "db-20" > /etc/hostname
hostnamectl set-hostname db-20
edit_file /etc/hostname

echo "=== Update IP address ==="
sed -i 's/address[[:space:]]\+192\.168\.20\.2\/29/address 192.168.20.3\/29/' /etc/network/interfaces
edit_file /etc/network/interfaces

    echo "=== Tandai bahwa reboot akan dilakukan ==="
    touch "$FLAG"

    echo "=== Reboot sistem ==="
    systemctl reboot

    exit 0
fi

echo "apt install mariadb-server mariadb-client"
apt install mariadb-server mariadb-client -y

echo "=== Create database Moodle ==="
export MYSQL_PWD="admin"

mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS moodle
DEFAULT CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'noval'@'192.168.20.2'
IDENTIFIED BY '12345';

GRANT ALL PRIVILEGES ON moodle.* TO 'noval'@'192.168.20.2';

FLUSH PRIVILEGES;
EOF

unset MYSQL_PWD

export MYSQL_PWD="admin"
mysql -u root -e "SHOW DATABASES LIKE 'moodle';"
mysql -u root -e "SELECT Host, User FROM mysql.user WHERE User='noval';"
unset MYSQL_PWD

MYSQL_CNF="/etc/mysql/mariadb.conf.d/50-server.cnf"

echo "bind-address = 0.0.0.0"
sed -i 's/^\s*bind-address\s*=.*/bind-address = 0.0.0.0/' "$MYSQL_CNF"

echo "=== Restart MariaDB ==="
systemctl restart mariadb
systemctl restart mysqld

rm -f "$FLAG"
