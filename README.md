# Market Manifest — Despliegue en EC2 (Ubuntu 24.04)

Repositorio con scripts y configuracion para desplegar el **Marketplace Turistico** en **3 instancias EC2 t3.medium** con Ubuntu 24.04, una para cada componente:

| Instancia | Componente | Stack |
|-----------|-----------|-------|
| EC2 #1 | Base de Datos | MongoDB 7 |
| EC2 #2 | Backend | Flask + Gunicorn + Python 3.11 |
| EC2 #3 | Frontend | React + Vite + Nginx |

---

## Arquitectura

```
Usuario → http://<FRONTEND_PUBLIC_IP>:80
              ↓
         [Nginx]
         Servir SPA (React build)
              ↓  /api/ → http://<BACKEND_PRIVATE_IP>:8000
         [Gunicorn]
         Flask API
              ↓  mongodb://<MONGO_PRIVATE_IP>:27017
         [MongoDB 7]
```

Las instancias se comunican por **IPs privadas** de AWS (misma VPC / security groups).

---

## Security Groups (AWS)

| Grupo | Reglas |
|-------|--------|
| **MongoDB SG** | Puerto `27017` desde IP privada del Backend |
| **Backend SG** | Puerto `8000` desde IP privada del Frontend |
| **Frontend SG** | Puerto `80` desde `0.0.0.0/0` (HTTP publico) |
| **SSH** | Puerto `22` desde tu IP (en los 3) |

---

## 1. Instancia MongoDB

```bash
# 1. Clonar este repo
git clone https://github.com/tian-net/market-manifest.git
cd market-manifest

# 2. Ejecutar setup
chmod +x mongo/setup.sh
sudo ./mongo/setup.sh

# 3. Verificar
sudo systemctl status mongod
```

Anotar la **IP privada** de esta instancia — la necesitaras para el backend.

---

## 2. Instancia Backend

```bash
# 1. Clonar este repo
git clone https://github.com/tian-net/market-manifest.git
cd market-manifest

# 2. Ejecutar setup pasando la IP privada de MongoDB
chmod +x backend/setup.sh
sudo ./backend/setup.sh <MONGO_PRIVATE_IP>

# Ejemplo: sudo ./backend/setup.sh 10.0.1.50

# 3. Verificar
sudo systemctl status backend
curl http://localhost:8000/
```

Anotar la **IP privada** de esta instancia — la necesitaras para el frontend.

---

## 3. Instancia Frontend

```bash
# 1. Clonar este repo
git clone https://github.com/tian-net/market-manifest.git
cd market-manifest

# 2. Ejecutar setup pasando la IP privada del Backend
chmod +x frontend/setup.sh
sudo ./frontend/setup.sh <BACKEND_PRIVATE_IP>

# Ejemplo: sudo ./frontend/setup.sh 10.0.1.100

# 3. Verificar
curl http://localhost/
```

Abrir en el navegador: `http://<FRONTEND_PUBLIC_IP>`

---

## Setup manual (si prefieres no usar los scripts)

### MongoDB

```bash
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
  sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor
echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | \
  sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
sudo apt-get update -y
sudo apt-get install -y mongodb-org
sudo sed -i 's/127.0.0.1/0.0.0.0/' /etc/mongod.conf
sudo systemctl enable mongod && sudo systemctl start mongod
```

### Backend

```bash
sudo apt-get install -y python3 python3-pip python3-venv git
git clone https://github.com/vallegrande/AS242S4_PII_T05-be.git /home/ubuntu/backend
cd /home/ubuntu/backend
python3 -m venv venv
source venv/bin/activate
pip install gunicorn flask flask-cors pymongo email-validator python-dotenv
echo "MONGO_URI=mongodb://<MONGO_IP>:27017/tourism_marketplace" > .env
gunicorn --bind 0.0.0.0:8000 --workers 4 run:app
```

### Frontend

```bash
sudo apt-get install -y nginx git curl
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
git clone https://github.com/vallegrande/AS242S4_PII_T05-fe.git /home/ubuntu/frontend
cd /home/ubuntu/frontend
echo "VITE_API_BASE_URL=/api/v1" > .env
npm install && npm run build
sudo cp -r dist/* /var/www/html/
sudo cp nginx.conf /etc/nginx/sites-available/default
sudo sed -i 's/<BACKEND_IP>/<TU_BACKEND_IP>/' /etc/nginx/sites-available/default
sudo systemctl restart nginx
```

---

## Comandos utiles para las 3 instancias

```bash
# Ver logs del backend
sudo journalctl -u backend -f

# Ver logs de Nginx
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# Ver logs de MongoDB
sudo journalctl -u mongod -f

# Probar backend localmente
curl http://localhost:8000/

# Probar frontend localmente
curl http://localhost/

# Test de conexion backend -> mongo
curl http://localhost:8000/api/v1/partners/

# Reiniciar servicios
sudo systemctl restart backend
sudo systemctl restart nginx
sudo systemctl restart mongod
```

---

## Actualizar codigo (en cada instancia)

```bash
cd /home/ubuntu/backend   # o /home/ubuntu/frontend
git pull origin develop
source venv/bin/activate  # solo backend
pip install -r requirements.txt  # solo backend
npm install && npm run build  # solo frontend
sudo systemctl restart backend  # solo backend
sudo systemctl restart nginx    # solo frontend
```

---

## Alternativa: Despliegue con Docker / Kubernetes

Este repositorio tambien incluye:

- `backend/Dockerfile` — imagen Docker del backend
- `frontend/Dockerfile` — imagen Docker del frontend
- `k8s/` — manifiestos para desplegar en Kubernetes

Ver la seccion `k8s/README.md` o la documentacion de Kubernetes para mas detalles.
