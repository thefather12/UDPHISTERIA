#!/bin/bash

# --- CONFIGURACIÓN DE RUTAS ---
# Usamos una ruta fija para evitar errores de "File not found"
export dir="/root"
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
    echo -e "       GESTOR DE SERVIDOR UDP"
    echo "=========================================="
}

estado_servicio() {
    echo -e "\n--- ESTADO DEL SISTEMA ---"
    if systemctl is-active --quiet udpmod; then
        echo -e "SERVICIO: \e[1;32mONLINE (ACTIVO)\e[0m"
    else
        echo -e "SERVICIO: \e[1;31mOFFLINE (FALLÓ)\e[0m"
        echo -e "\e[1;33mLOG DE ERROR:\e[0m"
        journalctl -u udpmod --no-pager -n 10 | grep -i "error"
    fi
    echo "--------------------------"
    systemctl status udpmod --no-pager | grep -E "Active:|Main PID:"
    read -p "Presione Enter para volver..."
}

configurar_dominio() {
    read -p " INGRESA TU NUEVO DOMINIO: " domain
    [[ -z "$domain" ]] && return
    
    echo "Regenerando certificados..."
    openssl req -newkey rsa:2048 -nodes -keyout "${repo_dir}/udpmod.server.key" -subj "/C=CN/ST=GD/L=SZ/O=Udpmod, Inc./CN=${domain}" -out "${repo_dir}/udpmod.server.csr"
    openssl x509 -req -extfile <(printf "subjectAltName=DNS:${domain},DNS:${domain}") -days 3650 -in "${repo_dir}/udpmod.server.csr" -CA "${repo_dir}/udpmod.ca.crt" -CAkey "${repo_dir}/udpmod.ca.key" -CAcreateserial -out "${repo_dir}/udpmod.server.crt"
    
    systemctl restart udpmod
    echo "Dominio actualizado."
    sleep 2
}

instalar_base() {
    mostrar_banner
    echo "Iniciando instalación inicial en $dir..."
    read -p " INGRESA TU DOMINIO: " domain
    
    apt update -y; apt install git openssl -y
    
    cd $dir
    [[ -d "$repo_dir" ]] && rm -rf "$repo_dir"
    git clone https://github.com/rudi9999/UDPMOD.git
    
    OBFS=$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 8)
    interfas=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
    
    # Generar Certificados
    openssl genrsa -out "${repo_dir}/udpmod.ca.key" 2048
    openssl req -new -x509 -days 3650 -key "${repo_dir}/udpmod.ca.key" -subj "/C=CN/ST=GD/L=SZ/O=Udpmod, Inc./CN=Udpmod Root CA" -out "${repo_dir}/udpmod.ca.crt"
    openssl req -newkey rsa:2048 -nodes -keyout "${repo_dir}/udpmod.server.key" -subj "/C=CN/ST=GD/L=SZ/O=Udpmod, Inc./CN=${domain}" -out "${repo_dir}/udpmod.server.csr"
    openssl x509 -req -extfile <(printf "subjectAltName=DNS:${domain},DNS:${domain}") -days 3650 -in "${repo_dir}/udpmod.server.csr" -CA "${repo_dir}/udpmod.ca.crt" -CAkey "${repo_dir}/udpmod.ca.key" -CAcreateserial -out "${repo_dir}/udpmod.server.crt"

    # Configurar archivos con rutas absolutas
    sed -i "s/setobfs/${OBFS}/" "${repo_dir}/config.json"
    sed -i "s#instDir#${repo_dir}#g" "${repo_dir}/config.json"
    sed -i "s#instDir#${repo_dir}#g" "${repo_dir}/udpmod.service"
    sed -i "s#iptb#${interfas}#g" "${repo_dir}/udpmod.service"
    
    # IMPORTANTE: Asegurar permisos del binario
    chmod +x "${repo_dir}/"*
    chmod 755 "${repo_dir}/udpmod" # Asumiendo que el binario se llama udpmod
    
    cp "${repo_dir}/udpmod.service" /etc/systemd/system/
    
    systemctl daemon-reload
    systemctl enable udpmod
    systemctl restart udpmod
    
    echo "Instalación completada."
    sleep 2
}

# --- MENÚ PRINCIPAL ---
menu() {
    while true; do
        mostrar_banner
        echo " 1) ACTIVAR / REINICIAR SERVICIO"
        echo " 2) ESTADO DEL SERVICIO"
        echo " 3) CAMBIAR DOMINIO"
        echo " 4) CAMBIAR PUERTO"
        echo " 5) AGREGAR USUARIO"
        echo " 6) ELIMINAR USUARIO"
        echo " 7) LISTA DE USUARIOS"
        echo " 8) DESINSTALAR"
        echo " 0) SALIR"
        echo "=========================================="
        read -p "Seleccione una opción: " opcion

        case $opcion in
            1) systemctl daemon-reload; systemctl restart udpmod; echo "Reiniciado"; sleep 1 ;;
            2) estado_servicio ;;
            3) configurar_dominio ;;
            4) read -p "Nuevo puerto: " p; sed -i "s/\"listen\": \":.*\"/\"listen\": \":$p\"/" "${repo_dir}/config.json"; systemctl restart udpmod ;;
            5) read -p "Nombre usuario: " u; echo "$u" >> "${repo_dir}/users.db"; echo "Usuario Guardado"; sleep 1 ;;
            6) read -p "Usuario a borrar: " u; sed -i "/^$u$/d" "${repo_dir}/users.db"; echo "Eliminado"; sleep 1 ;;
            7) echo -e "\n--- LISTA ---"; cat "${repo_dir}/users.db" 2>/dev/null || echo "Sin usuarios"; read -p "Enter..." ;;
            8) systemctl stop udpmod; rm /etc/systemd/system/udpmod.service; rm -rf "$repo_dir"; exit 0 ;;
            0) exit 0 ;;
            *) echo "Opción no válida"; sleep 1 ;;
        esac
    done
}

# Ejecución inicial
if [ ! -f "/etc/systemd/system/udpmod.service" ]; then
    instalar_base
fi
menu

