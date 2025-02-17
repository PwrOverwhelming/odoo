#!/bin/bash

################################################################################
# Odoo 18 Installation Script for Ubuntu 24.04 (with virtualenv support)
# Author: Henry Robert Muwanika
#-------------------------------------------------------------------------------
# This script will install Odoo on your Ubuntu server using a virtual environment.
# It can install multiple Odoo instances in one Ubuntu server by using different
# virtual environments and ports.
#-------------------------------------------------------------------------------
# Usage:
# ./install_odoo_ubuntu.sh <OE_VERSION> <OE_PORT> <VENV_NAME>
# Example for Odoo 17:
# ./install_odoo_ubuntu.sh 17.0 8069 odoo17_env
# Example for Odoo 18:
# ./install_odoo_ubuntu.sh 18.0 8070 odoo18_env
################################################################################

# Check if the correct number of arguments is provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <OE_VERSION> <OE_PORT> <VENV_NAME>"
    echo "Example: $0 17.0 8069 odoo17_env"
    exit 1
fi

OE_VERSION=$1
OE_PORT=$2
VENV_NAME=$3

OE_USER="odoo"
OE_HOME="/opt/$OE_USER"
OE_HOME_EXT="/opt/$OE_USER/${OE_USER}-server-$OE_VERSION"
VENV_PATH="/opt/$OE_USER/$VENV_NAME"

# Other configurations
INSTALL_WKHTMLTOPDF="True"
IS_ENTERPRISE="False"
INSTALL_POSTGRESQL_SIXTEEN="True"
INSTALL_NGINX="True"
OE_SUPERADMIN="admin"
GENERATE_RANDOM_PASSWORD="True"
OE_CONFIG="${OE_USER}-server-$OE_VERSION"
WEBSITE_NAME="example.com"
LONGPOLLING_PORT="8072"
ENABLE_SSL="True"
ADMIN_EMAIL="odoo@example.com"

#--------------------------------------------------
# Update and upgrade the system
#--------------------------------------------------
echo -e "=== Updating system packages ... ==="
sudo apt update 
sudo apt upgrade -y
sudo apt autoremove -y

#----------------------------------------------------
# Disabling password authentication
#----------------------------------------------------
echo "=== Disabling password authentication ... ==="
sudo apt -y install openssh-server
sudo sed -i 's/#ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config 
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart sshd

#--------------------------------------------------
# Setting up the timezones
#--------------------------------------------------
timedatectl set-timezone Africa/Kigali
timedatectl

#--------------------------------------------------
# Installing PostgreSQL Server
#--------------------------------------------------
echo -e "=== Install and configure PostgreSQL ... ==="
if [ $INSTALL_POSTGRESQL_SIXTEEN = "True" ]; then
    echo -e "=== Installing postgreSQL V16 ... ==="
    sudo apt -y install postgresql-16
else
    echo -e "=== Installing the default postgreSQL version ... ==="
    sudo apt -y install postgresql postgresql-server-dev-all
fi

echo "=== Starting PostgreSQL service... ==="
sudo systemctl start postgresql 
sudo systemctl enable postgresql

echo -e "=== Creating the Odoo PostgreSQL User ... ==="
sudo su - postgres -c "createuser -s $OE_USER" 2> /dev/null || true

#--------------------------------------------------
# Installing required packages
#--------------------------------------------------
echo "=== Installing required packages... ==="
sudo apt install -y git wget python3-minimal python3-dev python3-pip python3-wheel libxml2-dev libxslt1-dev zlib1g-dev libsasl2-dev libldap2-dev build-essential \
libssl-dev libffi-dev libmysqlclient-dev libjpeg-dev libpq-dev libjpeg8-dev liblcms2-dev libblas-dev libatlas-base-dev libzip-dev python3-setuptools node-less \
python3-venv python3-cffi gdebi zlib1g-dev curl cython3 python3-openssl

sudo pip3 install --upgrade pip --break-system-packages
sudo pip3 install setuptools wheel --break-system-packages

# Installing xfonts dependencies for wkhtmltopdf
echo "=== Installing xfonts for wkhtmltopdf... ==="
sudo apt -y install xfonts-75dpi xfonts-encodings xfonts-utils xfonts-base fontconfig

# Install Node.js and npm
echo "=== Installing Node.js and npm ... ==="
sudo apt -y install nodejs npm

sudo ln -s /usr/bin/nodejs /usr/bin/node
sudo npm install -g less less-plugin-clean-css

# Install rtlcss for RTL support
echo "=== Installing rtlcss ... ==="
sudo npm install -g rtlcss

#--------------------------------------------------
# Install Wkhtmltopdf if needed
#--------------------------------------------------
if [ $INSTALL_WKHTMLTOPDF = "True" ]; then
  echo "=== Install wkhtmltopdf ... ==="
  sudo wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.jammy_amd64.deb 
  sudo apt install ./wkhtmltox_0.12.6.1-2.jammy_amd64.deb
  sudo cp /usr/local/bin/wkhtmltoimage /usr/bin/wkhtmltoimage
  sudo cp /usr/local/bin/wkhtmltopdf /usr/bin/wkhtmltopdf
else
  echo "Wkhtmltopdf isn't installed due to the choice of the user!"
fi

# Create Odoo system user
echo "=== Create Odoo system user ==="
sudo adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'Odoo' --group $OE_USER
sudo adduser $OE_USER sudo

echo -e "=== Create Log directory ... ==="
sudo mkdir /var/log/$OE_USER
sudo chown -R $OE_USER:$OE_USER /var/log/$OE_USER

#--------------------------------------------------
# Create and activate virtual environment
#--------------------------------------------------
echo "=== Creating virtual environment ... ==="
sudo -u $OE_USER python3 -m venv $VENV_PATH
source $VENV_PATH/bin/activate

#--------------------------------------------------
# Install Odoo from source
#--------------------------------------------------
echo "=== Cloning Odoo $OE_VERSION from GitHub ... ==="
sudo -u $OE_USER git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/odoo $OE_HOME_EXT/
pip install -r $OE_HOME_EXT/requirements.txt

if [ $IS_ENTERPRISE = "True" ]; then
    # Odoo Enterprise install!
    pip install psycopg2-binary pdfminer.six
    sudo ln -s /usr/bin/nodejs /usr/bin/node

    GITHUB_RESPONSE=$(sudo -u $OE_USER git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME/enterprise/addons" 2>&1)
    while [[ $GITHUB_RESPONSE == *"Authentication"* ]]; do
        echo "============== WARNING ====================="
        echo "Your authentication with Github has failed! Please try again."
        printf "In order to clone and install the Odoo enterprise version you \n need to be an offical Odoo partner and you need access to \n http://github.com/odoo/enterprise.\n"
        echo "TIP: Press ctrl+c to stop this script."
        echo "============================================="
        echo " "
        GITHUB_RESPONSE=$(sudo -u $OE_USER git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME/enterprise/addons" 2>&1)
    done

    echo -e "=== Added Enterprise code under $OE_HOME/enterprise/addons ==="
    echo -e "==== Installing Enterprise specific libraries ==="
    pip install num2words ofxparse dbfread ebaysdk firebase_admin pyOpenSSL
    sudo npm install -g less
    sudo npm install -g less-plugin-clean-css
fi

# Create custom addons directory
echo "Creating custom addons directory..."
sudo -u $OE_USER mkdir -p $OE_HOME/custom/addons

echo "Creating enterprise addons directory..."
sudo -u $OE_USER mkdir -p $OE_HOME/enterprise/addons

echo "=== Setting permissions on home folder ==="
sudo chown -R $OE_USER:$OE_USER $OE_HOME/

# Create Odoo configuration file
echo "=== Creating Odoo configuration file ... ==="
sudo touch /etc/${OE_CONFIG}.conf

# Generate admin password
if [ $GENERATE_RANDOM_PASSWORD = "True" ]; then
    echo -e "\n========= Generating random admin password ==========="
    OE_SUPERADMIN=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 1)
fi

sudo cat <<EOF > /etc/${OE_CONFIG}.conf
[options]
admin_passwd = ${OE_SUPERADMIN}
db_host = False
db_port = False
db_user = $OE_USER
db_password = False
logfile = /var/log/${OE_USER}/${OE_CONFIG}.log
addons_path = ${OE_HOME_EXT}/addons, ${OE_HOME}/custom/addons, ${OE_HOME}/enterprise/addons
http_port = ${OE_PORT}
xmlrpc_port = ${OE_PORT}
workers = 1
list_db = True
EOF

sudo chown $OE_USER:$OE_USER /etc/${OE_CONFIG}.conf
sudo chmod 640 /etc/${OE_CONFIG}.conf

#--------------------------------------------------
# Creating systemd service file for Odoo
#--------------------------------------------------
echo "=== Creating systemd service file... ==="
sudo cat <<EOF > /lib/systemd/system/$OE_USER-$OE_VERSION.service
[Unit]
Description=Odoo Open Source ERP and CRM ($OE_VERSION)
After=network.target

[Service]
Type=simple
User=$OE_USER
Group=$OE_USER
ExecStart=$VENV_PATH/bin/python3 $OE_HOME_EXT/odoo-bin --config /etc/${OE_CONFIG}.conf --logfile /var/log/${OE_USER}/${OE_CONFIG}.log
KillMode=mixed

[Install]
WantedBy=multi-user.target

EOF

sudo chmod 755 /lib/systemd/system/$OE_USER-$OE_VERSION.service
sudo chown root: /lib/systemd/system/$OE_USER-$OE_VERSION.service

# Reload systemd and start Odoo service
echo "=== Reloading systemd daemon ... ==="
sudo systemctl daemon-reload

sudo systemctl enable --now $OE_USER-$OE_VERSION.service
sudo systemctl start $OE_USER-$OE_VERSION.service

#--------------------------------------------------
# Install Nginx if needed
#--------------------------------------------------
if [ $INSTALL_NGINX = "True" ]; then
  echo "==== Installing nginx ... ===="
  sudo apt install -y nginx
  sudo systemctl enable nginx

  echo "==== Configuring nginx ... ===="
  cat <<EOF > /etc/nginx/sites-available/$OE_USER-$OE_VERSION

upstream $OE_USER-$OE_VERSION {
 server 127.0.0.1:$OE_PORT;
}

upstream ${OE_USER}chat-$OE_VERSION {
 server 127.0.0.1:$LONGPOLLING_PORT;
}

server {
   listen 80;
   server_name $WEBSITE_NAME;

   client_max_body_size 500M;

   access_log /var/log/nginx/$OE_USER-access.log;
   error_log /var/log/nginx/$OE_USER-error.log;

   keepalive_timeout 90;

   proxy_buffers 16 64k;
   proxy_buffer_size 128k;

   proxy_read_timeout 720s;
   proxy_connect_timeout 720s;
   proxy_send_timeout 720s;

   proxy_set_header Host \$host;
   proxy_set_header X-Forwarded-Host \$host;
   proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
   proxy_set_header X-Forwarded-Proto \$scheme;
   proxy_set_header X-Real-IP \$remote_addr;

   location / {
     proxy_redirect off;
     proxy_pass http://$OE_USER-$OE_VERSION;
   }

   location /longpolling {
       proxy_pass http://${OE_USER}chat-$OE_VERSION;
   }

   location ~* /web/static/ {
       proxy_cache_valid 200 90m;
       proxy_buffering on;
       expires 864000;
       proxy_pass http://$OE_USER-$OE_VERSION;
  }

  gzip_types text/css text/less text/plain text/xml application/xml application/json application/javascript;
  gzip on;
}
 
EOF

  sudo ln -s /etc/nginx/sites-available/$OE_USER-$OE_VERSION /etc/nginx/sites-enabled/$OE_USER-$OE_VERSION
  sudo rm /etc/nginx/sites-enabled/default
  sudo rm /etc/nginx/sites-available/default

  sudo systemctl reload nginx
  sudo su root -c "printf 'proxy_mode = True\n' >> /etc/${OE_CONFIG}.conf"
  echo "Done! The Nginx server is up and running. Configuration can be found at /etc/nginx/sites-available/$OE_USER-$OE_VERSION"
else
  echo "===== Nginx isn't installed due to choice of the user! ========"
fi

#--------------------------------------------------
# Enable ssl with certbot
#--------------------------------------------------
if [ $INSTALL_NGINX = "True" ] && [ $ENABLE_SSL = "True" ]  && [ $WEBSITE_NAME != "example.com" ];then
  echo "==== Installing certbot certificate ... ===="
  sudo apt-get remove certbot
  sudo snap install core
  sudo snap refresh core
  sudo snap install --classic certbot
  sudo ln -s /snap/bin/certbot /usr/bin/certbot
  sudo certbot --nginx -d $WEBSITE_NAME 
  sudo systemctl reload nginx  
  echo "============ SSL/HTTPS is enabled! ==========="
else
  echo "==== SSL/HTTPS isn't enabled due to choice of the user or because of a misconfiguration! ======"
fi

#--------------------------------------------------
# UFW Firewall
#--------------------------------------------------
echo "=== Installation of UFW firewall ... ==="
sudo apt install -y ufw 

sudo ufw allow 'Nginx Full'
sudo ufw allow 'Nginx HTTP'
sudo ufw allow 'Nginx HTTPS'
sudo ufw allow 22/tcp
sudo ufw allow 6010/tcp
sudo ufw allow 8069/tcp
sudo ufw allow 8072/tcp
sudo ufw enable -y

clear

# Final message
echo "Checking Odoo service status..."
sudo systemctl status $OE_USER-$OE_VERSION
echo "========================================================================"
echo "Done! The Odoo server is up and running. Specifications:"
echo "Port: $OE_PORT"
echo "User service: $OE_USER"
echo "User PostgreSQL: $OE_USER"
echo "Code location: $OE_HOME_EXT"
echo "Addons folder: $OE_HOME/custom/addons/"
echo "Password superadmin (database): $OE_SUPERADMIN"
echo "start odoo service: sudo systemctl start $OE_USER-$OE_VERSION"
echo "stop odoo service: sudo systemctl stop $OE_USER-$OE_VERSION"
echo "Restart Odoo service: sudo systemctl restart $OE_USER-$OE_VERSION"
echo "Odoo installation is complete. Access it at http://your-IP-address:$OE_PORT"
echo "========================================================================"

if [ $INSTALL_NGINX = "True" ]; then
  echo "Nginx configuration file: /etc/nginx/sites-available/$OE_USER-$OE_VERSION"
fi

