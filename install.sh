#!/bin/bash

# =========================================================
# Hysteria V1 - Unificado (Instalación + Gestión + OBFS)
# =========================================================

# --- Matriz de Colores ---
COLOR[0]='\033[1;37m' # Blanco
COLOR[1]='\e[93m'     # Amarillo claro
COLOR[2]='\e[32m'     # Verde
COLOR[3]='\e[31m'     # Rojo
COLOR[4]='\e[34m'     # Azul
COLOR[5]='\e[95m'     # Magenta
COLOR[6]='\033[1;97m' # Blanco brillante
COLOR[7]='\033[36m'   # Cian
NC='\e[0m'

CONFIG_DIR="/etc/hysteria"
CONFIG_FILE="/etc/hysteria/config.json"
EXECUTABLE="/usr/local/bin/hysteria1"
SYSTEMD_SERVICE="/etc/systemd/system/hysteria1-server.service"

# --- Crear comando menu_udp ---
if [[ ! -f "/usr/local/bin/menu_udp" ]]; then
    echo "bash $(readlink -f "$0")" > /usr/local/bin/menu_udp
    chmod +x /usr/local/bin/menu_udp
fi

# --- Funciones Técnicas ---
detect_arch() {
    case "$(uname -m)" in
        'x86_64') ARCH='amd64' ;;
        'aarch64') ARCH='arm64' ;;
        *) ARCH='amd64' ;;
    esac
}

stop_hys() {
    systemctl stop hysteria1-server > /dev/null 2>&1
    pkill -f hysteria1 > /dev/null 2>&1
}

# --- Menú de Modificación (IMPORTANTE) ---
modify_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${COLOR[3]}Error: Hysteria no está instalado.${NC}"
        sleep 2 && return
    fi
    
    clear
    echo -e "${COLOR[5]}┌──────────────────────────────────────────────┐${NC}"
    echo -e "${COLOR[5]}│${NC}        ${COLOR[6]}MODIFICAR CONFIGURACIÓN UDP${NC}          ${COLOR[5]}│${NC}"
    echo -e "${COLOR[5]}└──────────────────────────────────────────────┘${NC}"
    echo -e " ${COLOR[2]}1)${NC} Cambiar Puerto UDP"
    echo -e " ${COLOR[2]}2)${NC} Cambiar Contraseña Auth"
    echo -e " ${COLOR[2]}3)${NC} Configurar/Cambiar OBFS"
    echo -e " ${COLOR[2]}0)${NC} Volver"
    echo ""
    echo -ne "${COLOR[1]}Seleccione una opción:${NC} "
    read m_opt

    case $m_opt in
        1)
            echo -ne "${COLOR[7]}Ingrese nuevo puerto: ${COLOR[6]}"
            read n_port
            sed -i "s/\"listen\": \":.*/\"listen\": \":$n_port\",/g" "$CONFIG_FILE"
            ;;
        2)
            echo -ne "${COLOR[7]}Ingrese nueva contraseña Auth: ${COLOR[6]}"
            read n_pass
            sed -i "s/\"password\": \".*\"/\"password\": \"$n_pass\"/g" "$CONFIG_FILE"
            ;;
        3)
            echo -e "${COLOR[7]}Seleccione tipo de Ofuscación:${NC}"
            echo -e " ${COLOR[2]}1)${NC} OBFS (Solo ofuscación)"
            echo -e " ${COLOR[2]}2)${NC} OBFS + AUTH (Recomendado)"
            echo -ne "${COLOR[1]}Opción: ${NC}"
            read o_type
            echo -ne "${COLOR[7]}Ingrese nueva contraseña de Ofuscación: ${COLOR[6]}"
            read n_obfs
            # Limpiar obfs anterior
            sed -i '/"obfs":/d' "$CONFIG_FILE"
            # Insertar nueva configuración de obfs
            sed -i "3i    \"obfs\": \"$n_obfs\"," "$CONFIG_FILE"
            echo -e "${COLOR[2]}OBFS actualizado.${NC}"
            ;;
        0) return ;;
    esac
    
    systemctl restart hysteria1-server
    echo -e "${COLOR[2]}Cambios aplicados con éxito.${NC}"
    sleep 2
}

# --- Proceso de Instalación ---
install_hys() {
    clear
    echo -e "${COLOR[5]}==============================================${NC}"
    echo -e "      ${COLOR[6]}INSTALACIÓN HYSTERIA V1 UNIFICADO${NC}"
    echo -e "${COLOR[5]}==============================================${NC}"
    
    apt-get update && apt-get install -y curl wget openssl qrencode
    
    stop_hys
    detect_arch
    mkdir -p "$CONFIG_DIR"

    # Datos con realce de color
    echo -e -n "${COLOR[7]}➤ Puerto UDP (Enter aleatorio): ${COLOR[6]}"
    read port
    [[ -z "$port" ]] && port=$(shuf -i 2000-65000 -n 1)

    echo -e -n "${COLOR[7]}➤ Contraseña Auth (Enter aleatorio): ${COLOR[6]}"
    read password
    [[ -z "$password" ]] && password=$(date +%s%N | md5sum | cut -c 1-12)

    echo -e "${COLOR[7]}➤ Configurar Ofuscación:${NC}"
    echo -e "  ${COLOR[2]}1)${NC} OBFS"
    echo -e "  ${COLOR[2]}2)${NC} OBFS + AUTH"
    echo -e "  ${COLOR[2]}3)${NC} Sin Ofuscación"
    echo -ne "${COLOR[1]}  Seleccione opción: ${COLOR[6]}"
    read obfs_opt
    
    obfs_line=""
    if [[ "$obfs_opt" == "1" || "$obfs_opt" == "2" ]]; then
        echo -ne "${COLOR[7]}  ➤ Ingrese clave de ofuscación: ${COLOR[6]}"
        read obfs_key
        obfs_line="\"obfs\": \"$obfs_key\","
    fi

    # Descarga e Instalación
    wget -qO "$EXECUTABLE" "https://github.com/apernet/hysteria/releases/download/v1.3.5/hysteria-linux-$ARCH"
    chmod +x "$EXECUTABLE"

    # Certs Fix RNG
    export RANDFILE=$CONFIG_DIR/.rnd && touch $CONFIG_DIR/.rnd
    openssl ecparam -genkey -name prime256v1 -out "$CONFIG_DIR/private.key"
    openssl req -new -x509 -days 36500 -nodes -key "$CONFIG_DIR/private.key" -out "$CONFIG_DIR/cert.crt" -subj "/CN=www.bing.com"

    # Crear Config
    cat <<EOF > "$CONFIG_FILE"
{
    "protocol": "udp",
    "listen": ":$port",
    $obfs_line
    "cert": "$CONFIG_DIR/cert.crt",
    "key": "$CONFIG_DIR/private.key",
    "alpn": "h3",
    "auth": {
        "mode": "password",
        "config": { "password": "$password" }
    }
}
EOF

    # Crear Servicio
    cat <<EOF > "$SYSTEMD_SERVICE"
[Unit]
Description=Hysteria V1
After=network.target
[Service]
ExecStart=$EXECUTABLE -config $CONFIG_FILE server
Restart=always
User=root
[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload && systemctl enable hysteria1-server && systemctl restart hysteria1-server
    
    echo -e "\n${COLOR[2]}✔ INSTALACIÓN COMPLETA${NC}"
    echo -e "${COLOR[7]}Comando de acceso: ${COLOR[2]}menu_udp${NC}"
    read -p "Presione Enter para volver..."
}

# --- Menú Principal ---
while true; do
    clear
    echo -e "${COLOR[5]}┌──────────────────────────────────────────────┐${NC}"
    echo -e "${COLOR[5]}│${NC}       ${COLOR[6]}GESTOR HYSTERIA V1 - MENU UDP${NC}          ${COLOR[5]}│${NC}"
    echo -e "${COLOR[5]}└──────────────────────────────────────────────┘${NC}"
    echo -e "  ${COLOR[2]}[1]${NC} Instalar Hysteria V1"
    echo -e "  ${COLOR[2]}[2]${NC} ${COLOR[1]}Modificar Configuración (Puerto/OBFS/Pass)${NC}"
    echo -e "  ${COLOR[2]}[3]${NC} Desinstalar"
    echo -e "  ${COLOR[5]}──────────────────────────────────────────────${NC}"
    echo -e "  ${COLOR[2]}[4]${NC} Ver Logs en vivo"
    echo -e "  ${COLOR[2]}[0]${NC} Salir"
    echo ""
    echo -ne "${COLOR[1]}Seleccione una opción:${NC} "
    read opt
    case $opt in
        1) install_hys ;;
        2) modify_config ;;
        3) stop_hys && rm -rf "$CONFIG_DIR" "$EXECUTABLE" "$SYSTEMD_SERVICE" && echo "Eliminado"; sleep 1 ;;
        4) journalctl -u hysteria1-server -f ;;
        0) exit ;;
    esac
done

