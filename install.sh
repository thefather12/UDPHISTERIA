#!/bin/bash

# =========================================================
# Hysteria V1 - TODO EN UNO (Instalador + Menú + Editor)
# =========================================================

export LANG=en_US.UTF-8

# --- Matriz de Colores del Usuario ---
COLOR[0]='\033[1;37m' # Blanco
COLOR[1]='\e[93m'     # Amarillo
COLOR[2]='\e[32m'     # Verde
COLOR[3]='\e[31m'     # Rojo
COLOR[4]='\e[34m'     # Azul
COLOR[5]='\e[95m'     # Magenta
COLOR[6]='\033[1;97m' # Blanco Brillante
COLOR[7]='\033[36m'   # Cian
NC='\e[0m'

# --- Variables Globales ---
CONFIG_DIR="/etc/hysteria"
CONFIG_FILE="/etc/hysteria/config.json"
EXECUTABLE="/usr/local/bin/hysteria1"
SYSTEMD_SERVICE="/etc/systemd/system/hysteria1-server.service"
LATEST_VERSION="v1.3.5"

# --- Funciones Técnicas ---

detect_arch() {
    case "$(uname -m)" in
        'x86_64') ARCH='amd64' ;;
        'aarch64') ARCH='arm64' ;;
        'i386' | 'i686') ARCH='386' ;;
        *) echo -e "${COLOR[3]}Arquitectura no soportada.${NC}"; exit 1 ;;
    esac
}

stop_hysteria() {
    systemctl stop hysteria1-server > /dev/null 2>&1
    pkill -f hysteria1 > /dev/null 2>&1
}

# --- Función para obtener valores actuales del JSON ---
get_val() {
    grep -oP "\"$1\":\s*\"\K[^\"]+" "$CONFIG_FILE"
}

# --- Menú de Configuración (NUEVO) ---
change_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${COLOR[3]}Error: No hay configuración instalada.${NC}"
        sleep 2 && return
    fi

    clear
    echo -e "${COLOR[5]}┌──────────────────────────────────────────────┐${NC}"
    echo -e "${COLOR[5]}│${NC}       ${COLOR[6]}MODIFICAR CONFIGURACIÓN HYSTERIA${NC}       ${COLOR[5]}│${NC}"
    echo -e "${COLOR[5]}└──────────────────────────────────────────────┘${NC}"
    
    # Leer valores actuales
    curr_port=$(grep -oP '"listen":\s*":\K\d+' "$CONFIG_FILE")
    curr_pass=$(grep -oP '"password":\s*"\K[^"]+' "$CONFIG_FILE")
    curr_sni=$(grep -oP '"/CN=\K[^"]+' "$CONFIG_DIR/cert.crt" 2>/dev/null || echo "www.bing.com")

    echo -e " ${COLOR[2]}1)${NC} Cambiar Puerto (Actual: $curr_port)"
    echo -e " ${COLOR[2]}2)${NC} Cambiar Contraseña (Actual: $curr_pass)"
    echo -e " ${COLOR[2]}3)${NC} Cambiar SNI (Actual: $curr_sni)"
    echo -e " ${COLOR[2]}0)${NC} Volver"
    echo ""
    read -p "Seleccione: " conf_opt

    case $conf_opt in
        1)
            read -p "Nuevo puerto: " new_port
            sed -i "s/\"listen\": \":$curr_port\"/\"listen\": \":$new_port\"/g" "$CONFIG_FILE"
            ;;
        2)
            read -p "Nueva contraseña: " new_pass
            sed -i "s/\"password\": \"$curr_pass\"/\"password\": \"$new_pass\"/g" "$CONFIG_FILE"
            ;;
        3)
            read -p "Nuevo SNI: " new_sni
            openssl req -new -x509 -days 36500 -nodes -key "$CONFIG_DIR/private.key" -out "$CONFIG_DIR/cert.crt" -subj "/CN=$new_sni"
            ;;
        0) return ;;
    esac

    systemctl restart hysteria1-server
    echo -e "${COLOR[2]}Configuración actualizada y servicio reiniciado.${NC}"
    sleep 2
}

# --- Función de Instalación ---
install_process() {
    clear
    echo -e "${COLOR[4]}Iniciando instalación...${NC}"
    apt-get update && apt-get install -y curl wget openssl qrencode
    
    detect_arch
    stop_hysteria
    
    mkdir -p "$CONFIG_DIR"
    local url="https://github.com/apernet/hysteria/releases/download/$LATEST_VERSION/hysteria-linux-$ARCH"
    wget -qO "$EXECUTABLE" "$url" && chmod +x "$EXECUTABLE"

    # Configuración inicial
    read -p "Puerto UDP (Enter aleatorio): " port
    [[ -z "$port" ]] && port=$(shuf -i 2000-65000 -n 1)
    read -p "Contraseña: " pass
    [[ -z "$pass" ]] && pass=$(date +%s%N | md5sum | cut -c 1-12)

    # RNG Fix
    export RANDFILE=$CONFIG_DIR/.rnd && touch $CONFIG_DIR/.rnd
    openssl ecparam -genkey -name prime256v1 -out "$CONFIG_DIR/private.key"
    openssl req -new -x509 -days 36500 -nodes -key "$CONFIG_DIR/private.key" -out "$CONFIG_DIR/cert.crt" -subj "/CN=www.bing.com"

    cat <<EOF > "$CONFIG_FILE"
{
    "protocol": "udp",
    "listen": ":$port",
    "resolve_preference": "46",
    "cert": "$CONFIG_DIR/cert.crt",
    "key": "$CONFIG_DIR/private.key",
    "alpn": "h3",
    "auth": { "mode": "password", "config": { "password": "$pass" } }
}
EOF

    # Crear Servicio
    cat <<EOF > "$SYSTEMD_SERVICE"
[Unit]
Description=Hysteria V1
After=network.target
[Service]
ExecStart=$EXECUTABLE -config $CONFIG_FILE server
WorkingDirectory=$CONFIG_DIR
User=root
Restart=always
[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload && systemctl enable hysteria1-server && systemctl start hysteria1-server
    echo -e "${COLOR[2]}Hysteria instalado con éxito.${NC}"
    read -p "Presione Enter..."
}

# --- Menú Principal ---
while true; do
    clear
    echo -e "${COLOR[5]}┌──────────────────────────────────────────────┐${NC}"
    echo -e "${COLOR[5]}│${NC}        ${COLOR[6]}GESTOR HYSTERIA V1 UNIFICADO${NC}         ${COLOR[5]}│${NC}"
    echo -e "${COLOR[5]}└──────────────────────────────────────────────┘${NC}"
    echo -e "  ${COLOR[2]}[1]${NC} Instalar / Reinstalar"
    echo -e "  ${COLOR[2]}[2]${NC} ${COLOR[1]}Cambiar Configuración${NC} ${COLOR[0]}(Puerto, Pass, SNI)${NC}"
    echo -e "  ${COLOR[2]}[3]${NC} Desinstalar"
    echo -e "  ${COLOR[5]}──────────────────────────────────────────────${NC}"
    echo -e "  ${COLOR[2]}[4]${NC} Ver Logs"
    echo -e "  ${COLOR[2]}[5]${NC} Mostrar Configuración Actual"
    echo -e "  ${COLOR[2]}[0]${NC} Salir"
    echo ""
    read -p "Opción: " opt
    case $opt in
        1) install_process ;;
        2) change_config ;;
        3) stop_hysteria && rm -rf "$CONFIG_DIR" "$EXECUTABLE" "$SYSTEMD_SERVICE" && echo "Eliminado"; sleep 1 ;;
        4) journalctl -u hysteria1-server -f ;;
        5) clear && cat "$CONFIG_FILE" && read -p "Enter para continuar..." ;;
        0) exit ;;
    esac
done

