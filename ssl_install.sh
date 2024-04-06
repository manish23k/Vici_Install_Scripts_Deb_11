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

# Install Certbot (Let's Encrypt client) and Apache plugin
apt update || display_error "Failed to update package list"
apt install -y certbot python3-certbot-apache || display_error "Failed to install Certbot and Apache plugin"

# Request SSL certificate using Certbot
certbot --apache -d "$domain_name" || display_error "Failed to request SSL certificate"

# Verify SSL certificate renewal
certbot renew --dry-run || display_error "Failed to verify SSL certificate renewal"

echo "Let's Encrypt SSL certificate installation completed successfully for domain: $domain_name"
