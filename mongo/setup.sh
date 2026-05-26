#!/bin/bash
set -e

# ============================================================
# MongoDB 7 - Setup para Ubuntu 24.04 (t3.medium)
# Ejecutar en la instancia EC2 destinada a la base de datos
# ============================================================

echo "=== Instalando MongoDB 7 ==="

# 1. Importar GPG key
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
  sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor 2>/dev/null

# 2. Agregar repositorio
echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | \
  sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list

# 3. Instalar MongoDB
sudo apt-get update -y
sudo apt-get install -y mongodb-org

# 4. Permitir conexiones remotas (bind 0.0.0.0)
sudo sed -i 's/127.0.0.1/0.0.0.0/' /etc/mongod.conf

# 5. Iniciar servicio
sudo systemctl enable mongod
sudo systemctl start mongod

echo ""
echo "=== MongoDB 7 instalado y corriendo ==="
echo "URI interna: mongodb://<PRIVATE-IP-DE-ESTA-INSTANCIA>:27017/tourism_marketplace"
echo ""
echo "Usa este comando para verificar:"
echo "  sudo systemctl status mongod"
