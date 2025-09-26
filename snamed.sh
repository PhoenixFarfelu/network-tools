#!/bin/bash
# Script realise par @PhoenixFarfelu
# Valeurs par defaut des variables
expert=false

# Fonction de validation d'adresse IPv4
is_valid_ip() {
    [[ "$1" =~ ^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])$ ]]
}

# Analyse du premier argument
#case `echo "$1" | tr '[:upper:]' '[:lower:]'` in
case "$1" in
"-e" | "--expert")
    expert=true
    ;;&
"-r" | "--remove")
    # Desinstallation d'Apache2
    apt remove --purge bind9 -y
    read -p "Choix du nouveau DNS [129.20.211.22/X.X.X.X] " dns 
    if [[ -z "$dns" ]]; then
        dns="129.20.211.22"
    fi
    until is_valid_ip "$dns"; do
        echo "Adresse IP incorrecte, veuillez réessayer"
        read -p "Choix du nouveau DNS [129.20.211.22/X.X.X.X] " dns 
        if [[ -z "$dns" ]]; then
            dns="129.20.211.22"
        fi
    done
    echo "nameserver ${dns}" > /etc/resolv.conf
    ;;
*)
    # Instalation de bind9
    apt install bind9 -y
    if $expert; then
        read -p "DNS en charde des requetes [129.20.211.22/X.X.X.X] " forwarders
        if [[ -z "$forwarders" ]]; then
            forwarders="129.20.211.22;"
        fi
    else 
        forwarders="129.20.211.22;"
    fi
    until is_valid_ip "$forwarders"; do
        echo "Adresse IP incorrecte, veuillez réessayer"
        read -p "DNS en charde des requetes [129.20.211.22/X.X.X.X] " forwarders
        if [[ -z "$forwarders" ]]; then
            forwarders="129.20.211.22;"
        fi
    done

    # Configuration du DNS relais
    echo "options { 
        directory \"/var/cache/bind\"; 
        allow-query { any; }; 
        forward first; 
        forwarders { 
            ${forwarders}
        }; 
    };" > /etc/bind/named.conf.options

    # Ajout de Logs
    if $expert; then
        read -p "Ajout de Logs ? [Y/n] "
        if [[ -z "$REPLY" || ! "$REPLY" =~ ^([nN][oO]|[nN])$ ]]; then
            echo "logging {
                channel default_syslog {
                    syslog daemon;        // envoie vers le service syslog (facility daemon)
                    severity info;        // niveau info (pour avoir plus que les erreurs)
                    print-time yes;
                    print-severity yes;
                    print-category yes;
                };

                category queries { default_syslog; };  // log des requêtes DNS (queries)
                category default { default_syslog; };  // log par défaut
            };" >> /etc/bind/named.conf.options
        fi

        # Ajout de domaine
        read -p "Ajout de domaine ? [y/N] "
        if [[ -n "$REPLY" || "$REPLY" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            until [[ -n "$domainName" ]]; do
                read -p "nom du domaine (ex:mon.lan) : " domainName
            done

            echo "zone \"$domainName\" {
                type master;
                file \"/etc/bind/db.$domainName\";
            };" > /etc/bind/named.conf.local

            # Creation du fichier de domaine (db.XXX.XXX)
            touch "/etc/bind/db.$domainName"
            echo "
\$TTL 3h
@ IN SOA ns.$domainName. mailaddress.$domainName. (
        2025051901
        6H
        1H
        5D
        1D )
    @ IN NS ns.$domainName.
    @ IN MX 10 mail.$domainName." > "/etc/bind/db.$domainName"
            until is_valid_ip "$ns"; do
                read -p " Adresse ip du server [X.X.X.X] : " ns
            done
            echo "ns A $ns" >> "/etc/bind/db.$domainName"
            
            # Boucle pour ajout d'entrees DNS
            read -p "Ajouter une entrée au DNS ? (y/N)"
            if [[ -n "$REPLY" && "$REPLY" =~ ^([yY][eE][sS]|[yY])$ ]]; then
                endOfEntry=false
            else
                endOfEntry=true
            fi
            until $endOfEntry; do
                until [[ -n "$entryName" ]]; do
                    read -p "Nom de l'entrée à ajouter : " entryName
                done
                until is_valid_ip "$entryIP"; do
                    read -p "Adresse IP à associer : [X.X.X.X] " entryIP
                done
                echo "$entryName A $entryIP" >> "/etc/bind/db.$domainName"
                read -p "Ajouter une autre entrée au DNS ? (y/N)"
                if [[ -z "$REPLY" || "$REPLY" =~ ^([nN][oO]|[nN])$ ]]; then
                    endOfEntry=true
                fi
            done
        fi
    fi

    # Redemarrage du server
    sudo systemctl restart bind9

    # Le server deviens son propre DNS
    echo "nameserver 127.0.0.1" > /etc/resolv.conf
    ;;
esac