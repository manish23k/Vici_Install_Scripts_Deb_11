vicidial-dynamic portal Debian 11
https://manishkadiya.blogspot.com/2024/04/debian-11-vicidial-scratch-install.html

cd firewalld_201
cp -r zones /etc/firewalld/
cp -r ipsets /etc/firewalld/
cd ..
cp services/ /usr/lib/firewalld/

# Copy Dynamic Portal files to web folder
cp -r dynportal_201 /var/www/html/dynportal

cp vicidial-ssl.conf /etc/apache2/sites-available/

cp vicidial.conf /etc/apache2/sites-available

cd /servcies

cp *.xml /usr/lib/firewalld/services/

cp -r dynamicportal /var/www/html/

cd usr_share_vicibox-firewall_201
cp VB-firewall.pl /usr/bin/
chmod +x /usr/bin/VB-firewall.pl
