#!/bin/bash

output(){
    echo -e '\e[36m'$1'\e[0m';
}

warn(){
    echo -e '\e[31m'$1'\e[0m';
}

PANEL=v1.6.2
WINGS=v1.5.1
PHPMYADMIN=5.1.1

preflight(){
    output "Pterodactyl Installation & Upgrade Script"
    output "Copyright © 2021 Thien Tran <contact@tommytran.io>."
    output "Please join my Matrix for community support: https://matrix.to/#/#tommytran732:matrix.org"
    output ""

    output "Please note that this script is meant to be installed on a fresh OS. Installing it on a non-fresh OS may cause problems."
    output "Automatic operating system detection initialized..."

    os_check

    if [ "$EUID" -ne 0 ]; then
        output "Please run as root."
        exit 3
    fi

    output "Automatic architecture detection initialized..."
    MACHINE_TYPE=`uname -m`
    if [ "${MACHINE_TYPE}" == 'x86_64' ]; then
        output "64-bit server detected! Good to go."
        output ""
    else
        output "Unsupported architecture detected! Please switch to 64-bit (x86_64)."
        exit 4
    fi

    output "Automatic virtualization detection initialized..."
    if [ "$lsb_dist" =  "ubuntu" ]; then
        apt-get update --fix-missing
        apt-get -y install software-properties-common
        add-apt-repository -y universe
        apt-get -y install virt-what curl
    elif [ "$lsb_dist" =  "debian" ]; then
        apt update --fix-missing
        apt-get -y install software-properties-common virt-what wget curl dnsutils
    elif [ "$lsb_dist" = "fedora" ] || [ "$lsb_dist" = "centos" ] || [ "$lsb_dist" = "rhel" ] || [ "$lsb_dist" = "rocky" ] || [ "$lsb_dist" = "almalinux" ]; then
        yum -y install virt-what wget bind-utils
    fi
    virt_serv=$(echo $(virt-what))
    if [ "$virt_serv" = "" ]; then
        output "Virtualization: Bare Metal detected."
    elif [ "$virt_serv" = "openvz lxc" ]; then
        output "Virtualization: OpenVZ 7 detected."
    elif [ "$virt_serv" = "xen xen-hvm" ]; then
        output "Virtualization: Xen-HVM detected."
    elif [ "$virt_serv" = "xen xen-hvm aws" ]; then
        output "Virtualization: Xen-HVM on AWS detected."
        warn "When creating allocations for this node, please use the internal IP as Google Cloud uses NAT routing."
        warn "Resuming in 10 seconds..."
        sleep 10
    else
        output "Virtualization: $virt_serv detected."
    fi
    output ""
    if [ "$virt_serv" != "" ] && [ "$virt_serv" != "kvm" ] && [ "$virt_serv" != "vmware" ] && [ "$virt_serv" != "hyperv" ] && [ "$virt_serv" != "openvz lxc" ] && [ "$virt_serv" != "xen xen-hvm" ] && [ "$virt_serv" != "xen xen-hvm aws" ]; then
        warn "Unsupported type of virtualization detected. Please consult with your hosting provider whether your server can run Docker or not. Proceed at your own risk."
        warn "No support would be given if your server breaks at any point in the future."
        warn "Proceed?\n[1] Yes.\n[2] No."
        read choice
        case $choice in 
            1)  output "Proceeding..."
                ;;
            2)  output "Cancelling installation..."
                exit 5
                ;;
        esac
        output ""
    fi

    output "Kernel detection initialized..."
    if echo $(uname -r) | grep -q xxxx; then
        output "OVH kernel detected. This script will not work. Please reinstall your server using a generic/distribution kernel."
        output "When you are reinstalling your server, click on 'custom installation' and click on 'use distribution' kernel after that."
        output "You might also want to do custom partitioning, remove the /home partition and give / all the remaining space."
        output "Please do not hesitate to contact us if you need help regarding this issue."
        exit 6
    elif echo $(uname -r) | grep -q pve; then
        output "Proxmox LXE kernel detected. You have chosen to continue in the last step, therefore we are proceeding at your own risk."
        output "Proceeding with a risky operation..."
    elif echo $(uname -r) | grep -q stab; then
        if echo $(uname -r) | grep -q 2.6; then 
            output "OpenVZ 6 detected. This server will definitely not work with Docker, regardless of what your provider might say. Exiting to avoid further damages."
            exit 6
        fi
    elif echo $(uname -r) | grep -q gcp; then
        output "Google Cloud Platform detected."
        warn "Please make sure you have a static IP setup, otherwise the system will not work after a reboot."
        warn "Please also make sure the GCP firewall allows the ports needed for the server to function normally."
        warn "When creating allocations for this node, please use the internal IP as Google Cloud uses NAT routing."
        warn "Resuming in 10 seconds..."
        sleep 10
    else
        output "Did not detect any bad kernel. Moving forward..."
        output ""
    fi
}

os_check(){
    if [ -r /etc/os-release ]; then
        lsb_dist="$(. /etc/os-release && echo "$ID")"
        dist_version="$(. /etc/os-release && echo "$VERSION_ID")"
        if [ "$lsb_dist" = "rhel" ] || [ "$lsb_dist" = "rocky" ]; then
            dist_version="$(echo $dist_version | awk -F. '{print $1}')"
        fi
    else
        exit 1
    fi
    
    if [ "$lsb_dist" =  "ubuntu" ]; then
        if  [ "$dist_version" != "20.04" ]; then
            output "Unsupported Ubuntu version. Only Ubuntu 20.04 is supported."
            exit 2
        fi
    elif [ "$lsb_dist" = "debian" ]; then
        if [ "$dist_version" != "11" ]; then
            output "Unsupported Debian version. Only Debian 10 is supported."
            exit 2
        fi
    elif [ "$lsb_dist" = "fedora" ]; then
        if [ "$dist_version" != "35" ]; then
            output "Unsupported Fedora version. Only Fedora 34 is supported."
            exit 2
        fi
    elif [ "$lsb_dist" = "centos" ]; then
        if [ "$dist_version" != "8" ]; then
            output "Unsupported CentOS version. Only CentOS Stream 8 is supported."
            exit 2
        fi
    elif [ "$lsb_dist" = "rhel" ]; then
        if  [ $dist_version != "8" ]; then
            output "Unsupported RHEL version. Only RHEL 8 is supported."
            exit 2
        fi
    elif [ "$lsb_dist" = "rocky" ]; then
        if [ "$dist_version" != "8" ]; then
            output "Unsupported Rocky Linux version. Only Rocky Linux 8 is supported."
            exit 2
        fi
    elif [ "$lsb_dist" = "almalinux" ]; then
        if [ "$dist_version" != "8" ]; then
            output "Unsupported AlmaLinux version. Only AlmaLinux 8 is supported."
            exit 2
        fi
    elif [ "$lsb_dist" != "ubuntu" ] && [ "$lsb_dist" != "debian" ] && [ "$lsb_dist" != "fedora" ] && [ "$lsb_dist" != "centos" ] && [ "$lsb_dist" != "rhel" ] && [ "$lsb_dist" != "rocky" ] && [ "$lsb_dist" != "almalinux" ]; then
        output "Unsupported operating system."
        output ""
        output "Supported OS:"
        output "Ubuntu: 20.04"
        output "Debian: 11"
        output "Fedora: 35"
        output "CentOS Stream: 8"
        output "Rocky Linux: 8"
	output "AlmaLinux: 8"
        output "RHEL: 8"
        exit 2
    fi
}

install_options(){
    output "Please select your installation option:"
    output "[1] Install the panel ${PANEL}."
    output "[2] Install the wings ${WINGS}."
    output "[3] Install the panel ${PANEL} and wings ${WINGS}."
    output "[4] Upgrade panel to ${PANEL}."
    output "[5] Upgrade daemon to ${DAEMON}."
    output "[6] Upgrade panel to ${PANEL} and daemon to ${DAEMON}."
    output "[7] Install or update to phpMyAdmin (${PHPMYADMIN}) (only use this after you have installed the panel)."
    output "[8] Emergency MariaDB root password reset."
    output "[9] Emergency database host information reset."
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
        7 ) installoption=7
            output "You have selected to install or update to phpMyAdmin (${PHPMYADMIN}."
            ;;
        8 ) installoption=8
            output "You have selected MariaDB root password reset."
            ;;
        9 ) installoption=9
            output "You have selected Database Host information reset."
            ;;
        * ) output "You did not enter a valid selection."
            install_options
    esac
}

required_infos() {
    output "Please enter the desired user email address:"
    read -r email
    dns_check
}

dns_check(){
    output "Please enter your FQDN (panel.domain.tld):"
    read -r FQDN

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

repositories_setup(){
    output "Configuring your repositories..."
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        apt-get -y install sudo
        apt-get -y install software-properties-common curl apt-transport-https ca-certificates gnupg
        dpkg --remove-architecture i386
        echo 'Acquire::ForceIPv4 "true";' | sudo tee /etc/apt/apt.conf.d/99force-ipv4
        apt-get -y update
	curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash
        if [ "$lsb_dist" =  "ubuntu" ]; then
            LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
	    apt -y install tuned dnsutils
            tuned-adm profile latency-performance
        elif [ "$lsb_dist" =  "debian" ]; then
            apt-get -y install ca-certificates apt-transport-https
            echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/php.list
            apt -y install dirmngr
            wget -q https://packages.sury.org/php/apt.gpg -O- | sudo apt-key add -
            sudo apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
            apt -y install tuned
            tuned-adm profile latency-performance
            apt-get -y update
            apt-get -y upgrade
            apt-get -y autoremove
            apt-get -y autoclean
            apt-get -y install curl
        fi
    elif  [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" = "rocky" ] || [ "$lsb_dist" != "almalinux" ]; then
    	dnf -y install dnf-utils
        if  [ "$lsb_dist" =  "fedora" ] ; then
            dnf -y install http://rpms.remirepo.net/fedora/remi-release-35.rpm
	else	
	    dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
	    dnf -y install http://rpms.remirepo.net/enterprise/remi-release-8.rpm
	fi
	dnf config-manager --set-enabled remi
        dnf -y install tuned
        tuned-adm profile latency-performance
        dnf -y upgrade
        dnf -y autoremove
        dnf -y clean packages
        dnf -y install curl bind-utils cronie
    fi
}

install_dependencies(){
    output "Installing dependencies..."
    if  [ "$lsb_dist" =  "ubuntu" ] ||  [ "$lsb_dist" =  "debian" ]; then
        apt -y install php8.0 php8.0-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip} nginx tar unzip git redis-server nginx git wget expect
        sh -c "DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-unauthenticated mariadb-server"
    else
	dnf -y module install mariadb:10.5/server
	dnf -y module install php:remi-8.0/common
	dnf -y module install redis:remi-6.2/common
	dnf -y module install nginx:mainline/common
        dnf -y install git policycoreutils-python-utils unzip wget expect jq php-mysql php-zip php-bcmath tar
    fi

    output "Enabling Services..."
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        systemctl enable --now redis-server
        systemctl enable --now php8.0-fpm
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" = "rocky" ] || [ "$lsb_dist" != "almalinux" ]; then
        systemctl enable --now redis
        systemctl enable --now php-fpm
    fi

    systemctl enable --now cron
    systemctl enable --now mariadb
    systemctl enable --now nginx
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
    Q4="GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, DROP, EXECUTE, PROCESS, RELOAD, LOCK TABLES, CREATE USER ON *.* TO 'admin'@'$SERVER_IP' IDENTIFIED BY '$adminpassword' WITH GRANT OPTION;"
    Q5="SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$rootpassword');"
    Q6="DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    Q7="DELETE FROM mysql.user WHERE User='';"
    Q8="DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';"
    Q9="FLUSH PRIVILEGES;"
    SQL="${Q0}${Q1}${Q2}${Q3}${Q4}${Q5}${Q6}${Q7}${Q8}${Q9}"
    mysql -u root -e "$SQL"

    output "Binding MariaDB/MySQL to 0.0.0.0."
        if grep -Fqs "bind-address" /etc/mysql/mariadb.conf.d/50-server.cnf ; then
		sed -i -- '/bind-address/s/#//g' /etc/mysql/mariadb.conf.d/50-server.cnf
 		sed -i -- '/bind-address/s/127.0.0.1/0.0.0.0/g' /etc/mysql/mariadb.conf.d/50-server.cnf
		output 'Restarting MySQL process...'
		service mariadb restart
	elif grep -Fqs "bind-address" /etc/mysql/my.cnf ; then
        	sed -i -- '/bind-address/s/#//g' /etc/mysql/my.cnf
		sed -i -- '/bind-address/s/127.0.0.1/0.0.0.0/g' /etc/mysql/my.cnf
		output 'Restarting MySQL process...'
		service mariadb restart
	elif grep -Fqs "bind-address" /etc/my.cnf ; then
        	sed -i -- '/bind-address/s/#//g' /etc/my.cnf
		sed -i -- '/bind-address/s/127.0.0.1/0.0.0.0/g' /etc/my.cnf
		output 'Restarting MySQL process...'
		service mariadb restart
    	elif grep -Fqs "bind-address" /etc/mysql/my.conf.d/mysqld.cnf ; then
        	sed -i -- '/bind-address/s/#//g' /etc/mysql/my.conf.d/mysqld.cnf
		sed -i -- '/bind-address/s/127.0.0.1/0.0.0.0/g' /etc/mysql/my.conf.d/mysqld.cnf
		output 'Restarting MySQL process...'
		service mariadb restart
    	elif grep -Fqs "bind-address" /etc/my.cnf.d/mariadb-server.cnf ; then
        	sed -i -- '/bind-address/s/#//g' /etc/my.cnf.d/mariadb-server.cnf
		sed -i -- '/bind-address/s/127.0.0.1/0.0.0.0/g' /etc/my.cnf.d/mariadb-server.cnf
		output 'Restarting MySQL process...'
		service mariadb restart
	else
		output 'A MariaDB configuration file could not be detected! Please contact support.'
	fi

    output "Downloading Pterodactyl..."
    mkdir -p /var/www/pterodactyl
    cd /var/www/pterodactyl || exit
    curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/download/${PANEL}/panel.tar.gz
    tar -xzvf panel.tar.gz
    chmod -R 755 storage/* bootstrap/cache/

    output "Installing Pterodactyl..."
    if [ "$lsb_dist" = "fedora" ] || [ "$lsb_dist" = "centos" ] || [ "$lsb_dist" = "rhel" ] || [ "$lsb_dist" = "rocky" ] || [ "$lsb_dist" = "almalinux" ]; then
    	dnf -y install composer
    else 
    	curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer
    fi
 
    cp .env.example .env
    
    if [ "$lsb_dist" = "fedora" ] || [ "$lsb_dist" = "centos" ] || [ "$lsb_dist" = "rhel" ] || [ "$lsb_dist" = "rocky" ] || [ "$lsb_dist" = "almalinux" ]; then
    	composer update --no-interaction
	composer install --no-dev --optimize-autoloader --no-interaction
    else 
    	/usr/local/bin/composer install --no-dev --optimize-autoloader --no-interaction
    fi
    
    php artisan key:generate --force
    php artisan p:environment:setup -n --author=$email --url=https://$FQDN --timezone=America/New_York --cache=redis --session=database --queue=redis --redis-host=127.0.0.1 --redis-pass= --redis-port=6379
    php artisan p:environment:database --host=127.0.0.1 --port=3306 --database=panel --username=pterodactyl --password=$password
    output "To use PHP's internal mail sending, select [mail]. To use a custom SMTP server, select [smtp]. TLS Encryption is recommended."
    php artisan p:environment:mail
    php artisan migrate --seed --force
    php artisan p:user:make --email=$email --admin=1
    if  [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        chown -R www-data:www-data * /var/www/pterodactyl
    elif  [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" = "rocky" ] || [ "$lsb_dist" != "almalinux" ]; then
        chown -R nginx:nginx * /var/www/pterodactyl
	semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/pterodactyl/storage(/.*)?"
        restorecon -R /var/www/pterodactyl
    fi

    output "Creating panel queue listeners..."
    (crontab -l ; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1")| crontab -

    if  [ "$lsb_dist" =  "ubuntu" ] ||  [ "$lsb_dist" =  "debian" ]; then
        cat > /etc/systemd/system/pteroq.service <<- 'EOF'
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service
[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
[Install]
WantedBy=multi-user.target
EOF
    elif  [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" = "rocky" ] || [ "$lsb_dist" != "almalinux" ]; then
        cat > /etc/systemd/system/pteroq.service <<- 'EOF'
Description=Pterodactyl Queue Worker
After=redis-server.service
[Service]
User=nginx
Group=nginx
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
[Install]
WantedBy=multi-user.target
EOF
        setsebool -P httpd_can_network_connect 1
	setsebool -P httpd_execmem 1
	setsebool -P httpd_unified 1
    fi
    sudo systemctl daemon-reload
    systemctl enable --now pteroq.service
}

upgrade_pterodactyl(){
    cd /var/www/pterodactyl || exit
    php artisan down
    curl -L https://github.com/pterodactyl/panel/releases/download/${PANEL}/panel.tar.gz | tar --strip-components=1 -xzv
    chmod -R 755 storage/* bootstrap/cache
    composer install --no-dev --optimize-autoloader
    php artisan view:clear
    php artisan config:clear
    php artisan migrate --force
    php artisan db:seed --force
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        chown -R www-data:www-data * /var/www/pterodactyl
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" = "rocky" ] || [ "$lsb_dist" != "almalinux" ]; then
        chown -R nginx:nginx * /var/www/pterodactyl
        semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/pterodactyl/storage(/.*)?"
        restorecon -R /var/www/pterodactyl
    fi
    output "Your panel has successfully been updated to version ${PANEL}"
    php artisan up
    php artisan queue:restart
}

nginx_config() {
    output "Disabling default configuration..."
    rm -rf /etc/nginx/sites-enabled/default
    output "Configuring Nginx Webserver..."

echo '
server {
    listen 80 default_server;
    server_name '"$FQDN"';
    return 301 https://$server_name$request_uri;
}
server {
    listen 443 ssl http2 default_server;
    server_name '"$FQDN"';
    root /var/www/pterodactyl/public;
    index index.php;
    access_log /var/log/nginx/pterodactyl.app-access.log;
    error_log  /var/log/nginx/pterodactyl.app-error.log error;
    # allow larger file uploads and longer script runtimes
    client_max_body_size 100m;
    client_body_timeout 120s;
    sendfile off;
    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/'"$FQDN"'/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/'"$FQDN"'/privkey.pem;
    ssl_session_cache shared:SSL:10m;
    ssl_protocols TLSv1.2;
    ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256';
    ssl_prefer_server_ciphers on;
    # See https://hstspreload.org/ before uncommenting the line below.
    # add_header Strict-Transport-Security "max-age=15768000; preload;";
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Robots-Tag none;
    add_header Content-Security-Policy "frame-ancestors 'self'";
    add_header X-Frame-Options DENY;
    add_header Referrer-Policy same-origin;
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/var/run/php/php8.0-fpm.sock;
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
' | sudo -E tee /etc/nginx/sites-available/pterodactyl.conf >/dev/null 2>&1
    ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
    service nginx restart
}

nginx_config_redhat(){
    output "Configuring Nginx web server..."

echo '
server {
    listen 80 default_server;
    server_name '"$FQDN"';
    return 301 https://$server_name$request_uri;
}
server {
    listen 443 ssl http2 default_server;
    server_name '"$FQDN"';
    root /var/www/pterodactyl/public;
    index index.php;
    access_log /var/log/nginx/pterodactyl.app-access.log;
    error_log  /var/log/nginx/pterodactyl.app-error.log error;
    # allow larger file uploads and longer script runtimes
    client_max_body_size 100m;
    client_body_timeout 120s;

    sendfile off;
    # strengthen ssl security
    ssl_certificate /etc/letsencrypt/live/'"$FQDN"'/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/'"$FQDN"'/privkey.pem;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_ciphers "EECDH+AESGCM:EDH+AESGCM:ECDHE-RSA-AES128-GCM-SHA256:AES256+EECDH:DHE-RSA-AES128-GCM-SHA256:AES256+EDH:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA:ECDHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES256-GCM-SHA384:AES128-GCM-SHA256:AES256-SHA256:AES128-SHA256:AES256-SHA:AES128-SHA:DES-CBC3-SHA:HIGH:!aNULL:!eNULL:!EXPORT:!DES:!MD5:!PSK:!RC4";

    # See the link below for more SSL information:
    #     https://raymii.org/s/tutorials/Strong_SSL_Security_On_nginx.html
    #
    # ssl_dhparam /etc/ssl/certs/dhparam.pem;
    # Add headers to serve security related headers
    add_header Strict-Transport-Security "max-age=15768000; preload;";
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Robots-Tag none;
    add_header Content-Security-Policy "frame-ancestors 'self'";
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/var/run/php-fpm/pterodactyl.sock;
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
' | sudo -E tee /etc/nginx/conf.d/pterodactyl.conf >/dev/null 2>&1

    service nginx restart
    chown -R nginx:nginx $(pwd)
    semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/pterodactyl/storage(/.*)?"
    restorecon -R /var/www/pterodactyl
}

php_config(){
    output "Configuring PHP socket..."
    bash -c 'cat > /etc/php-fpm.d/www-pterodactyl.conf' <<-'EOF'
[pterodactyl]
user = nginx
group = nginx
listen = /var/run/php-fpm/pterodactyl.sock
listen.owner = nginx
listen.group = nginx
listen.mode = 0750
pm = ondemand
pm.max_children = 9
pm.process_idle_timeout = 10s
pm.max_requests = 200
EOF
    systemctl restart php-fpm
}

webserver_config(){
    if [ "$lsb_dist" =  "debian" ] || [ "$lsb_dist" =  "ubuntu" ]; then
        nginx_config
    elif  [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" =  "rocky" ] || [ "$lsb_dist" != "almalinux" ]; then
        php_config
        nginx_config_redhat
	chown -R nginx:nginx /var/lib/php/session
    fi
}

setup_pterodactyl(){
    install_dependencies
    install_pterodactyl
    ssl_certs
    webserver_config
}


install_wings() {
    cd /root || exit
    output "Installing Pterodactyl Wings dependencies..."
    if  [ "$lsb_dist" =  "ubuntu" ] ||  [ "$lsb_dist" =  "debian" ]; then
        apt-get -y install curl tar unzip
    elif  [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" =  "rocky" ] || [ "$lsb_dist" != "almalinux" ]; then
        dnf -y install curl tar unzip
    fi

    output "Installing Docker"
    if  [ "$lsb_dist" != "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" =  "rocky" ] || [ "$lsb_dist" != "almalinux" ]; then
        dnf -y install podman-docker
        systemctl enable --now podman.socket
    else
        curl -sSL https://get.docker.com/ | CHANNEL=stable bash
	systemctl enable --now docker
    fi

    output "Enabling SWAP support for Docker."
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& swapaccount=1/' /etc/default/grub
    output "Installing the Pterodactyl wings..."
    mkdir -p /etc/pterodactyl /srv/daemon-data
    cd /etc/pterodactyl || exit
    curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/download/${WINGS}/wings_linux_amd64
    chmod u+x /usr/local/bin/wings
    bash -c 'cat > /etc/systemd/system/wings.service' <<-'EOF'
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=600

[Install]
WantedBy=multi-user.target
EOF

    systemctl enable --now wings
    output "Wings ${WINGS} has now been installed on your system."
}


upgrade_wings(){
    curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
    chmod u+x /usr/local/bin/wings
    systemctl restart wings
    output "Your wings have been updated to version ${WINGS}."
}

install_phpmyadmin(){
    output "Installing phpMyAdmin..."
    cd /var/www/pterodactyl/public || exit
    rm -rf phpmyadmin
    wget https://files.phpmyadmin.net/phpMyAdmin/${PHPMYADMIN}/phpMyAdmin-${PHPMYADMIN}-all-languages.zip
    unzip phpMyAdmin-${PHPMYADMIN}-all-languages.zip
    mv phpMyAdmin-${PHPMYADMIN}-all-languages phpmyadmin
    rm -rf phpMyAdmin-${PHPMYADMIN}-all-languages.zip
    cd /var/www/pterodactyl/public/phpmyadmin || exit

    SERVER_IP=$(dig +short myip.opendns.com @resolver1.opendns.com)
    BOWFISH=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 34 | head -n 1`
    bash -c 'cat > /var/www/pterodactyl/public/phpmyadmin/config.inc.php' <<EOF
<?php
/* Servers configuration */
\$i = 0;
/* Server: MariaDB [1] */
\$i++;
\$cfg['Servers'][\$i]['verbose'] = 'MariaDB';
\$cfg['Servers'][\$i]['host'] = '${SERVER_IP}';
\$cfg['Servers'][\$i]['port'] = '';
\$cfg['Servers'][\$i]['socket'] = '';
\$cfg['Servers'][\$i]['auth_type'] = 'cookie';
\$cfg['Servers'][\$i]['user'] = 'root';
\$cfg['Servers'][\$i]['password'] = '';
/* End of servers configuration */
\$cfg['blowfish_secret'] = '${BOWFISH}';
\$cfg['DefaultLang'] = 'en';
\$cfg['ServerDefault'] = 1;
\$cfg['UploadDir'] = '';
\$cfg['SaveDir'] = '';
\$cfg['CaptchaLoginPublicKey'] = '6LcJcjwUAAAAAO_Xqjrtj9wWufUpYRnK6BW8lnfn';
\$cfg['CaptchaLoginPrivateKey'] = '6LcJcjwUAAAAALOcDJqAEYKTDhwELCkzUkNDQ0J5'
?>    
EOF
    output "Installation completed."
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        chown -R www-data:www-data * /var/www/pterodactyl
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" =  "rocky" ] || [ "$lsb_dist" != "almalinux" ]; then
        chown -R nginx:nginx * /var/www/pterodactyl
        semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/pterodactyl/storage(/.*)?"
        restorecon -R /var/www/pterodactyl
    fi
}

ssl_certs(){
    output "Installing Let's Encrypt and creating an SSL certificate..."
    cd /root || exit
    if  [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        apt-get -y install certbot
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" =  "rocky" ] || [ "$lsb_dist" != "almalinux" ]; then
        dnf -y install certbot
    fi
    service nginx stop
    certbot certonly --standalone --email "$email" --agree-tos -d "$FQDN" --non-interactive
    
    if [ "$installoption" = "2" ]; then
        if  [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
            ufw deny 80
        elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]|| [ "$lsb_dist" =  "rocky" ] || [ "$lsb_dist" != "almalinux" ]; then
            firewall-cmd --permanent --remove-port=80/tcp
            firewall-cmd --reload
        fi
    else
        service nginx restart
    fi
}

firewall(){
    output "Setting up Fail2Ban..."
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        apt -y install fail2ban
    elif [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" =  "rocky" ] || [ "$lsb_dist" != "almalinux" ]; then
        dnf -y install fail2ban
    fi 
    systemctl enable fail2ban
    bash -c 'cat > /etc/fail2ban/jail.local' <<-'EOF'
[DEFAULT]
# Ban hosts for ten hours:
bantime = 36000
# Override /etc/fail2ban/jail.d/00-firewalld.conf:
banaction = iptables-multiport
[sshd]
enabled = true
EOF
    service fail2ban restart

    output "Configuring your firewall..."
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        apt-get -y install ufw
        ufw allow 22
        if [ "$installoption" = "1" ]; then
            ufw allow 80
            ufw allow 443
            ufw allow 3306
        elif [ "$installoption" = "2" ]; then
            ufw allow 80
            ufw allow 8080
            ufw allow 2022
        elif [ "$installoption" = "3" ]; then
            ufw allow 80
            ufw allow 443
            ufw allow 8080
            ufw allow 2022
            ufw allow 3306
        fi
        yes | ufw enable 
    elif [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" =  "rocky" ] || [ "$lsb_dist" != "almalinux" ]; then
        dnf -y install firewalld
        systemctl enable firewalld
        systemctl start firewalld
        if [ "$installoption" = "1" ]; then
            firewall-cmd --add-service=http --permanent
            firewall-cmd --add-service=https --permanent 
            firewall-cmd --add-service=mysql --permanent
        elif [ "$installoption" = "2" ]; then
            firewall-cmd --permanent --add-service=80/tcp
            firewall-cmd --permanent --add-port=2022/tcp
            firewall-cmd --permanent --add-port=8080/tcp

        elif [ "$installoption" = "3" ]; then
            firewall-cmd --add-service=http --permanent
            firewall-cmd --add-service=https --permanent 
            firewall-cmd --permanent --add-port=2022/tcp
            firewall-cmd --permanent --add-port=8080/tcp
            firewall-cmd --permanent --add-service=mysql
        fi
    fi
}

database_host_reset(){
    SERVER_IP=$(curl -s http://checkip.amazonaws.com)
    adminpassword=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    Q0="SET old_passwords=0;"
    Q1="SET PASSWORD FOR 'admin'@'$SERVER_IP' = PASSWORD('$adminpassword');"
    Q2="FLUSH PRIVILEGES;"
    SQL="${Q0}${Q1}${Q2}"
    mysql mysql -e "$SQL"
    output "New database host information:"
    output "Host: $SERVER_IP"
    output "Port: 3306"
    output "User: admin"
    output "Password: $adminpassword"
}

broadcast(){
    if [ "$installoption" = "1" ] || [ "$installoption" = "3" ]; then
        broadcast_database
    fi
    output "###############################################################"
    output "FIREWALL INFORMATION"
    output ""
    output "All unnecessary ports are blocked by default."
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        output "Use 'ufw allow <port>' to enable your desired ports."
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" =  "rocky" ] || [ "$lsb_dist" != "almalinux" ]; then
        output "Use 'firewall-cmd --permanent --add-port=<port>/tcp' to enable your desired ports."
    fi
    output "###############################################################"
    output ""
}

broadcast_database(){
    output "###############################################################"
    output "MARIADB/MySQL INFORMATION"
    output ""
    output "Your MariaDB/MySQL root password is $rootpassword"
    output ""
    output "Create your MariaDB/MySQL host with the following information:"
    output "Host: $SERVER_IP"
    output "Port: 3306"
    output "User: admin"
    output "Password: $adminpassword"
    output "###############################################################"
    output ""
}

#Execution
preflight
install_options
case $installoption in 
    1)  repositories_setup
        required_infos
        firewall
        setup_pterodactyl
        broadcast
	broadcast_database
        ;;
    2)  repositories_setup
        required_infos
        firewall
        ssl_certs
        install_wings
        broadcast
	broadcast_database
        ;;
    3)  repositories_setup
        required_infos
        firewall
        ssl_certs
        setup_pterodactyl
        install_wings
        broadcast
        ;;
    4)  upgrade_pterodactyl
        ;;
    5)  upgrade_wings
        ;;
    6)  upgrade_pterodactyl
	upgrade_wings
	;;
    7)  install_phpmyadmin
        ;;
    8)  curl -sSL https://raw.githubusercontent.com/tommytran732/MariaDB-Root-Password-Reset/master/mariadb-104.sh | sudo bash
        ;;
    9)  database_host_reset
        ;;
esac
