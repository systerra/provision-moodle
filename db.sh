#!/bin/bash
set -e

echo "=== Update /etc/hosts ==="
sed -i '2c\192.168.20.3       db-20' /etc/hosts

echo "=== Update hostname ==="
echo "db-20" > /etc/hostname
hostnamectl set-hostname db-20

echo "=== Update IP address ==="
sed -i 's/address[[:space:]]\+192\.168\.20\.2\/29/address 192.168.20.3\/29/' \
    /etc/network/interfaces

echo "=== Restart networking ==="
systemctl restart networking || true

echo "=== Menunggu network siap ==="
sleep 10

# Tunggu sampai network benar-benar up (maks 60 detik)
for i in {1..12}; do
    if ping -c1 -W1 8.8.8.8 >/dev/null 2>&1; then
        echo "Network siap."
        break
    fi
    echo "Menunggu network... ($i)"
    sleep 5
done

echo "=== Install MariaDB Server & Client ==="
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

echo "=== Verifikasi User & Database ==="
export MYSQL_PWD="admin"
mysql -u root -e "SHOW DATABASES LIKE 'moodle';"
mysql -u root -e "SELECT Host, User FROM mysql.user WHERE User='noval';"
unset MYSQL_PWD

MYSQL_CNF="/etc/mysql/mariadb.conf.d/50-server.cnf"

echo "=== Konfigurasi bind-address ==="
sed -i 's/^\s*bind-address\s*=.*/bind-address = 0.0.0.0/' "$MYSQL_CNF"

echo "=== Restart MariaDB ==="
systemctl restart mariadb
systemctl restart mysqld
