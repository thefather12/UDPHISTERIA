#!/bin/bash

# --- CONFIGURACIÓN DE RUTAS ---
export dir=$(pwd)
export repo_dir="${dir}/UDPMOD"

# Instalación de Figlet para el banner
if ! command -v figlet &> /dev/null; then
    apt update -y && apt install figlet -y &> /dev/null
fi

# --- FUNCIONES ---

mostrar_banner() {
    clear
    echo -e "\e[1;36m"
    figlet "UDPMOD"
    echo -e "\e[0m"
    echo "=========================================="
}

instalacion_completa() {
    mostrar_banner
    # El script original pedía el dominio aquí
    read -p " INGRESA AQUI TU DOMINIO (o deja vacío para IP): " domain
    [[ -z "$domain" ]] && domain=$(wget -qO- eth0.me)

    echo "Instalando dependencias y clonando repositorio..."
    apt update -y; apt upgrade -y; apt install git openssl -y
    
    [[ -d "$repo_dir" ]] && rm -rf "$repo_dir"
    git clone https://github.com/rudi9999/UDPMOD.git

    # Generación de variables técnicas
    OBFS=$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 8)
    # El AUTH suele ser dinámico o fijo según el binario, aquí generamos uno:
    AUTH=$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 12)
    interfas=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
    sys=$(which sysctl)
    ip4t=$(which iptables)
    ip6t=$(which ip6tables)

    # Generación de Certificados SSL (Requerido para que el binario arranque)
    openssl genrsa -out "${repo_dir}/udpmod.ca.key" 2048
    openssl req -new -x509 -days 3650 -key "${repo_dir}/udpmod.ca.key" -subj "/C=CN/ST=GD/L=SZ/O=Udpmod, Inc./CN=Udpmod Root CA" -out "${repo_dir}/udpmod.ca.crt"
    openssl req -newkey rsa:2048 -nodes -keyout "${repo_dir}/udpmod.server.key" -subj "/C=CN/ST=GD/L=SZ/O=Udpmod, Inc./CN=${domain}" -out "${repo_dir}/udpmod.server.csr"
    openssl x509 -req -extfile <(printf "subjectAltName=DNS:${domain},DNS:${domain}") -days 3650 -in "${repo_dir}/udpmod.server.csr" -CA "${repo_dir}/udpmod.ca.crt" -CAkey "${repo_dir}/udpmod.ca.key" -CAcreateserial -out "${repo_dir}/udpmod.server.crt"

    # Modificación de archivos (sed) - Usando las etiquetas del script original
    sed -i "s/setobfs/${OBFS}/" "${repo_dir}/config.json"
    # Si el config.json tiene etiqueta para auth:
    sed -i "s/setauth/${AUTH}/" "${repo_dir}/config.json" 2>/dev/null 
    
    sed -i "s#instDir#${repo_dir}#g" "${repo_dir}/config.json"
    sed -i "s#instDir#${repo_dir}#g" "${repo_dir}/udpmod.service"
    sed -i "s#iptb#${interfas}#g" "${repo_dir}/udpmod.service"
    sed -i "s#sysb#${sys}#g" "${repo_dir}/udpmod.service"
    sed -i "s#ip4tbin#${ip4t}#g" "${repo_dir}/udpmod.service"
    sed -i "s#ip6tbin#${ip6t}#g" "${repo_dir}/udpmod.service"

    # Permisos y arranque
    chmod +x "${repo_dir}/"*
    cp "${repo_dir}/udpmod.service" /etc/systemd/system/
    
    systemctl daemon-reload
    systemctl enable udpmod
    systemctl restart udpmod

    # Mostrar datos finales como el script original
    echo -e "\n\e[1;32m--- DATOS DE CONEXIÓN ---\e[0m"
    echo " DOMINIO: ${domain}"
    echo " OBFS: ${OBFS}"
    echo " AUTH: ${AUTH}"
    echo " PUERTO: 36715"
    echo " RANGO: 10000:65000"
    echo "--------------------------"
    
    # Guardar datos para consulta posterior
    echo "OBFS: ${OBFS} | AUTH: ${AUTH} | DOMINIO: ${domain}" > "${repo_dir}/data"
    
    echo -ne "\n\033[1;31mCOPIE LOS DATOS Y PRESIONE ENTER PARA IR AL MENU!\033[0m"; read
}

# --- MENÚ ---
menu() {
    while true; do
        mostrar_banner
        echo " 1) ACTIVAR / REINSTALAR UDPMOD"
        echo " 2) Estado del servicio"
        echo " 3) Cambio de dominio"
        echo " 4) Agregar usuario"
        echo " 5) Eliminar usuario"
        echo " 6) Lista de usuarios"
        echo " 7) Desinstalar UDPMOD"
        echo " 0) Salir"
        echo "=========================================="
        read -p "Seleccione una opción: " opcion

        case $opcion in
            1) instalacion_completa ;;
            2) 
                echo "--- ESTADO ---"
                systemctl status udpmod --no-pager | grep -E "Active:|Main PID:"
                read -p "Enter para volver..." 
                ;;
            3) 
                read -p "Nuevo Dominio: " domain
                # Regenerar certificados para el nuevo dominio
                openssl req -newkey rsa:2048 -nodes -keyout "${repo_dir}/udpmod.server.key" -subj "/C=CN/ST=GD/L=SZ/O=Udpmod, Inc./CN=${domain}" -out "${repo_dir}/udpmod.server.csr"
                openssl x509 -req -extfile <(printf "subjectAltName=DNS:${domain},DNS:${domain}") -days 3650 -in "${repo_dir}/udpmod.server.csr" -CA "${repo_dir}/udpmod.ca.crt" -CAkey "${repo_dir}/udpmod.ca.key" -CAcreateserial -out "${repo_dir}/udpmod.server.crt"
                systemctl restart udpmod
                echo "Dominio actualizado"; sleep 1 
                ;;
            4) read -p "Usuario: " u; echo "$u" >> "${repo_dir}/users.db"; echo "Agregado"; sleep 1 ;;
            5) read -p "Eliminar: " u; sed -i "/^$u$/d" "${repo_dir}/users.db"; echo "Borrado"; sleep 1 ;;
            6) echo "--- USUARIOS ---"; cat "${repo_dir}/users.db" 2>/dev/null; read -p "Enter..." ;;
            7) 
                systemctl stop udpmod; systemctl disable udpmod
                rm /etc/systemd/system/udpmod.service; rm -rf "$repo_dir"
                echo "Desinstalado"; sleep 1; exit 0 
                ;;
            0) exit 0 ;;
            *) echo "Opción no válida" ;;
        esac
    done
}

menu

