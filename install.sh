#!/bin/bash

# --- VARIABLES DEL INSTALADOR ORIGINAL ---
CONFIG_DIR="/etc/udpmod"
CONFIG_FILE="$CONFIG_DIR/config.json"
BIN_PATH="/usr/local/bin/udpmod"
SERVICE_NAME="udpmod-server.service"

# --- COLORES ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# --- FUNCIONES DE EXTRACCIÓN (Basadas en tu archivo) ---
get_config_val() {
    if [ -f "$CONFIG_FILE" ]; then
        grep "$1" "$CONFIG_FILE" | sed 's/"\|,//g' | awk '{print $2}'
    else
        echo "N/A"
    fi
}

# --- LÓGICA DE INSTALACIÓN (Referencia a installUDP.sh) ---
ejecutar_instalacion() {
    echo -e "${YELLOW}Iniciando instalación desde fuente oficial...${NC}"
    # Aquí puedes llamar a tu script original o integrar la lógica de:
    # 1. Descarga de binario
    # 2. Generación de certificados SSL
    # 3. Configuración de iptables
    bash <(curl -Ls https://raw.githubusercontent.com/rudi9999/UDPMOD/main/install.sh) # Ejemplo de llamada
    read -p "Instalación finalizada. Presiona Enter para abrir el menú."
}

# --- MENÚ INTERACTIVO ---
mostrar_menu() {
    while true; do
        clear
        IP_PUB=$(curl -s https://api.ipify.org || echo "127.0.0.1")
        PUERTO=$(get_config_val "listen")
        OBFS_VAL=$(get_config_val "obfs")
        ESTADO=$(systemctl is-active $SERVICE_NAME 2>/dev/null)
        
        [[ "$ESTADO" == "active" ]] && ESTADO_TXT="${GREEN}[ON]${NC}" || ESTADO_TXT="${RED}[OFF]${NC}"

        echo -e "${RED}---------------------------------------${NC}"
        echo -e "      ${BOLD}ADMINISTRACION UDPMOD v6${NC}"
        echo -e "${RED}---------------------------------------${NC}"
        echo -e " ${CYAN}BINARIO:${NC} Hysteria-V2"
        echo -e " ${CYAN}IP:${NC} $IP_PUB"
        echo -e " ${CYAN}OBFS:${NC} $OBFS_VAL"
        echo -e " ${CYAN}PUERTO:${NC} $PUERTO"
        echo -e "${RED}---------------------------------------${NC}"
        echo -e " ${GREEN}[1]${NC} > CA TLS CLIENTE"
        echo -e " ${GREEN}[2]${NC} > MODIFICAR OBFS"
        echo -e " ${GREEN}[3]${NC} > MODIFICAR RANGOS IPTABLES"
        echo -e " ${GREEN}[4]${NC} > MODIFICAR PUERTO"
        echo -e " ${RED}---------------------------------------${NC}"
        echo -e " ${GREEN}[5]${NC} > ${YELLOW}REINICIAR SERVICIO${NC}"
        echo -e " ${GREEN}[6]${NC} > INICIAR/PARAR SERVICIO $ESTADO_TXT"
        echo -e " ${GREEN}[7]${NC} > ESTADO DEL SERVICIO"
        echo -e " ${GREEN}[8]${NC} > LOG EN TIEMPO REAL"
        echo -e " ${RED}---------------------------------------${NC}"
        echo -e " ${GREEN}[10]${NC} > ${RED}DESINSTALAR UDPMOD${NC}"
        echo -e " ${GREEN}[0]${NC} > SALIR"
        echo -e "${RED}---------------------------------------${NC}"
        echo -ne " Selecciona una opcion: "
        read opcion

        case $opcion in
            1) 
                echo -e "${YELLOW}Certificado CA:${NC}"
                cat "$CONFIG_DIR/udpmod.ca.crt" 2>/dev/null || echo "No encontrado"
                read -p "Presiona Enter..." ;;
            2) 
                read -p "Nuevo valor OBFS: " NEW_OBFS
                sed -i "s/\"obfs\": \".*\"/\"obfs\": \"$NEW_OBFS\"/" "$CONFIG_FILE"
                systemctl restart $SERVICE_NAME
                ;;
            4) 
                read -p "Nuevo Puerto (ej. :36712): " NEW_PORT
                sed -i "s/\"listen\": \":.*\"/\"listen\": \"$NEW_PORT\"/" "$CONFIG_FILE"
                systemctl restart $SERVICE_NAME
                ;;
            5) systemctl restart $SERVICE_NAME ;;
            6) 
                if [[ "$ESTADO" == "active" ]]; then systemctl stop $SERVICE_NAME
                else systemctl start $SERVICE_NAME; fi ;;
            7) systemctl status $SERVICE_NAME; read -p "Enter..." ;;
            8) journalctl -u $SERVICE_NAME -f ;;
            10) 
                # Lógica de eliminación de tu script
                systemctl stop $SERVICE_NAME
                rm -rf "$CONFIG_DIR" "$BIN_PATH"
                echo "UDPMOD eliminado."
                exit 0 ;;
            0) exit 0 ;;
            *) echo "Opción inválida"; sleep 1 ;;
        esac
    done
}

# --- FLUJO PRINCIPAL ---
if [ -f "$BIN_PATH" ]; then
    mostrar_menu
else
    echo -e "${CYAN}UDPMOD no detectado.${NC}"
    echo "1) Instalar ahora"
    echo "2) Salir"
    read -p "Opción: " opt
    [[ "$opt" == "1" ]] && ejecutar_instalacion && mostrar_menu || exit 0
fi

