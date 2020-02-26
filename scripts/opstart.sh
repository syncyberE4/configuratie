#!/bin/bash
sudo apt-get update -y
sudo apt-get upgrade -y

#installeren van benodigdheden voor ASP .net
sudo apt-get -y install libunwind8 gettext
sudo apt-get -y install apt-transport-https

wget https://download.visualstudio.microsoft.com/download/pr/60780f73-a484-43fe-a6b9-c9042e3d2281/83d8c620270147af223bbd9f9d287b9a/aspnetcore-runtime-3.0.2-linux-x64.tar.gz
mkdir /opt/dotnet
gunzip aspnetcore-runtime-3.0.2-linux-x64.tar.gz
tar -xvf aspnetcore-runtime-3.0.2-linux-x64.tar -C /opt/dotnet/
ln -s /opt/dotnet/dotnet /usr/local/bin
dotnet --info

#ftpd installeren
sudo apt install pure-ftpd -y

#apache2 installeren
sudo apt-get install apache2

#installatie van de mysql-serverl
sudo apt-get install mysql-server
sudo mysql_secure_installation 

#Create login in mysql for the administrator. 
sudo mysql -uroot -p <<MYSQL_SCRIPT
FLUSH PRIVILEGES;
CREATE DATABASE syncyber;
CREATE USER 'administrator'@'localhost' IDENTIFIED BY 'R1234-56'; 
GRANT ALL PRIVILEGES ON *.* TO 'administrator'@'localhost' WITH GRANT OPTION;

CREATE USER 'applicatie'@'localhost' IDENTIFIED BY 'applicatie'; 
GRANT ALL PRIVILEGES ON *.* TO 'applicatie'@'localhost' WITH GRANT OPTION;

CREATE USER 'microcontroller'@'localhost' IDENTIFIED BY '071RMphIJmkFUR21#';
GRANT ALL PRIVILEGES ON *.* TO 'microcontroller'@'localhost' WITH GRANT OPTION;

CREATE USER 'gregory'@'%' IDENTIFIED BY 'badmuts'; 
GRANT ALL PRIVILEGES ON *.* TO 'gregory'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
MYSQL_SCRIPT

sudo apt-get install php libapache2-mod-php -y

#Give rights to apache www folder 
sudo mkdir /var/www/ 
sudo chmod -R 777 /var/www/


#installatie van PHPMyAdmin
sudo apt install phpmyadmin php-mbstring php-gettext -y

#de phpMyAdmin module aanzetten
sudo phpenmod mbstring

#herstart de apache2 server
sudo systemctl restart apache2
sudo a2enmod rewrite -y
sudo systemctl restart apache2

#mappen aanmaken
sudo mkdir /home/administrator/backup
sudo chmod -R 777 /home/administrator/backup

#create mount point for usb
sudo mkdir /media/backup
sudo chown -R administrator:administrator /media/backup


#add a virtual host to apache2
sudo bash -c 'echo -e "<VirtualHost *:80> \n\n DocumentRoot /var/www/Front_end \n ErrorLog ${APACHE_LOG_DIR}/error.log \n CustomLog ${APACHE_LOG_DIR}/access.log combined \n\n <Directory /var/www/Front_end> \n RewriteEngine on \n\n RewriteCond %{REQUEST_FILENAME} -f [OR] \n RewriteCond %{REQUEST_FILENAME} -d \n RewriteRule ^ - [L] \n\n RewriteRule ^ index.html [L] \n </Directory> \n\n </VirtualHost>\n\n<VirtualHost *:8050> \n\n DocumentRoot /var/www/dashboard \n ErrorLog /error.log\n CustomLog /access.log combined\n\n</VirtualHost>\n\n<VirtualHost *:8051>\n DocumentRoot /var/www/archief\n ErrorLog /error.log\n CustomLog /access.log combined\n</VirtualHost>"' > /etc/apache2/sites-available/syncyber.com.conf

sudo a2dissite 000-default.conf
sudo rm /etc/apache2/sites-available/000-default.conf

sudo a2ensite syncyber.com.conf
sudo a2enmod rewrite
sudo service apache2 restart

#configuratie automysqlbackup
sudo aptitude install automysqlbackup autopostgresqlbackup -y
mkdir /opt/automysqlbackup
cd /opt/automysqlbackup/
mkdir /var/backup/
chmod 777 /var/backup
wget http://ufpr.dl.sourceforge.net/project/automysqlbackup/AutoMySQLBackup/AutoMySQLBackup%20VER%203.0/automysqlbackup-v3.0_rc6.tar.gz
tar zxf automysqlbackup-v3.0_rc6.tar.gz
sudo ./install.sh
cd /etc/automysqlbackup/
#nano myserver.conf aanpassen van de instellingen aan de database

#schrijven en aanmaken van backupscript
sudo bash -c 'echo -e "#!/bin/bash\nbackup_files=\"/home /var /etc \"\ndest=\"/media/backup\"\nday=\$(date+%A)\nhostname=\$(hostname -s)\narchive_file=\"\$hostname-\$day.tgz\"\necho \"Backing up \$backup_files to \$dest/\$archive_file \"\ntar czf \$dest/\$archive_file \$backup_files \n echo \"backup finished\"\nls -lh \$dest"' > /home/administrator/backup/backup.sh


#crontabfile instellen
sudo bash -c 'echo -e "22 11	* * *	root	/home/administrator/backup/backup.sh\n39 10	* * *	root	/usr/local/bin/automysqlbackup /etc/automysqlbackup/myserver.conf"' > /etc/crontab
#sudo bash -c 'echo -e "39 10	* * *	root	/usr/local/bin/automysqlbackup /etc/automysqlbackup/myserver.conf"' > /etc/crontab

alias backup='sudo /home/administrator/backup/backup.sh'
sudo chmod u+x /home/administrator/backup/backup.sh

#firewallrules instellen
sudo apt-get install ufw

sudo ufw disable

sudo ufw default deny incoming
sudo ufw default deny outgoing

sudo ufw allow 22/tcp
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow 8050
sudo ufw allow 5000:5001/tcp
sudo ufw allow 5000:5001/udp
sudo ufw allow 3306/udp
sudo ufw allow 3306/tcp

sudo ufw allow out 8050
sudo ufw allow out 80
sudo ufw allow out 443
sudo ufw allow out 3306

#crontab -e instellen
crontab -l | { cat; echo "47 10 * * * /usr/local/bin/automysqlbackup /etc/automysqlbackup/myserver.conf"; } | crontab -
crontab -l | { cat; echo "22 11 * * * /home/administrator/backup/backup.sh"; } | crontab -

sudo rm -r /etc/apache2/ports.conf
sudo touch /etc/apache2/ports.conf

#ports apache instellen
sudo bash -c 'echo -e "<ifModule ssl_module>\n	Listen 443\n</ifModule>\n<ifModule mod_gnutls.c>\n	Listen 443\n</ifModule>\n\nListen 8050\nListen 80\nListen 8051"' >> /etc/apache2/ports.conf

#de nodige files verwijderen
sudo rm /etc/automysqlbackup/myserver.conf
sudo rm /etc/mysql/mysql.conf.d/mysqld.cnf

#mappen aanmaken + rechten geven
sudo rm -r /var/www/dashboard
sudo rm -r /var/www/archief
sudo rm -r /var/www/Front_end

sudo mkdir /var/www/dashboard
sudo chmod 777 /var/www/dashboard

sudo mkdir /var/www/archief
sudo chmod 777 /var/www/archief


#de juiste bestanden op de juiste plaats zetten
cd /etc/automysqlbackup
wget https://raw.githubusercontent.com/LambrechtsLouis/syncyberTest/master/etc/automysqlbackup/myserver.conf

cd /etc/mysql/mysql.conf.d
wget https://raw.githubusercontent.com/LambrechtsLouis/syncyberTest/master/etc/mySQL/mysql/mysqld.cnf

cd /home/administrator
git init

git clone https://github.com/syncyberE4/Applicatie.git

mkdir publish
chmod 777 publish
mv Applicatie/publish/* publish
chmod 777 /home/administrator/publish/*
rm -r /home/administrator/Applicatie

cd /var/www
git init

#clonen van dashboard en archief applicatie
git clone https://github.com/syncyberE4/html.git

cd /home/administrator

#verplaatsen van dashboard applicatie
mv /var/www/html/live-overzicht/* /var/www/dashboard/

cd /home/administrator

#verplaatsen van archief
mv /var/www/html/archief-overzicht/* /var/www/archief

#verwijderen dubbele bestanden
rm -r /var/www/html

cd /var/www

#clonen van frontend
git clone https://github.com/syncyberE4/Front_end.git

chmod 777 /var/www/Front_end

#rechten geven op alle mappen in de www directory
cd /var/www/
chmod 777 ./*

#rechten geven op de juiste mappen
sudo chmod 777 /var/www/archief/api
sudo chmod 777 /var/www/archief/fonts
sudo chmod 777 /var/www/archief/index.html
sudo chmod 777 /var/www/archief/js
sudo chmod 777 /var/www/archief/sass

sudo chmod 777 /var/www/dashboard/api
sudo chmod 777 /var/www/dashboard/fonts
sudo chmod 777 /var/www/dashboard/index.html
sudo chmod 777 /var/www/dashboard/js
sudo chmod 777 /var/www/dashboard/sass

#na het schrijven apache herstarten
sudo service apache2 restart

#uitgaande icmp pakketten toestaan
sudo bash -c 'echo -e "-A ufw-before-output -p icmp -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT\n-A ufw-before-output -p icmp -m state --state ESTABLISHED,RELATED -j ACCEPT"' >> /etc/ufw/before.rules

sudo ufw enable

