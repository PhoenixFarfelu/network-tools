# INIT
red='\e[0;31m'
green='\e[0;32m'
orange='\e[0;33m'
blue='\e[1;34m'
purple='\e[0;35m'
reset='\e[0m'
networks=""
targets=""

# Get default DNS
dns1=`cat /etc/resolv.conf | awk '/nameserver/' $1 | cut -d' ' -f2 | head -n1`
dns2=`cat /etc/resolv.conf | awk '/nameserver/' $1 | cut -d' ' -f2 | head -n2 | tail -n1`
if [[ "$dns1" == "$dns2" ]]; then
    dns2=""
fi
echo -e "${blue}------------- DNS -------------${reset}"
echo -e "PRIMARY DNS :   ${purple}$dns1${reset}"
if [[ -n "$dns2" ]]; then
    echo -e "SECONDARY DNS : ${purple}$dns2${reset}"
fi
echo -e "${blue}---------- ADDRESSES ----------${reset}"
for iface in `ip a | awk '/</' $1 | cut -d' ' -f2 | cut -d':' -f1`; do
    # Get IPs
    inet=`ip a ls $iface | awk '/inet /' $1 | grep "((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])/([1-9]|1[0-9]|2[0-9]|3[0-2])" -oE`
    inet6=`ip a ls $iface | awk '/inet6 /' $1 | grep "(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))" -oE`
    if [[ -z `ip a ls $iface | awk '/loopback/' $1 ` ]]; then
        networks=`echo -e "$networks\n$inet"`
    else
        targets=`echo -e "$targets\n$inet"`
    fi
    inet=`echo -e $inet | sed "s/ /\x1b[0m, \x1b[35m/"`
    inet6=`echo -e $inet6 | sed "s/ /\x1b[0m, \x1b[35m/"`
    # Get MAC
    mac=`ip addr ls $iface | awk '/link\//' $1 | grep "([0-9a-f]{2}:){5}[0-9a-f]{2}" -oE | head -n1`
    # Get state
    state=`ip a ls $iface | awk '/state/' $1 | cut -d' ' -f9`
    if [[ $state == "UP" ]]; then
        state="${green}$state${reset}"
    fi
    if [[ $state == "DOWN" ]]; then
        state="${red}$state${reset}"
    fi
    echo -e "${orange}$iface${reset} :
        IP adress :  ${purple}${inet}${reset} and ${purple}$inet6${reset}
        MAC adress : ${orange}$mac${reset}
        state : $state"
done
echo -e "${blue}----------- ROUTING -----------${reset}"
defaultGateway=`ip route | awk '/default/' $1 | cut -d' ' -f3`
defaultGatewayIface=`ip route | awk '/default/' $1 | cut -d' ' -f5`
echo -e "Default route throught ${orange}$defaultGatewayIface${reset} towards ${purple}$defaultGateway${reset}"

# Network scan
echo -e "${blue}------------ SCANS ------------${reset}"
networks=`echo -e "$networks" | tail -n+2`
targets=`echo -e "$targets" | tail -n+2 | awk "/\/32/" | cut -d"/" -f1`
# echo "NETWORKS : $networks"
# echo "TARGETS : $targets"
for network in $networks; do
    scan=`nmap -sn $network | awk "/scan report/ $1"`
    while IFS= read -r line; do
        name=`echo "$line" | cut -d" " -f5`
        ip=`echo "$line" | cut -d" " -f6 | cut -c2- | rev | cut -c2- | rev`
        if [[ -z "$ip" ]]; then
            echo -e "found ${purple}$name${reset}"
        else
            echo -e "found ${orange}$name${reset} at ${purple}$ip${reset}"
        fi
        targets=`echo -e "$targets\n$ip"`
    done <<< "$scan"
done
# targets=`echo -e "$targets" | tail -n+2`
# echo "NETWORKS : $networks"
# echo "TARGETS : $targets"
for target in $targets; do
    # echo -e "\nScan de $target"
    nmap=`nmap $target | tail -n+2 | head -n -1 | sed "s/open/\x1b[32mopen\x1b[0m/" | sed "s/$target/\x1b[35m$target\x1b[0m/"`
    name=`echo "$nmap" | head -n1 | cut -d" " -f5`
    # echo "NAME : $name"
    if [[ "$name" != "$target" ]]; then
        nmap=`echo "$nmap" | sed "s/$name/\x1b[33m$name\x1b[0m/"`
    fi
    echo -e "\n$nmap"
done