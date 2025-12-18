#!/bin/bash

# =========================================================
# Hysteria V1 - Unificado (Core + Menú)
# Fusionado para Script Multiprocolo
# =========================================================

# --- Variables Globales ---
export LANG=en_US.UTF-8
DEFAULT_SNI="www.bing.com"
CONFIG_DIR="/etc/hysteria"
EXECUTABLE_INSTALL_PATH="/usr/local/bin/hysteria1"
SYSTEMD_SERVICES_DIR="/etc/systemd/system"
LATEST_VERSION_HYSTERIA1="v1.3.5"

# Colores
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN='\033[0m'

# --- Funciones de Utilidad ---
red() { echo -e "${RED}${01m}$1${PLAIN}"; }
green() { echo -e "${GREEN}${01m}$1${PLAIN}"; }
yellow() { echo -e "${YELLOW}${01m}$1${PLAIN}"; }

# --- Lógica de Instalación Core (ex install_server.sh) ---
detect_arch() {
    case "$(uname -m)" in
        'i386' | 'i686') ARCH='386' ;;
        'amd64' | 'x86_64') ARCH='amd64' ;;
        'armv8' | 'aarch64') ARCH='arm64' ;;
        *) red "Arquitectura no soportada"; exit 1 ;;
    esac
}

download_binary() {
    local version=$LATEST_VERSION_HYSTERIA1
    local url="https://github.com/apernet/hysteria/releases/download/$version/hysteria-linux-$ARCH"
    yellow "Descargando binario Hysteria V1 ($version)..."
    curl -L -f -q --retry 5 -o "$EXECUTABLE_INSTALL_PATH" "$url"
    chmod +x "$EXECUTABLE_INSTALL_PATH"
}

setup_systemd() {
    yellow "Configurando servicio Systemd..."
    cat <<EOF > "$SYSTEMD_SERVICES_DIR/hysteria1-server.service"
[Unit]
Description=Hysteria V1 Server Service
After=network.target

[Service]
Type=simple
ExecStart=$EXECUTABLE_INSTALL_PATH -config $CONFIG_DIR/config.json server
WorkingDirectory=$CONFIG_DIR
User=root
Environment=HYSTERIA_LOG_LEVEL=info
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
}

# --- Lógica de Configuración (hysteria1.sh) ---

realIp(){
    ip=$(curl -s4m8 ip.sb -k) || ip=$(curl -s6m8 ip.sb -k)
}

inst_cert(){
    # [Mantenido del original: Opciones 1 (Self-signed), 2 (ACME), 3 (Custom)]
    # Por brevedad, aquí se define la lógica de la opción 1 por defecto si no hay entrada
    mkdir -p $CONFIG_DIR
    cert_path="$CONFIG_DIR/cert.crt"
    key_path="$CONFIG_DIR/private.key"
    openssl ecparam -genkey -name prime256v1 -out "$key_path"
    openssl req -new -x509 -days 36500 -key "$key_path" -out "$cert_path" -subj "/CN=$DEFAULT_SNI"
    chmod 777 "$cert_path" "$key_path"
    hy_host=$ip
    sni_host=$DEFAULT_SNI
}

# --- Función Principal de Instalación ---
installHysteria(){
    realIp
    detect_arch
    
    # Instalación de dependencias
    apt update && apt install -y curl wget sudo qrencode iptables-persistent netfilter-persistent openssl

    download_binary
    setup_systemd

    # Configuración básica (Simplificada para integración rápida)
    # Aquí puedes llamar a inst_port, inst_protocol del script original
    port=$(shuf -i 2000-65535 -n 1)
    inst_cert
    
    cat <<EOF > $CONFIG_DIR/config.json
{
    "protocol": "udp",
    "listen": ":$port",
    "resolve_preference": "46",
    "cert": "$cert_path",
    "key": "$key_path",
    "alpn": "h3",
    "auth": {
        "mode": "password",
        "config": {
            "password": "$(date +%s%N | md5sum | cut -c 1-16)"
        }
    }
}
EOF

    systemctl enable hysteria1-server
    systemctl start hysteria1-server
    green "Hysteria V1 instalado y corriendo en puerto $port"
}

# --- Menú de Integración ---
menu_hysteria() {
    echo -e "1. Instalar Hysteria V1"
    echo -e "2. Desinstalar"
    echo -e "0. Salir"
    read -p "Opción: " opt
    case $opt in
        1) installHysteria ;;
        2) # Lógica de desinstalación
           systemctl stop hysteria1-server
           rm -rf $EXECUTABLE_INSTALL_PATH $CONFIG_DIR
           green "Desinstalado." ;;
        *) exit ;;
    esac
}

menu_hysteria

