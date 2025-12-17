#!/bin/bash

# --- INSTALACIÓN DE DEPENDECIAS PARA EL MENÚ ---
if ! command -v figlet &> /dev/null; then
    apt update -y && apt install figlet -y &> /dev/null
fi

dir=$(pwd)
repo_dir="${dir}/UDPMOD"

# --- FUNCIONES ---

mostrar_banner() {
    clear
    echo -e "\e[1;36m"
    figlet "UDPMOD"
    echo -e "\e[0m"
    echo "=========================================="
    echo -e "       GESTOR DE SERVIDOR UDP"
    echo "=========================================="
}

configurar_dominio() {
    read -p " INGRESA TU DOMINIO (ej. sub.dominio.com): " domain
    if [ -z "$domain" ]; then
        echo -e "\e[1;31mError: El dominio no puede estar vacío.\e[0m"
        sleep 2
        return
    fi
    
    echo "Generando nuevos certificados para: $domain..."
    
    # Limpiar certificados antiguos si existen
    rm -f ${repo_dir}/udpmod.server.*
    
    # Generar certificados con el nuevo dominio
    openssl req -newkey rsa:2048 -nodes -keyout "${repo_dir}/udpmod.server.key" -subj "/C=CN/ST=GD/L=SZ/O=Udpmod, Inc./CN=${domain}" -out "${repo_dir}/udpmod.server.csr"
    openssl x509 -req -extfile <(printf "subjectAltName=DNS:${domain},DNS:${domain}") -days 3650 -in "${repo_dir}/udpmod.server.csr" -CA "${repo_dir}/udpmod.ca.crt" -CAkey "${repo_dir}/udpmod.ca.key" -CAcreateserial -out "${repo_dir}/udpmod.server.crt"
    
    systemctl restart udpmod
    echo -e "\e[1;32mDominio actualizado y servicio reiniciado.\e[0m"
    sleep 2
}

estado_servicio() {
    echo -e "\n--- ESTADO DEL SISTEMA ---"
    systemctl is-active --quiet udpmod && echo -e "SERVICIO: \e[1;32mONLINE\e[0m" || echo -e "SERVICIO: \e[1;31mOFFLINE\e[0m"
    echo "--------------------------"
    systemctl status udpmod --no-pager | grep -E "Active:|Main PID:"
    read -p "Presione Enter para volver..."
}

desinstalar_udpmod() {
    echo -e "\e[1;31mEliminando UDPMOD del sistema...\e[0m"
    systemctl stop udpmod
    systemctl disable udpmod
    rm -f /etc/systemd/system/udpmod.service
    systemctl daemon-reload
    rm -rf "$repo_dir"
    echo "Desinstalación completa."
    exit 0
}

# --- LÓGICA DE INSTALACIÓN INICIAL ---
instalar_base() {
    mostrar_banner
    echo "Iniciando instalación inicial..."
    read -p " INGRESA TU DOMINIO PARA LA INSTALACIÓN: " domain
    
    apt update -y; apt upgrade -y; apt install git openssl -y
    
    if [ ! -d "$repo_dir" ]; then
        git clone https://github.com/rudi9999/UDPMOD.git
    fi

    OBFS=$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 8)
    interfas=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
    sys=$(which sysctl)
    ip4t=$(which iptables)
    ip6t=$(which ip6tables)

    # Certificados iniciales
    openssl genrsa -out "${repo_dir}/udpmod.ca.key" 2048
    openssl req -new -x509 -days 3650 -key "${repo_dir}/udpmod.ca.key" -subj "/C=CN/ST=GD/L=SZ/O=Udpmod, Inc./CN=Udpmod Root CA" -out "${repo_dir}/udpmod.ca.crt"
    openssl req -newkey rsa:2048 -nodes -keyout "${repo_dir}/udpmod.server.key" -subj "/C=CN/ST=GD/L=SZ/O=Udpmod, Inc./CN=${domain}" -out "${repo_dir}/udpmod.server.csr"
    openssl x509 -req -extfile <(printf "subjectAltName=DNS:${domain},DNS:${domain}") -days 3650 -in "${repo_dir}/udpmod.server.csr" -CA "${repo_dir}/udpmod.ca.crt" -CAkey "${repo_dir}/udpmod.ca.key" -CAcreateserial -out "${repo_dir}/udpmod.server.crt"

    # Configuración de archivos
    sed -i "s/setobfs/${OBFS}/" "${repo_dir}/config.json"
    sed -i "s#instDir#${dir}#g" "${repo_dir}/config.json"
    sed -i "s#instDir#${dir}#g" "${repo_dir}/udpmod.service"
    sed -i "s#iptb#${interfas}#g" "${repo_dir}/udpmod.service"
    sed -i "s#sysb#${sys}#g" "${repo_dir}/udpmod.service"
    sed -i "s#ip4tbin#${ip4t}#g" "${repo_dir}/udpmod.service"
    sed -i "s#ip6tbin#${ip6t}#g" "${repo_dir}/udpmod.service"

    chmod +x "${repo_dir}/"*
    cp "${repo_dir}/udpmod.service" /etc/systemd/system/
    
    systemctl daemon-reload
    systemctl enable udpmod
    systemctl start udpmod
    
    echo "Instalación finalizada con éxito."
    sleep 2
}

# --- MENÚ PRINCIPAL ---
menu() {
    while true; do
        mostrar_banner
        echo " 1) ACTIVAR / REINICIAR UDPMOD"
        echo " 2) Estado del servicio"
        echo " 3) Cambiar Dominio"
        echo " 4) Cambio de puerto"
        echo " 5) Agregar usuario"
        echo " 6) Eliminar usuario"
        echo " 7) Lista de usuarios"
        echo " 8) Desinstalar UDPMOD"
        echo " 0) Salir"
        echo "=========================================="
        read -p "Seleccione una opción: " opcion

        case $opcion in
            1) systemctl restart udpmod; echo "Servicio reiniciado"; sleep 1 ;;
            2) estado_servicio ;;
            3) configurar_dominio ;;
            4) read -p "Nuevo puerto: " p; sed -i "s/\"port\": .*/\"port\": $p,/" "${repo_dir}/config.json"; systemctl restart udpmod ;;
            5) read -p "Usuario: " u; echo "$u" >> "${repo_dir}/users.db"; echo "Agregado"; sleep 1 ;;
            6) read -p "Usuario a borrar: " u; sed -i "/^$u$/d" "${repo_dir}/users.db"; echo "Eliminado"; sleep 1 ;;
            7) echo "--- USUARIOS ---"; cat "${repo_dir}/users.db" 2>/dev/null || echo "Vacío"; read -p "Enter..." ;;
            8) desinstalar_udpmod ;;
            0) exit 0 ;;
            *) echo "Opción inválida"; sleep 1 ;;
        esac
    done
}

# Ejecución
if [ ! -d "$repo_dir" ]; then
    instalar_base
fi
menu
