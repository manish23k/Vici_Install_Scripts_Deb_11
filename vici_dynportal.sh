#!/bin/bash

# Function to display error and exit
function display_error {
    echo "Error: $1"
    exit 1
}

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
   display_error "This script must be run as root"
fi

# Get domain name input
read -p "Enter your domain name (e.g., example.com): " domain_name

# Install required packages
apt update || display_error "Failed to update package list"
apt install -y firewalld ipset unzip || display_error "Failed to install required packages"

# Download and extract Dynamic Portal files
mkdir -p /usr/src/dynamicportal
cd /usr/src/dynamicportal || display_error "Failed to change directory to /usr/src/dynamicportal"
wget https://github.com/manish23k/vicidial-dynamicportal/archive/refs/heads/main.zip || display_error "Failed to download Dynamic Portal files"
unzip main.zip || display_error "Failed to extract Dynamic Portal files"
cd vicidial-dynamicportal-main || display_error "Failed to change directory to vicidial-dynamicportal-main"

# Copy Firewall zones, services, ipset rules
cp -r zones /etc/firewalld/
cp -r ipsets /etc/firewalld/
cp services/*.xml /usr/lib/firewalld/services/

# Copy Dynamic Portal files to web folder
cp -r dynamicportal /var/www/html/dynportal

# Copy ssl file to http config folder
cp vicidial-ssl.conf /etc/apache2/sites-available

# Edit vicidial-ssl.conf with SSL certificate and key
#sed -i "s#/etc/letsencrypt/live/$domain_name/fullchain.pem#" /etc/apache2/sites-available/vicidial-ssl.conf
sed -i "s#/etc/letsencrypt/live/$domain_name/privkey.pem#" /etc/apache2/sites-available/vicidial-ssl.conf

# Add listen ports in Apache configuration
echo "Listen 81" >> /etc/apache2/ports.conf
echo "Listen 446" >> /etc/apache2/ports.conf

# Copy VB-firewall script to bin and set permissions
cp VB-firewall /usr/bin/
chmod +x /usr/bin/VB-firewall

# Restart Firewalld
systemctl enable firewalld
systemctl restart firewalld || display_error "Failed to restart Firewalld"

# Add cronjob entry to run VB-firewall every minute
(crontab -l 2>/dev/null; echo "* * * * * /usr/bin/VB-firewall --white --dynamic --quiet") | crontab -
(crontab -l 2>/dev/null; echo "@reboot /usr/bin/VB-firewall --white --dynamic --quiet") | crontab -

echo "Vicidial Dynamic Portal setup completed successfully."
echo "Make sure to configure Vicidial settings and IP lists manually through the Admin portal."
