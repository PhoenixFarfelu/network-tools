#!/bin/bash
# Valeurs par defaut des variables
expert=false

# Analyse du premier argument
case "$1" in
"-e" | "--expert")
    expert=true
    ;;&
"-r" | "--remove")
    # Desinstallation d'Apache2
    apt purge kea-dhcp4-server -y
    ;;
*)
    # Instalation d'Apache2
    apt install kea-dhcp4-server -y
    if $expert; then
        read -p "Nom de l'interface du service [ETH0/nom] : " interface
        if [[ -z "$interface" ]]; then
            interface="eth0"
        fi
        read -p "Durée de valid-lifetime [691200/durée] : " lifetime
        if [[ -z "$lifetime" ]]; then
            lifetime="691200"
        fi
    fi

    # Configuration generale
    echo "{
    \"Dhcp4\": {
        \"interfaces-config\": {
        \"interfaces\": [\"${interface}\"]
        },
        \"valid-lifetime\": $lifetime,
        \"renew-timer\": 345600,
        \"rebind-timer\": 604800,
        \"authoritative\": true,
        \"lease-database\": {
        \"type\": \"memfile\",
        \"persist\": true,
        \"name\": \"/var/lib/kea/kea-leases4.csv\",
        \"lfc-interval\": 3600
        }," > /etc/kea/kea-dhcp4.conf

    echo '
            "subnet4": [' >> /etc/kea/kea-dhcp4.conf

    # Boucle si plusieurs subnets
    done=false
    until $done; do
        # Configuration du subnet
        read -p "Subnet à definir (X.X.X.X/XX) : " subnet
        read -p "Début de la pool (X.X.X.X) : " poolStart
        read -p "Fin de la pool (X.X.X.X) : " poolEnd
        echo "
            {
                \"subnet\": \"${subnet}\",
                \"pools\": [
                {
                    \"pool\": \"${poolStart} - ${poolEnd}\"
                }
                ],
                \"option-data\": [" >> /etc/kea/kea-dhcp4.conf

        # Ajout DNS
        read -p "Ajout de domain-name-servers ? [N/X.X.X.X] " dns
        if [[ -n "$dns" && ! "$dns" =~ ^([nN][oO]|[nN])$ ]]; then
            echo "
                {
                    \"name\": \"domain-name-servers\",
                    \"data\": \"${dns}\"
                }" >> /etc/kea/kea-dhcp4.conf
        fi

        # Ajout router
        read -p "Ajout de router par défaut ? [N/X.X.X.X] " router
        if [[ -n "$router" && ! "$router" =~ ^([nN][oO]|[nN])$ ]]; then
            echo ",
                {
                    \"name\": \"routers\",
                    \"data\": \"${router}\"
                }" >> /etc/kea/kea-dhcp4.conf
        fi
        echo '
                ]' >> /etc/kea/kea-dhcp4.conf

        # Configuration des adresses reservees (expert only)
        if $expert; then
            read -p "Mettre en place une/des reservation(s) d'adresse ? [y/N] " reservation
            if [[ "$reservation" =~ ^([yY][eE][sS]|[yY])$ ]]; then
                endReservation=false
                until $endReservation; do
                    # Recuperation des variables
                    read -p "Nom de l'appareil (hostname)" name
                    read -p "Adresse MAC : " macAddr
                    read -p "Adresse IP associée : " ipAddr

                    # Ajout de la reservation d'adresse
                    echo ",
                        \"reservations\": [
                        {
                            \"hw-address\": \"${macAddr}\",
                            \"ip-address\": \"${ipAddr}\",
                            \"hostname\": \"${name}\"
                        }" >> /etc/kea/kea-dhcp4.conf

                    # Verification si plusieurs reservations
                    read -p "Mettre en place une autre reservation d'adresse ? [y/N] " reservation
                    if [[ ! "$reservation" =~ ^([yY][eE][sS]|[yY])$ ]]; then
                        endReservation=true
                    fi
                done
                echo '
                    ]' >> /etc/kea/kea-dhcp4.conf
            fi
        fi

        # Fermeture du subnet
        echo '
            }' >> /etc/kea/kea-dhcp4.conf
        
        # SI mise en place de plusieurs sites
        valid=false
        until $valid; do
            read -p "Configurer un autre subnet ? [y/N] : " autreSubnet
            # Ajout d'une valeur par defaut
            if [[ -z "$autreSubnet" ]]; then
                autreSubnet="no"
            fi

            # Analyse de la reponse
            case $autreSubnet in
            [yY][eE][sS]|[yY])
                valid=true
                # Ajout de separation entre les deux subnets
                echo ',' >> /etc/kea/kea-dhcp4.conf
                ;;
            [nN][oO]|[nN])
                valid=true
                done=true
                ;;
            esac
        done
    done

    # Fermeture du bloc subnet4
    echo '
            ]' >> /etc/kea/kea-dhcp4.conf
    
    # Mise en place de logs (possible ajout de details plus tard)
    if $expert; then
        read -p "Mettre en place des logs ? [y/N] " logs
        if [[ "$logs" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            echo ", 
                \"loggers\": [
                {
                    \"name\": \"kea-dhcp4\",
                    \"output_options\": [
                    {
                        \"output\": \"syslog\"
                    }
                    ],
                    \"severity\": \"INFO\",
                    \"debuglevel\": 0
                }
                ]" >> /etc/kea/kea-dhcp4.conf
        fi
    fi

    # Fermeture du service
    echo '
    }
    }' >> /etc/kea/kea-dhcp4.conf
esac