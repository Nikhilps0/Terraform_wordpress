#!/bin/bash
yum install mariadb-server -y
systemctl start mariadb.service
systemctl enable mariadb.service
mysql -e "UPDATE mysql.user SET Password=PASSWORD('55zK4THjpdHzcMdU') WHERE User='root';"
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'"
mysql -e "FLUSH PRIVILEGES;"
mysql -u root -p'55zK4THjpdHzcMdU' -e "create database ${DATABASE_NAME};"
mysql -u root -p'55zK4THjpdHzcMdU' -e "create user '${DATABASE_USER}'@'localhost' identified by '${DATABASE_PASSWORD}';"
mysql -u root -p'55zK4THjpdHzcMdU' -e "grant all privileges on ${DATABASE_NAME}.* to '${DATABASE_USER}'@'localhost';"
mysql -u root -p'55zK4THjpdHzcMdU' -e "flush privileges;"
systemctl restart mariadb.service

echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config
echo "LANG=en_US.utf-8" >> /etc/environment
echo "LC_ALL=en_US.utf-8" >> /etc/environment
service sshd restart

yum install httpd -y
yum install mod_ssl -y
systemctl restart httpd.service
yum install -y amazon-linux-extras
amazon-linux-extras enable php7.4
yum clean metadata
sudo yum install -y php php-{pear,cgi,common,curl,mbstring,gd,mysqlnd,gettext,bcmath,json,xml,fpm,intl,zip,imap}

wget https://wordpress.org/latest.tar.gz -P /var/website/


tar -xf /var/website/latest.tar.gz -C /var/website/
cp -r /var/website/wordpress/* /var/www/html/

sed -i 's/database_name_here/${DATABASE_NAME}/g' /var/www/html/wp-config-sample.php
sed -i 's/username_here/${DATABASE_USER}/g' /var/www/html/wp-config-sample.php
sed -i 's/password_here/${DATABASE_PASSWORD}/g' /var/www/html/wp-config-sample.php
sed -i 's/localhost/localhost/g' /var/www/html/wp-config-sample.php


echo "SetEnvIf x-forwarded-proto https HTTPS=on" >> /etc/httpd/conf/httpd.conf

sed -i 's/post_max_size = 8M/post_max_size = 128M/g'  /etc/php.ini
sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 128M/g'  /etc/php.ini
mv /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
chown -R apache:apache /var/www/html/*
systemctl restart httpd.service
systemctl enable httpd.service