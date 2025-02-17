#!/bin/bash

# Verificar que se proporcionen los argumentos necesarios
if [ "$#" -ne 3 ]; then
    echo "Uso: $0 <OE_VERSION> <OE_PORT> <VENV_NAME>"
    echo "Ejemplo: $0 17.0 8069 odoo17_env"
    exit 1
fi

OE_VERSION=$1
OE_PORT=$2
VENV_NAME=$3

OE_USER="odoo$OE_VERSION"  # Por ejemplo, "odoo17" o "odoo18"
OE_HOME="/opt/$OE_USER"  # Por ejemplo, "/opt/odoo17" o "/opt/odoo18"
OE_HOME_EXT="$OE_HOME/${OE_USER}-server"
VENV_PATH="$OE_HOME/$VENV_NAME"  # Por ejemplo, "/opt/odoo17/odoo17_env"
OE_CONFIG="${OE_USER}-server.conf"  # Por ejemplo, "odoo17-server.conf" o "odoo18-server.conf"

# Otras configuraciones
INSTALL_WKHTMLTOPDF="True"
IS_ENTERPRISE="False"
INSTALL_POSTGRESQL_SIXTEEN="True"
INSTALL_NGINX="True"
OE_SUPERADMIN="admin"
GENERATE_RANDOM_PASSWORD="True"
WEBSITE_NAME="odoo$OE_VERSION.tudominio.com"  # Por ejemplo, "odoo17.tudominio.com" o "odoo18.tudominio.com"
LONGPOLLING_PORT="8072"
ENABLE_SSL="True"
ADMIN_EMAIL="odoo@example.com"

#--------------------------------------------------
# Actualizar el sistema
#--------------------------------------------------
echo -e "=== Actualizando el sistema ... ==="
sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y

#--------------------------------------------------
# Crear usuario de sistema para Odoo
#--------------------------------------------------
if ! id "$OE_USER" &>/dev/null; then
    echo "=== Creando usuario de sistema para Odoo ... ==="
    sudo adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'Odoo' --group $OE_USER
else
    echo "=== El usuario $OE_USER ya existe. Saltando creación. ==="
fi

#--------------------------------------------------
# Crear entorno virtual
#--------------------------------------------------
if [ ! -d "$VENV_PATH" ]; then
    echo "=== Creando entorno virtual ... ==="
    sudo -u $OE_USER python3 -m venv $VENV_PATH
else
    echo "=== El entorno virtual ya existe. Saltando creación. ==="
fi

#--------------------------------------------------
# Clonar el repositorio de Odoo
#--------------------------------------------------
echo "=== Clonando Odoo $OE_VERSION desde GitHub ... ==="
sudo -u $OE_USER git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/odoo $OE_HOME_EXT

#--------------------------------------------------
# Instalar dependencias de Odoo
#--------------------------------------------------
echo "=== Instalando dependencias de Odoo ... ==="
sudo -u $OE_USER $VENV_PATH/bin/pip install -r $OE_HOME_EXT/requirements.txt

#--------------------------------------------------
# Crear archivo de configuración de Odoo
#--------------------------------------------------
echo "=== Creando archivo de configuración de Odoo ... ==="
sudo cat <<EOF > /etc/$OE_CONFIG
[options]
admin_passwd = ${OE_SUPERADMIN}
db_host = False
db_port = False
db_user = $OE_USER
db_password = False
logfile = /var/log/$OE_USER/$OE_CONFIG.log
addons_path = $OE_HOME_EXT/addons
http_port = $OE_PORT
xmlrpc_port = $OE_PORT
workers = 1
list_db = True
EOF

sudo chown $OE_USER:$OE_USER /etc/$OE_CONFIG
sudo chmod 640 /etc/$OE_CONFIG

#--------------------------------------------------
# Crear servicio systemd para Odoo
#--------------------------------------------------
echo "=== Creando servicio systemd para Odoo ... ==="
sudo cat <<EOF > /lib/systemd/system/$OE_USER.service
[Unit]
Description=Odoo $OE_VERSION
After=network.target

[Service]
Type=simple
User=$OE_USER
Group=$OE_USER
ExecStart=$VENV_PATH/bin/python3 $OE_HOME_EXT/odoo-bin --config /etc/$OE_CONFIG
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now $OE_USER.service

#--------------------------------------------------
# Mensaje final
#--------------------------------------------------
echo "=== Odoo $OE_VERSION instalado con éxito! ==="
echo "Puerto: $OE_PORT"
echo "Servicio systemd: $OE_USER.service"
echo "Archivo de configuración: /etc/$OE_CONFIG"
echo "Para iniciar Odoo: sudo systemctl start $OE_USER.service"
echo "Para detener Odoo: sudo systemctl stop $OE_USER.service"
