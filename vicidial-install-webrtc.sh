#!/bin/bash

echo "Download Viciphone"
cd /tmp
git clone https://github.com/manish23k/ViciPhone.git
cd Viciphone
cp -r src /var/www/html/agc/viciphone
chmod -R 755 /var/www/html/agc/viciphone

echo "Install certbot for LetsEncrypt"

	#sudo add-apt-repository ppa:certbot/certbot
	sudo apt install python-certbot-apache


echo "Enter the DOMAIN NAME HERE. ***********IF YOU DONT HAVE ONE PLEASE DONT CONTINUE: "
read DOMAINNAME

echo "Please Enter EMAIL and Agree the Terms and Conditions "
certbot --apache -d $DOMAINNAME

echo "Change http.conf in Asterisk"
wget -O /etc/asterisk/http.conf https://raw.githubusercontent.com/jaganthoutam/vicidial-install-scripts/main/asterisk-http.conf
sed -i s/DOMAINNAME/"$DOMAINNAME"/g /etc/asterisk/http.conf

echo "Change sip.conf in Asterisk"
#wget -O /etc/asterisk/sip.conf https://raw.githubusercontent.com/jaganthoutam/vicidial-install-scripts/main/asterisk-sip.conf
sed -i s/DOMAINNAME/"$DOMAINNAME"/g /etc/asterisk/sip.conf

echo "Reloading Asterisk"
rasterisk -x reload

echo "Add DOMAINAME servers web_socket_url"
echo "%%%%%%%%%%%%%%%This Wont work if you SET root Password%%%%%%%%%%%%%%%"
mysql -e "use asterisk; update servers set web_socket_url='wss://$DOMAINNAME:8089/ws';"

echo "Add DOMAINAME system_settings webphone_url"
echo "%%%%%%%%%%%%%%%This Wont work if you SET root Password%%%%%%%%%%%%%%%"
mysql -e "use asterisk; update system_settings set webphone_url='https://$DOMAINNAM/agc/viciphone/viciphone.php';"

echo "Create WEBRTC_TEMP"
mysql -e "use asterisk; INSERT INTO `vicidial_conf_templates` VALUES ('WEBRTC_TEMP','WEBRTC_TEMP','type=friend\r\nhost=dynamic\r\ncontext=default\r\nencryption=yes\r\navpf=yes\r\nicesupport=yes\r\ndirectmedia=no\r\ntransport=wss\r\nforce_avp=yes\r\ndtlsenable=yes\r\ndtlsverify=no\r\ndtlscertfile=/etc/letsencrypt/live/$DOMAINNAME/fullchain.pem\r\ndtlsprivatekey=/etc/letsencrypt/live/$DOMAINNAME/privkey.pem\r\ndtlssetup=actpass\r\nrtcp_mux=yes','---ALL---');


echo "update the Phone tables to set is_webphone to Y deffault"
mysql -e "use asterisk; ALTER TABLE phones MODIFY COLUMN is_webphone ENUM('Y','N','Y_API_LAUNCH') default 'Y';"
mysql -e "use asterisk; update phones set template_id='WEBRTC_TEMP';"

