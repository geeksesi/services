#!/bin/bash

DOMAIN=$1
PORT=$2

# Create Nginx config
cat > /home/geeksesi/public_html/services/$DOMAIN.conf <<EOL
server{
    listen 80;
    server_name $DOMAIN;

    location / {
        return 301 https://\$host\$request_uri;
    }
}
server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /home/geeksesi/public_html/services/$DOMAIN/$DOMAIN.crt;
    ssl_certificate_key /home/geeksesi/public_html/services/$DOMAIN/$DOMAIN.key;

    location / {
        proxy_pass http://localhost:$PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOL

# Enable site
ln -s /home/geeksesi/public_html/services/$DOMAIN.conf /etc/nginx/sites-enabled/$DOMAIN.conf

# Update /etc/hosts
echo "127.0.0.1 $DOMAIN" >> /etc/hosts

# Restart Nginx
systemctl restart nginx
