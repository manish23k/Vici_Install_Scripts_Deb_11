vicidial-dynamic portal Debian 11
https://manishkadiya.blogspot.com/2024/04/debian-11-vicidial-scratch-install.html

cp VB-firewall /usr/bin/

chmod +x /usr/bin/VB-firewall

cp -r zones /etc/firewalld/

cp vicidial-ssl.conf /etc/apache2/sites-available/

cp vicidial.conf /etc/apache2/sites-available

cd /servcies

cp *.xml /usr/lib/firewalld/services/

cp -r dynamicportal /var/www/html/
