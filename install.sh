#!/bin/bash

output(){
    echo -e '\e[36m'$1'\e[0m';
}

PANEL=latest
WINGS=latest

preflight(){
    output "Pterodactyl Installation & Upgrade Script"
    output "Copyright © 2018-2023 Thien Tran <contact@tommytran.io>."
    output "Please join my Matrix for community support: https://matrix.to/#/#tommy:arcticfoxes.net"
    output ""
    output "Please note that this script is meant to do installations on a fresh OS."

    if [ "$EUID" -ne 0 ]; then
        output "Please run as root."
        exit 3
    fi

    if [ -r /etc/os-release ]; then
        lsb_dist="$(. /etc/os-release && echo "$ID")"
        dist_version="$(. /etc/os-release && echo "$VERSION_ID")"
        if [ "$lsb_dist" = "rhel" ] || [ "$lsb_dist" = "rocky" ] || [ "$lsb_dist" = "almalinux" ]; then
            dist_version="$(echo $dist_version | awk -F. '{print $1}')"
        fi
    else
        exit 1
    fi

    if [ "$lsb_dist" = "rhel" ]; then
        if  [ $dist_version != "9" ]; then
            output "Unsupported RHEL version. Only RHEL 9 is supported."
            exit 2
        fi
    elif [ "$lsb_dist" = "centos" ]; then
        if [ "$dist_version" != "9" ]; then
            output "Unsupported CentOS version. Only CentOS Stream 9 is supported."
            exit 2
        fi
    elif [ "$lsb_dist" = "rocky" ]; then
        if [ "$dist_version" != "9" ]; then
            output "Unsupported Rocky Linux version. Only Rocky Linux 9 is supported."
            exit 2
        fi
    elif [ "$lsb_dist" = "almalinux" ]; then
        if [ "$dist_version" != "9" ]; then
            output "Unsupported AlmaLinux version. Only AlmaLinux 9 is supported."
            exit 2
        fi
    elif [ "$lsb_dist" != "rhel" ] && [ "$lsb_dist" != "centos" ] && [ "$lsb_dist" != "rocky" ] && [ "$lsb_dist" != "almalinux" ]; then
        output "Unsupported operating system."
        output ""
        output "Supported OS:"
        output "RHEL: 9"
        output "CentOS Stream: 9"
        output "Rocky Linux: 9"
        output "AlmaLinux: 9"
        exit 2
    fi
}

install_options(){
    output "Please select your installation option:"
    output "[1] Install the panel ${PANEL}."
    output "[2] Install the wings ${WINGS}."
    output "[3] Install the panel ${PANEL} and wings ${WINGS}."
    output "[4] Upgrade panel to ${PANEL}."
    output "[5] Upgrade wings to ${WINGS}."
    output "[6] Upgrade panel to ${PANEL} and daemon to ${WINGS}."
    output "[7] Emergency MariaDB root password reset."
    output "[8] Emergency database host information reset."
    read -r choice
    case $choice in
        1 ) installoption=1
            output "You have selected ${PANEL} panel installation only."
            ;;
        2 ) installoption=2
            output "You have selected wings ${WINGS} installation only."
            ;;
        3 ) installoption=3
            output "You have selected ${PANEL} panel and wings ${WINGS} installation."
            ;;
        4 ) installoption=4
            output "You have selected to upgrade the panel to ${PANEL}."
            ;;
        5 ) installoption=5
            output "You have selected to upgrade the daemon to ${DAEMON}."
            ;;
        6 ) installoption=6
            output "You have selected to upgrade panel to ${PANEL} and daemon to ${DAEMON}."
            ;;
        7 ) installoption=8
            output "You have selected MariaDB root password reset."
            ;;
        8 ) installoption=9
            output "You have selected Database Host information reset."
            ;;
        * ) output "You did not enter a valid selection."
            install_options
    esac
}

required_infos() {
    output "Please enter the desired user email address:"
    read -r email

    output "Please enter your FQDN (panel.domain.tld):"
    read -r FQDN

    timezone=$(timedatectl | grep "Time zone" | awk '{ print $3 }')

    dnf upgrade -y
    dnf install -y bind-utils

    output "Resolving DNS..."
    SERVER_IP=$(dig +short myip.opendns.com @resolver1.opendns.com -4)
    DOMAIN_RECORD=$(dig +short ${FQDN})
    if [ "${SERVER_IP}" != "${DOMAIN_RECORD}" ]; then
        output ""
        output "The entered domain does not resolve to the primary public IP of this server."
        output "Please make an A record pointing to your server's IP. For example, if you make an A record called 'panel' pointing to your server's IP, your FQDN is panel.domain.tld"
        output "If you are using Cloudflare, please disable the orange cloud."
        output "If you do not have a domain, you can get a free one at https://freenom.com"
        dns_check
    else
        output "Domain resolved correctly. Good to go..."
    fi
}

install_dependencies(){
    output "Installing dependencies..."

    if [ "$lsb_dist" = "rhel" ]; then
        subscription-manager repos --enable codeready-builder-for-rhel-9-$(arch)-rpms
        rpm --import https://raw.githubusercontent.com/tommytran732/Pterodactyl-Script/master/epel9.asc
        dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
    elif [ "$lsb_dist" = "centos" ]; then
        dnf config-manager --set-enabled crb
        dnf install -y epel-release epel-next-release
    else
        dnf config-manager --set-enabled crb
        dnf install -y epel-release
    fi

    #Adding Remi's repo because RHEL 9 does not have php-sodium for php 8.1 yet. Also, it is unclear whether RHEL 9 will get php 8.2 and above modules later on or not.
    rpm --import https://raw.githubusercontent.com/tommytran732/Pterodactyl-Script/master/remi9.asc
    dnf install -y https://rpms.remirepo.net/enterprise/remi-release-9.rpm

    dnf module install -y php:remi-8.1/common
    dnf install -y php-bcmath php-gd php-mysqlnd php-pdo php-sodium
    systemctl enable --now php-fpm

    dnf module install -y composer:2/common

    dnf module install -y redis:remi-7.0/common
    systemctl enable --now redis

    #Adding upstream repo because RHEL's version is extremely oudated.
    curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | sudo bash
    dnf install -y nginx mariadb-server
    systemctl enable --now mariadb

    cat > /etc/yum.repos.d/nginx.repo <<- 'EOF'
[nginx-stable]
name=nginx stable repo
baseurl=http://nginx.org/packages/centos/$releasever/$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true

[nginx-mainline]
name=nginx mainline repo
baseurl=http://nginx.org/packages/mainline/centos/$releasever/$basearch/
gpgcheck=1
enabled=0
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true
EOF
    dnf config-manager --enable nginx-mainline
    dnf install -y nginx
    systemctl enable --now nginx


    dnf install -y tuned
    tune-adm profile latency-performance

    systemctl disable --now sshd.service
    systemctl enable --now sshd.socket
}

install_pterodactyl() {
    output "Creating the databases and setting root password..."
    password=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    adminpassword=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    rootpassword=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    Q0="DROP DATABASE IF EXISTS test;"
    Q1="CREATE DATABASE IF NOT EXISTS panel;"
    Q2="SET old_passwords=0;"
    Q3="GRANT ALL ON panel.* TO 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '$password';"
    Q4="GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, RELOAD, REFERENCES, INDEX, ALTER, CREATE TEMPORARY TABLES, LOCK TABLES, CREATE VIEW, EVENT, TRIGGER, SHOW VIEW, CREATE ROUTINE, ALTER ROUTINE, EXECUTE ON *.* TO 'admin'@'$SERVER_IP' IDENTIFIED BY '$adminpassword' WITH GRANT OPTION;"
    Q5="SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$rootpassword');"
    Q6="DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    Q7="DELETE FROM mysql.user WHERE User='';"
    Q8="DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';"
    Q9="FLUSH PRIVILEGES;"
    SQL="${Q0}${Q1}${Q2}${Q3}${Q4}${Q5}${Q6}${Q7}${Q8}${Q9}"
    mysql -u root -e "$SQL"

    output "Binding MariaDB/MySQL to 0.0.0.0"
    if grep -Fqs "bind-address" /etc/my.cnf.d/server.cnf ; then
        sed -i 's/#bind-address=0.0.0.0/bind-address=0.0.0.0/' /etc/my.cnf.d/server.cnf
        output 'Restarting MariaDB process...'
        systemctl restart mariadb
    else
        output 'A MariaDB configuration file could not be detected! Please contact support.'
    fi

    output "Downloading Pterodactyl..."
    mkdir -p /var/www/pterodactyl
    cd /var/www/pterodactyl || exit
    if [ ${PANEL} = "latest" ]; then
        curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    else
        curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/download/${PANEL}/panel.tar.gz
    fi
    tar -xzvf panel.tar.gz
    chmod -R 755 storage/* bootstrap/cache/

    output "Installing Pterodactyl..."

    cp .env.example .env
    composer update --no-interaction
    composer install --no-dev --optimize-autoloader --no-interaction

    php artisan key:generate --force
    php artisan p:environment:setup -n --author=$email --url=https://$FQDN --timezone=${timezone} --cache=redis --session=database --queue=redis --redis-host=127.0.0.1 --redis-pass= --redis-port=6379
    php artisan p:environment:database --host=127.0.0.1 --port=3306 --database=panel --username=pterodactyl --password=$password
    output "To use PHP's internal mail sending, select [mail]. To use a custom SMTP server, select [smtp]. TLS Encryption is recommended."
    php artisan p:environment:mail
    php artisan migrate --seed --force
    php artisan p:user:make --email=$email --admin=1
    sed -i 's/PTERODACTYL_TELEMETRY_ENABLED=true/PTERODACTYL_TELEMETRY_ENABLED=false/' /var/www/pterodactyl/.env

    chown -R nginx:nginx * /var/www/pterodactyl

    cat > /etc/systemd/system/pteros.service <<- 'EOF'
# Pterodactyl Schedule Service
# ----------------------------------

[Unit]
Description=Pterodactyl Schedule Service

[Service]
# On some systems the user and group might be different.
# Some systems use `apache` or `nginx` as the user and group.
User=nginx
Group=nginx
ExecStart=php /var/www/pterodactyl/artisan schedule:run
StandardOutput=null
Type=oneshot
EOF

    cat > /etc/systemd/system/pteros.timer <<- 'EOF'
# Pterodactyl Schedule Service Timer
# ----------------------------------

[Unit]
Description=Pterodactyl Schedule Service Timer

[Timer]
OnCalendar=*-*-* *:*:00

[Install]
WantedBy=timers.target
EOF

    cat > /etc/systemd/system/pteroq.service <<- 'EOF'
# Pterodactyl Queue Worker File
# ----------------------------------

[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
# On some systems the user and group might be different.
# Some systems use `apache` or `nginx` as the user and group.
User=nginx
Group=nginx
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    systemctl enable --now pteros.timer
    systemctl enable --now pteroq.service
}

upgrade_pterodactyl(){
    cd /var/www/pterodactyl && php artisan p:upgrade
    chown -R nginx:nginx /var/www/pterodactyl
    output "Your panel has successfully been updated to version ${PANEL}"
}

webserver_config(){

    output "Configuring PHP socket..."
    bash -c 'cat > /etc/php-fpm.d/www-pterodactyl.conf' <<-'EOF'
[pterodactyl]

user = nginx
group = nginx

listen = /run/php-fpm/pterodactyl.sock
listen.owner = nginx
listen.group = nginx
listen.mode = 0750

pm = ondemand
pm.max_children = 9
pm.process_idle_timeout = 10s
pm.max_requests = 200
EOF
    systemctl restart php-fpm

    output "Configuring Nginx web server..."

    rm -f /etc/nginx/conf.d/default.conf

    cat > /etc/nginx/conf.d/pterodactyl.conf <<- 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name FQDN;
    return 301 https://$server_name$request_uri;
}
server {
    listen 443 ssl http2 default_server;
    listen [::]:443 ssl http2 default_server;
    server_name FQDN;
    root /var/www/pterodactyl/public;
    index index.php;

    access_log /var/log/nginx/pterodactyl.app-access.log;
    error_log  /var/log/nginx/pterodactyl.app-error.log error;

    # allow larger file uploads and longer script runtimes
    client_max_body_size 100m;
    client_body_timeout 120s;

    sendfile off;
    ssl_certificate /etc/letsencrypt/live/FQDN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/FQDN/privkey.pem;
    ssl_session_cache shared:SSL:10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers "ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256";
    ssl_prefer_server_ciphers on;

    add_header Strict-Transport-Security "max-age=15768000; includeSubDomains; preload" always;
    add_header Content-Security-Policy "default-src 'none'; connect-src *; font-src 'self' https://fonts.gstatic.com https://cdnjs.cloudflare.com; img-src 'self' https://www.gravatar.com; frame-src https://recaptcha.net; manifest-src 'self'; script-src 'self' 'unsafe-inline' https://recaptcha.net https://www.gstatic.com; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com https://cdnjs.cloudflare.com; frame-ancestors 'self'; block-all-mixed-content; base-uri 'none'";
    add_header Permissions-Policy "accelerometer=(), ambient-light-sensor=(), autoplay=(), battery=(), camera=(), clipboard-read=(), display-capture=(), document-domain=(), encrypted-media=(), fullscreen=(), geolocation=(), gyroscope=(), hid=(), idle-detection=(), interest-cohort=(), magnetometer=(), midi=(), payment=(), picture-in-picture=(), publickey-credentials-get=(), screen-wake-lock=(), serial=(), usb=(), sync-xhr=(), xr-spatial-tracking=()";
    add_header Referrer-Policy "same-origin" always;
    add_header X-Content-Type-Options "nosniff" always;
    #add_header X-UA-Compatible "IE=Edge" always;
    add_header X-XSS-Protection "0" always;
    add_header Cross-Origin-Resource-Policy same-origin;
    add_header Cross-Origin-Opener-Policy same-origin;
    add_header X-XSS-Protection "0" always;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php-fpm/pterodactyl.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
        include /etc/nginx/fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

    sed -i "s/FQDN/${FQDN}/g" /etc/nginx/conf.d/pterodactyl.conf

    service nginx restart
    restorecon -R /var/www/pterodactyl
    setsebool -P httpd_can_network_connect 1
    setsebool -P httpd_execmem 1
    setsebool -P httpd_unified 1
}

install_wings() {
    output "Installing Docker"
    dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    dnf -y --allowerasing install docker-ce

    systemctl enable --now docker
    output "Installing the Pterodactyl wings..."
    mkdir -p /etc/pterodactyl
    cd /etc/pterodactyl || exit
    if [ ${WINGS} = "latest" ]; then
        curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
    else
        curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/download/${WINGS}/wings_linux_amd64
    fi
    chmod u+x /usr/local/bin/wings

      bash -c 'cat > /etc/systemd/system/wings.service' <<-'EOF'
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service
PartOf=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    systemctl enable wings

    output "Adding Fail2ban rules for Wings SFTP"
    echo '[wings]
enabled = true
port    = 2022
logpath = /var/log/pterodactyl/wings.log
maxretry = 5
findtime = 3600
bantime = -1
backend = systemd' | tee -a /etc/fail2ban/jail.local

    bash -c 'cat > /etc/fail2ban/conf.d/wings.conf' <<-'EOF'
# Fail2Ban filter for wings (Pterodactyl daemon)
#
#
#
# "WARN: [Sep  8 18:51:00.414] failed to validate user credentials (invalid format) ip=<HOST>:51782 subsystem=sftp username=logout"
#
[INCLUDES]
before = common.conf
[Definition]
_daemon = wings
failregex = failed to validate user credentials \([^\)]+\) ip=<HOST>:.* subsystem=sftp username=.*$
ignoreregex =
[Init]
datepattern = \[%%b %%d %%H:%%M:%%S.%%f\]
EOF
    systemctl restart fail2ban

    output "Wings ${WINGS} has now been installed on your system."
    output "You should go to your panel and configure the node now."
    output "If you get `bash: wings: command not found` when running the auto deployment command, replace `wings` with `/usr/local/bin/wings` and it will work."
    output "Do `systemctl start wings` after you are done configuring the node."
}


upgrade_wings(){
    systemctl stop wings
    if [ ${WINGS} = "latest" ]; then
        curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
    else
        curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/download/${WINGS}/wings_linux_amd64
    fi
    chmod u+x /usr/local/bin/wings
    systemctl start wings
    output "Your wings have been updated to version ${WINGS}."
}

firewall(){
    if [ "$installoption" = "2" ]; then
        if [ "$lsb_dist" = "rhel" ]; then
            subscription-manager repos --enable codeready-builder-for-rhel-9-$(arch)-rpms
            rpm --import https://raw.githubusercontent.com/tommytran732/Pterodactyl-Script/master/epel9.asc
            dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
        elif [ "$lsb_dist" = "centos" ]; then
            dnf config-manager --set-enabled crb
            dnf install -y epel-release epel-next-release
        else
            dnf config-manager --set-enabled crb
            dnf install -y epel-release
        fi
    fi

    output "Setting up Fail2Ban..."
    dnf -y install fail2ban
    systemctl enable --now fail2ban
    bash -c 'cat > /etc/fail2ban/jail.local' <<-'EOF'
[DEFAULT]
# Ban hosts for ten hours:
bantime = 36000
[sshd]
enabled = true
EOF
    systemctl restart fail2ban

    output "Configuring your firewall..."
    dnf -y install firewalld
    systemctl enable --now firewalld
    firewall-cmd --remove-service=cockpit
    if [ "$installoption" = "1" ]; then
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        firewall-cmd --permanent --add-service=mysql
    elif [ "$installoption" = "2" ]; then
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-port=2022/tcp
        firewall-cmd --permanent --add-port=8080/tcp
        firewall-cmd --zone=trusted --add-masquerade --permanent
    elif [ "$installoption" = "3" ]; then
        firewall-cmd --add-service=http --permanent
        firewall-cmd --add-service=https --permanent
        firewall-cmd --permanent --add-port=2022/tcp
        firewall-cmd --permanent --add-port=8080/tcp
        firewall-cmd --permanent --add-service=mysql
        firewall-cmd --zone=trusted --add-masquerade --permanent
    fi
    firewall-cmd --reload
}

ssl_certs(){
    output "Installing Let's Encrypt and creating an SSL certificate..."
    dnf -y install certbot

    if [ "$installoption" = "1" ] || [ "$installoption" = "3" ]; then
        dnf -y install python3-certbot-nginx
        certbot --nginx --redirect --no-eff-email --email "$email" --agree-tos -d "$FQDN"
        setfacl -Rdm u:mysql:rx /etc/letsencrypt
        setfacl -Rm u:mysql:rx /etc/letsencrypt
        sed -i '/\[mysqld\]/a ssl-key=/etc/letsencrypt/live/'"${FQDN}"'/privkey.pem' /etc/my.cnf.d/server.cnf
        sed -i '/\[mysqld\]/a ssl-ca=/etc/letsencrypt/live/'"${FQDN}"'/chain.pem' /etc/my.cnf.d/server.cnf
        sed -i '/\[mysqld\]/a ssl-cert=/etc/letsencrypt/live/'"${FQDN}"'/cert.pem' /etc/my.cnf.d/server.cnf
        systemctl restart mariadb
    fi

    if [ "$installoption" = "2" ]; then
    certbot certonly --standalone --no-eff-email --email "$email" --agree-tos -d "$FQDN" --non-interactive
    fi
    systemctl enable --now certbot-renew.timer
}

linux_hardening(){
    curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/modprobe.d/30_security-misc.conf -o /etc/modprobe.d/30_security-misc.conf
    curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/sysctl.d/30_security-misc.conf -o /etc/sysctl.d/30_security-misc.conf
    sed -i 's/kernel.yama.ptrace_scope=2/kernel.yama.ptrace_scope=3/g' /etc/sysctl.d/30_security-misc.conf
    curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/sysctl.d/30_silent-kernel-printk.conf -o /etc/sysctl.d/30_silent-kernel-printk.conf
    sysctl -p

    curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/chrony.conf -o /etc/chrony.conf
    systemctl restart chronyd

    mkdir -p /etc/systemd/system/NetworkManager.service.d
    curl https://gitlab.com/divested/brace/-/raw/master/brace/usr/lib/systemd/system/NetworkManager.service.d/99-brace.conf -o /etc/systemd/system/NetworkManager.service.d/99-brace.conf
    systemctl restart NetworkManager

    mkdir -p /etc/systemd/system/irqbalance.service.d
    curl https://gitlab.com/divested/brace/-/raw/master/brace/usr/lib/systemd/system/irqbalance.service.d/99-brace.conf -o /etc/systemd/system/irqbalance.service.d/99-brace.conf
    systemctl restart irqbalance

    mkdir -p /etc/systemd/system/sshd.service.d
    curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/systemd/system/sshd.service.d/limits.conf -o /etc/systemd/system/sshd.service.d/limits.conf
    systemctl restart sshd

    if [ "$lsb_dist" = "rhel" ]; then
        insights-client --register
        dnf install -y yara
        insights-client --collector malware-detection
        sed -i 's/test_scan: true/test_scan: false/' /etc/insights-client/malware-detection-config.yml
    fi
}

database_host_reset(){
    adminpassword=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    Q0="SET old_passwords=0;"
    Q1="SET PASSWORD FOR 'admin'@'$SERVER_IP' = PASSWORD('$adminpassword');"
    Q2="FLUSH PRIVILEGES;"
    SQL="${Q0}${Q1}${Q2}"
    mysql mysql -e "$SQL"
    output "New database admin user information:"
    output "User: admin"
    output "Password: $adminpassword"
}

print_info(){
    if [ "$installoption" = "1" ] || [ "$installoption" = "3" ]; then
        print_info_database
    fi
    output "------------------------------------------------------------------"
    output "FIREWALL INFORMATION"
    output ""
    output "All unnecessary ports are blocked by default."
    output "Use 'firewall-cmd --permanent --add-port=<port>/tcp' to enable your desired ports."
    output "------------------------------------------------------------------"
    output ""
}

print_info_database(){
    output "------------------------------------------------------------------"
    output "MARIADB/MySQL INFORMATION"
    output ""
    output "Your MariaDB/MySQL root password is $rootpassword"
    output ""
    output "Create your MariaDB/MySQL host with the following information:"
    output "Host: ${FQDN}"
    output "Port: 3306"
    output "User: admin"
    output "Password: $adminpassword"
    output "------------------------------------------------------------------"
    output ""
}

#Execution
preflight
install_options
case $installoption in
    1)  required_infos
        linux_hardening
        install_dependencies
        install_pterodactyl
        firewall
        ssl_certs
        webserver_config
        print_info
        print_info_database
        ;;
    2)  required_infos
        linux_hardening
        firewall
        ssl_certs
        install_wings
        print_info
        print_info_database
        ;;
    3)  required_infos
        linux_hardening
        install_dependencies
        install_pterodactyl
        firewall
        ssl_certs
        webserver_config
        install_wings
        print_info
        ;;
    4)  upgrade_pterodactyl
        ;;
    5)  upgrade_wings
        ;;
    6)  upgrade_pterodactyl
        upgrade_wings
        ;;
    7)  curl -sSL https://raw.githubusercontent.com/tommytran732/MariaDB-Root-Password-Reset/master/mariadb-104.sh | sudo bash
        ;;
    8)  database_host_reset
        ;;
esac
