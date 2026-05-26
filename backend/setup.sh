#!/bin/bash
set -e

# ============================================================
# Backend - Setup para Ubuntu 24.04 (t3.medium)
# Ejecutar en la instancia EC2 destinada al Backend
# ============================================================

MONGO_IP="${1:-<MONGO_PRIVATE_IP>}"

echo "=== Instalando Backend ==="
echo "MONGO_IP: $MONGO_IP"

# 1. Dependencias del sistema
sudo apt-get update -y
sudo apt-get install -y python3 python3-pip python3-venv git

# 2. Clonar repositorio del backend
cd /home/ubuntu
git clone https://github.com/vallegrande/AS242S4_PII_T05-be.git backend
cd backend

# 3. Entorno virtual y dependencias
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install gunicorn flask flask-cors pymongo email-validator python-dotenv

# 4. Crear archivo .env
cat > .env << EOF
MONGO_URI=mongodb://${MONGO_IP}:27017/tourism_marketplace
EOF

# 5. Systemd service
sudo tee /etc/systemd/system/backend.service << SERVEOF
[Unit]
Description=Marketplace Backend (Gunicorn)
After=network.target

[Service]
User=ubuntu
Group=ubuntu
WorkingDirectory=/home/ubuntu/backend
EnvironmentFile=/home/ubuntu/backend/.env
ExecStart=/home/ubuntu/backend/venv/bin/gunicorn --bind 0.0.0.0:8000 --workers 4 run:app
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVEOF

# 6. Iniciar servicio
sudo systemctl daemon-reload
sudo systemctl enable backend
sudo systemctl start backend

echo ""
echo "=== Backend desplegado en puerto 8000 ==="
echo ""
echo "Comandos utiles:"
echo "  sudo systemctl status backend"
echo "  sudo journalctl -u backend -f"
