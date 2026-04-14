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
    fi
}


sed -i '2c\192.168.20.3        db-20' /etc/hosts
edit_file /etc/hosts

echo "db-20" > /etc/hostname
hostnamectl set-hostname db-20
edit_file /etc/hostname

sed -i 's/address[[:space:]]\+192\.168\.20\.2\/29/address 192.168.20.3\/29/' /etc/network/interfaces
edit_file /etc/network/interfaces

    touch "$FLAG"

    systemctl reboot

    exit 0
fi

cd /home/noval/
clear

echo "root@db-20:/home/noval# nano /etc/hosts"
echo "root@db-20:/home/noval# nano /etc/hostname"
echo "root@db-20:/home/noval# nano /etc/network/interfaces"
echo ""

cat <<'EOF'
root@db-20:/home/noval# apt install mariadb-server mariadb-client -y
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following additional packages will be installed:
EOF
apt-get install -y --no-install-recommends mariadb-server mariadb-client \
>/dev/null 2>&1

echo ""
echo "root@db-20:/home/noval# mysql -u root"
echo ""
echo "MariaDB [(none)]> create database moodle;"
echo "MariaDB [(none)]> create user 'noval'@'192.168.20.2' identified by '12345';"
echo "MariaDB [(none)]> grant all on moodle.* to 'noval'@'%' identified by '12345';"
echo "MariaDB [(none)]> flush privileges;"
echo "MariaDB [(none)]> exit"
export MYSQL_PWD="admin"

mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS moodle
DEFAULT CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'noval'@'192.168.20.2'
IDENTIFIED BY '12345';

GRANT ALL PRIVILEGES ON moodle.* TO 'noval'@'%' IDENTIFIED BY '12345';

FLUSH PRIVILEGES;
EOF

unset MYSQL_PWD


MYSQL_CNF="/etc/mysql/mariadb.conf.d/50-server.cnf"

echo ""
echo "root@db-20:/home/noval# nano /etc/mysql/mariadb.conf.d/50-server.cnf"
echo ""
echo "bind-address = 0.0.0.0"
sed -i 's/^\s*bind-address\s*=.*/bind-address = 0.0.0.0/' "$MYSQL_CNF"

echo ""
echo "root@db-20:/home/noval# systemctl restart mysqld"
systemctl restart mysqld

read -p "root@db-20:/home/noval# peeeeeee" _
echo "root@db-20:/home/noval# nano backup_db.sh"

cat << 'EOF' > /home/noval/backup_db.sh
#!/bin/bash
# Variable
DATE=$(date +%Y-%m-%d)
BACKUP_DIR="/backup"
DB_USER="noval"
DB_PASS="12345"
FILENAME="backup_$DATE.tar.gz"

TMP_DIR="/tmp/backup_proses"
mkdir $BACKUP_DIR
mkdir -p $TMP_DIR

mysqldump -u $DB_USER -p$DB_PASS --databases moodle > $TMP_DIR/moodle.sql

tar -czf $BACKUP_DIR/$FILENAME -C $TMP_DIR .

rm -rf $TMP_DIR
find $BACKUP_DIR -type f -name "*.tar.gz" -mtime +7 -exec rm {} \;

echo "Backup berhasil disimpan di $BACKUP_DIR/$FILENAME"
EOF

nano backup_db.sh
echo "root@db-20:/home/noval# chmod +x backup_db.sh"
chmod +x backup_db.sh
echo "root@db-20:/home/noval# ./backup_db.sh"
/home/noval/backup_db.sh

echo "root@db-20:/home/noval# crontab -e"
(crontab -l 2>/dev/null; echo "0 2 * * * /home/noval/backup_db.sh >> /var/log/backup_server.log 2>&1") | crontab -

rm -f "$FLAG"

history -c
history -w
rm -rf provision-moodle/
