#!/bin/bash
set -e

# ============================================================
# Frontend - Setup para Ubuntu 24.04 (t3.medium)
# Ejecutar en la instancia EC2 destinada al Frontend
# ============================================================

BACKEND_IP="${1:-<BACKEND_PRIVATE_IP>}"

echo "=== Instalando Frontend ==="
echo "BACKEND_IP: $BACKEND_IP"

# 1. Instalar Nginx y Node.js 20
sudo apt-get update -y
sudo apt-get install -y nginx git curl

curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# 2. Clonar repositorio del frontend
cd /home/ubuntu
git clone https://github.com/vallegrande/AS242S4_PII_T05-fe.git frontend
cd frontend

# 3. Configurar .env con URL relativa (usa nginx como proxy)
echo "VITE_API_BASE_URL=/api/v1" > .env

# 4. Build
npm install
npm run build

# 5. Copiar build a directorio de Nginx
sudo cp -r dist/* /var/www/html/

# 6. Configurar Nginx con la IP del backend
sudo cp nginx.conf /etc/nginx/sites-available/default
sudo sed -i "s/<BACKEND_IP>/${BACKEND_IP}/g" /etc/nginx/sites-available/default

sudo systemctl restart nginx

echo ""
echo "=== Frontend desplegado en puerto 80 ==="
echo ""
echo "Comandos utiles:"
echo "  sudo systemctl status nginx"
echo "  sudo nginx -t"
