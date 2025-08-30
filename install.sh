#!/bin/bash
set -e

REPO_BASE="https://raw.githubusercontent.com/PhoenixFarfelu/network-tools/main"
INSTALL_DIR="/usr/local/bin"
#Outils disponibles : "sapache2" "skea" "snamed"
TOOLS=("sapache2" "skea" "snamed")

echo "[*] Installation des outils de déploiement réseau..."

for tool in "${TOOLS[@]}"; do
  echo "  ↪ Téléchargement de $tool..."
  curl -sSL "$REPO_BASE/$tool.sh" -o "$tool"
  chmod +x "$tool"
  echo "  ↪ Installation dans $INSTALL_DIR..."
  sudo mv "$tool" "$INSTALL_DIR/$tool"
done

echo "[✔] Tous les outils ont été installés avec succès."
