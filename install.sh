
#!/bin/bash

# =========================================================
# GESTOR HYSTERIA V1 - PRO UNIFICADO
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

# --- Crear comando permanente 'menuhy' ---
# Usamos un método más robusto para que el comando funcione siempre
if [[ ! -f "/usr/local/bin/menuhy" ]]; then
    echo "bash $(readlink -f "$0")" > /usr/local/bin/menuhy
    chmod +x /usr/local/bin/menuhy
fi

stop_hys() { systemctl stop hysteria1-server > /dev/null 2>&1; pkill -f hysteria1 > /dev/null 2>&1; }

# --- Función de Logs mejorada ---
show_logs() {
    echo -e "${COLOR[1]}Mostrando logs (Presiona Ctrl+C para detener la lectura)...${NC}"
    echo -e "${COLOR[7]}Una vez que te detengas, presiona Enter para volver al menú.${NC}"
    sleep 2
    journalctl -u hysteria1-server -n 50 -f
    echo -e "\n${COLOR[2]}Lectura de log finalizada.${NC}"
    read -p "Presione [Enter] para regresar al menú..."
}

# --- Función para mostrar configuración ---
show_config() {
    clear
    echo -e "${COLOR[5]}==============================================${NC}"
    echo -e "      ${COLOR[6]}CONFIGURACIÓN ACTUAL UDP${NC}"
    echo -e "${COLOR[5]}==============================================${NC}"
    if [[ -f "$CONFIG_FILE" ]]; then
        # Extraer datos para vista limpia
        PORT=$(grep -oP '"listen":\s*":\K\d+' "$CONFIG_FILE")
        AUTH=$(grep -oP '"password":\s*"\K[^"]+' "$CONFIG_FILE")
        OBFS=$(grep -oP '"obfs":\s*"\K[^"]+' "$CONFIG_FILE")
        
        echo -e "${COLOR[7]}IP del Servidor:${NC} ${COLOR[0]}$(curl -s ipv4.icanhazip.com)${NC}"
        echo -e "${COLOR[7]}Puerto UDP:     ${NC} ${COLOR[6]}$PORT${NC}"
        echo -e "${COLOR[7]}Auth/Password:  ${NC} ${COLOR[6]}$AUTH${NC}"
        [[ ! -z "$OBFS" ]] && echo -e "${COLOR[7]}OBFS/Camuflaje: ${NC} ${COLOR[6]}$OBFS${NC}"
        echo -e "${COLOR[7]}SNI/Host:       ${NC} ${COLOR[6]}www.bing.com${NC}"
        echo -e "${COLOR[5]}----------------------------------------------${NC}"
        echo -e "${COLOR[1]}Contenido del archivo JSON:${NC}"
        cat "$CONFIG_FILE"
    else
        echo -e "${COLOR[3]}No se encontró el archivo de configuración.${NC}"
    fi
    echo ""
    read -p "Presione [Enter] para regresar..."
}

# --- Función de Modificación ---
modify_config() {
    clear
    echo -e "${COLOR[5]}┌──────────────────────────────────────────────┐${NC}"
    echo -e "${COLOR[5]}│${NC}        ${COLOR[6]}MODIFICAR PARÁMETROS UDP${NC}             ${COLOR[5]}│${NC}"
    echo -e "${COLOR[5]}└──────────────────────────────────────────────┘${NC}"
    echo -e " ${COLOR[2]}1)${NC} Cambiar Puerto UDP"
    echo -e " ${COLOR[2]}2)${NC} Cambiar AUTH (Contraseña Usuario)"
    echo -e " ${COLOR[2]}3)${NC} Cambiar/Configurar OBFS"
    echo -e " ${COLOR[2]}0)${NC} Volver"
    echo ""
    read -p "Seleccione: " opt
    case $opt in
        1) echo -ne "${COLOR[7]}Nuevo Puerto: ${COLOR[6]}"; read n_p; sed -i "s/\"listen\": \":.*/\"listen\": \":$n_p\",/g" "$CONFIG_FILE" ;;
        2) echo -ne "${COLOR[7]}Nuevo AUTH: ${COLOR[6]}"; read n_a; sed -i "s/\"password\": \".*\"/\"password\": \"$n_a\"/g" "$CONFIG_FILE" ;;
        3) echo -ne "${COLOR[7]}Nuevo OBFS: ${COLOR[6]}"; read n_o; 
           if grep -q "obfs" "$CONFIG_FILE"; then sed -i "s/\"obfs\": \".*\"/\"obfs\": \"$n_o\"/g" "$CONFIG_FILE"
           else sed -i "3i    \"obfs\": \"$n_o\"," "$CONFIG_FILE"; fi ;;
        *) return ;;
    esac
    systemctl restart hysteria1-server
    echo -e "${COLOR[2]}Cambios aplicados.${NC}"
    sleep 1
}

# --- Proceso de Instalación ---
install_hys() {
    clear
    echo -e "${COLOR[5]}==============================================${NC}"
    echo -e "      ${COLOR[6]}INSTALACIÓN HYSTERIA V1 PRO${NC}"
    echo -e "${COLOR[5]}==============================================${NC}"
    
    stop_hys
    mkdir -p "$CONFIG_DIR"

    echo -e -n "${COLOR[7]}➤ Ingrese Puerto UDP: ${COLOR[6]}"
    read port
    [[ -z "$port" ]] && port=$(shuf -i 2000-65000 -n 1)

    echo -e -n "${COLOR[7]}➤ Ingrese Contraseña AUTH (Usuario): ${COLOR[6]}"
    read auth_pass
    [[ -z "$auth_pass" ]] && auth_pass=$(date +%s%N | md5sum | cut -c 1-12)

    echo -e -n "${COLOR[7]}➤ Ingrese Contraseña OBFS (Opcional): ${COLOR[6]}"
    read obfs_key
    
    obfs_line=""
    [[ ! -z "$obfs_key" ]] && obfs_line="\"obfs\": \"$obfs_key\","

    echo -e "${COLOR[4]}Instalando Core y Certificados...${NC}"
    wget -qO "$EXECUTABLE" "https://github.com/apernet/hysteria/releases/download/v1.3.5/hysteria-linux-amd64"
    chmod +x "$EXECUTABLE"

    export RANDFILE=$CONFIG_DIR/.rnd && touch $CONFIG_DIR/.rnd
    openssl ecparam -genkey -name prime256v1 -out "$CONFIG_DIR/private.key"
    openssl req -new -x509 -days 36500 -nodes -key "$CONFIG_DIR/private.key" -out "$CONFIG_DIR/cert.crt" -subj "/CN=www.bing.com"

    cat <<EOF > "$CONFIG_FILE"
{
    "protocol": "udp",
    "listen": ":$port",
    $obfs_line
    "cert": "$CONFIG_DIR/cert.crt",
    "key": "$CONFIG_DIR/private.key",
    "alpn": "h3",
    "auth": { "mode": "password", "config": { "password": "$auth_pass" } }
}
EOF

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
    echo -e "\n${COLOR[2]}✔ INSTALACIÓN EXITOSA.${NC}"
    read -p "Presione [Enter] para continuar..."
}

# --- Menú Principal ---
while true; do
    clear
    echo -e "${COLOR[5]}###############################################################################${NC}"
    echo -e "${COLOR[5]}#${NC} ${COLOR[6]}GESTOR HYSTERIA V1 - PROTOCOLO UDP${NC}                                      ${COLOR[5]}#${NC}"
    echo -e "${COLOR[5]}#${NC} ${COLOR[2]}By: @THEFATHER12 | Forked: THEFATHER12-OSCARG{NC}                         ${COLOR[5]}#${NC}"
    echo -e "${COLOR[5]}###############################################################################${NC}"
    echo ""
    echo -e " ${COLOR[2]}1.${NC} Instalar Hysteria 1"
    echo -e " ${COLOR[2]}2.${NC} ${COLOR[3]}Desinstalar Hysteria 1${NC}"
    echo -e " ${COLOR[5]}-------------${NC}"
    echo -e " ${COLOR[2]}3.${NC} Iniciar / Parar / Reiniciar"
    echo -e " ${COLOR[2]}4.${NC} ${COLOR[1]}Modificar Configuración (AUTH/OBFS/PUERTO)${NC}"
    echo -e " ${COLOR[2]}5.${NC} Ver Configuración Guardada (Datos App)"
    echo -e " ${COLOR[5]}-------------${NC}"
    echo -e " ${COLOR[2]}6.${NC} Ver Logs en Tiempo Real"
    echo -e " ${COLOR[2]}0.${NC} Salir del script"
    echo ""
    echo -ne "${COLOR[7]}Seleccione una opción [0-6]: ${COLOR[6]}"
    read menuInput

    case $menuInput in
        1) install_hys ;;
        2) stop_hys && rm -rf "$CONFIG_DIR" "$EXECUTABLE" "$SYSTEMD_SERVICE" && echo "Eliminado"; sleep 1 ;;
        3) systemctl restart hysteria1-server && echo "Reiniciado"; sleep 1 ;;
        4) modify_config ;;
        5) show_config ;;
        6) show_logs ;;
        0) exit 0 ;;
        *) echo -e "${COLOR[3]}Opción inválida${NC}"; sleep 1 ;;
    esac
done
