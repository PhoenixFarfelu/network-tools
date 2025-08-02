#!/bin/bash
# Valeurs par defaut des variables
expert=false

# Analyse du premier argument
#case `echo "$1" | tr '[:upper:]' '[:lower:]'` in
case "$1" in
"-e" | "--expert")
    expert=true
    ;;&
"-r" | "--remove")
    # Desinstallation d'Apache2
    apt purge apache2 -y
    ;;
*)
    # Instalation d'Apache2
    apt install apache2 -y

    # Desactivation du site par defaut
    a2dissite 000-default.conf

    # Creation des differentes pages
    done=false
    until $done
    do
        # Recuperation des variables (page, port, docroot)
        read -p "Nom de la page à créer : " page
        chemin_absolu="/etc/apache2/sites-available/${page}.conf"
        if $expert; then
            read -p "Numero de port [80/num] : " port
            if [[ -z "$port" ]]; then
                port="80"
            fi
            if [[ "$port" != "80" ]]; then
                # Modification des ports d'ecoute
                echo "Listen ${port}" >> /etc/apache2/ports.conf
            fi
            read -p "DocumentRoot : [DEFAULT/chemin_absolu] : " docroot
            if [[ -z "$docroot" ]]; then
                docroot="/var/www/${page}"
            fi 
        else
            port="80"
            docroot="/var/www/${page}"
        fi

        # Modification du fichier de configuration
        touch $chemin_absolu
        echo "<VirtualHost *:${port}>" > "$chemin_absolu"
        echo "	ServerAdmin webmaster@localhost" >> "$chemin_absolu"
        echo "	DocumentRoot ${docroot}" >> "$chemin_absolu"
        echo "	ErrorLog \${APACHE_LOG_DIR}/${page}.log" >> "$chemin_absolu"
        # Mise en place des fonctionnalites expertes
        if $expert
        then
            read -p "Ajout de CustomLog ? [Y/n] "
            if [[ -z "$REPLY" || "$REPLY" =~ ^([yY][eE][sS]|[yY])$ ]]
            then
                echo "	CustomLog \"|/usr/bin/logger -t apache2\" combined" >> "$chemin_absolu"
            fi
            read -p "Ajout de ServerName ? [N/ServerName] " servername
            if [[ -n "$REPLY" && ! "$REPLY" =~ ^([nN][oO]|[nN])$ ]]
            then
                echo "	ServerName ${servername}" >> "$chemin_absolu"
            fi
            read -p "Ajout de ServerAlias ? [N/ServerAlias] " serveralias
            if [[ -n "$REPLY" && ! "$REPLY" =~ ^([nN][oO]|[nN])$ ]]
            then
                echo "	ServerAlias ${serveralias}" >> "$chemin_absolu"
            fi
        fi
        echo "</VirtualHost>" >> "$chemin_absolu"

        # Creation du site
        mkdir -p "${docroot}"
        touch "${docroot}/index.html"
        echo "<html><body><h1>Bienvenu sur ${page}</h1></body></html>" > "${docroot}/index.html"

        # Activation du site
        a2ensite "${page}"

        # SI mise en place de plusieurs sites
        valid=false
        until $valid
        do
            read -p "Configurer un autre site ? [y/N] : " autreSite
            # Ajout d'une valeur par defaut
            if [[ -z "$autreSite" ]]; then
                autreSite="no"
            fi

            # Analyse de la reponse
            case $autreSite in
            [yY][eE][sS]|[yY])
                valid=true
                ;;
            [nN][oO]|[nN])
                valid=true
                done=true
                ;;
            esac
        done
    done

    # Redemarrage du serveur
    systemctl restart apache2
    ;;
esac

# Affichage du status d'Apache
systemctl status apache2

# Mise en place des noms de domaines
#echo "www.site1 CNAME serveur" >> /etc/bind/db.mon.lan
#echo "www.site2 CNAME serveur" >> /etc/bind/db.mon.lan

#systemctl restart named
# Script realise par @PhoenixFarfelu