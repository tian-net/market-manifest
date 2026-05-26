# Despliegue Multi-Cluster - Market App

Arquitectura: 3 instancias EC2 independientes, cada una con Minikube.

| Cluster | EC2 | Servicio | Puerto Expuesto |
|---------|-----|----------|----------------|
| MongoDB | EC2-1 | MongoDB 7 | 27017 (ClusterIP + port-forward host:27017) |
| Backend | EC2-2 | Flask + Gunicorn | 30002 (NodePort) |
| Frontend | EC2-3 | React + Vite + Nginx | 30081 (NodePort) |

Namespace comun: `marketplace`

---

## 1. Prerequisitos (en cada EC2)

```bash
# Ubuntu 24.04 - t3.medium
sudo apt update && sudo apt install -y docker.io
sudo usermod -aG docker $USER && newgrp docker

# Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

minikube start --driver=docker
```

## 2. Orden de Despliegue

### Paso 1: Cluster MongoDB (EC2-1)

```bash
git clone https://github.com/tian-net/market-manifest.git
cd market-manifest

kubectl apply -f mongo-cluster/marketplace-namespace.yaml
kubectl apply -f mongo-cluster/mongo-deployment.yaml
kubectl apply -f mongo-cluster/mongo-service.yaml

# Exponer MongoDB fuera del cluster (Minikube Docker driver)
kubectl port-forward -n marketplace service/mongo-service 27017:27017 --address 0.0.0.0 &

# Anotar IP publica de EC2-1
curl ifconfig.me   # <MONGO_EC2_IP>
```

### Paso 2: Cluster Backend (EC2-2)

Antes de desplegar, editar `backend-cluster/backend-deployment.yaml`:
- Reemplazar `<MONGO_EC2_IP>` con la IP publica de EC2-1

```bash
git clone https://github.com/tian-net/market-manifest.git
cd market-manifest

# Editar la IP en backend-deployment.yaml
sed -i 's/<MONGO_EC2_IP>/REEMPLAZAR_CON_IP_EC2_MONGO/g' backend-cluster/backend-deployment.yaml

kubectl apply -f backend-cluster/marketplace-namespace.yaml
kubectl apply -f backend-cluster/backend-deployment.yaml
kubectl apply -f backend-cluster/backend-service.yaml

# Exponer Backend
kubectl port-forward -n marketplace service/backend-service 30002:8000 --address 0.0.0.0 &

# Verificar
curl http://localhost:30002/api/v1/partners/
```

### Paso 3: Cluster Frontend (EC2-3)

Antes de construir la imagen, clonar el frontend y construir con la IP publica de EC2-2:

```bash
git clone https://github.com/tian-net/AS242S4_PII_T05-fe.git
cd AS242S4_PII_T05-fe

# Construir imagen con la IP de EC2-2
docker build \
  --build-arg VITE_API_BASE_URL=http://<EC2-2_IP>:30002/api/v1 \
  -t tian11qb/market-frontend:latest .

docker push tian11qb/market-frontend:latest

# Desplegar manifiestos
cd ..
git clone https://github.com/tian-net/market-manifest.git
cd market-manifest

kubectl apply -f frontend-cluster/marketplace-namespace.yaml
kubectl apply -f frontend-cluster/frontend-deployment.yaml
kubectl apply -f frontend-cluster/frontend-service.yaml

# Exponer Frontend
kubectl port-forward -n marketplace service/frontend-service 30081:80 --address 0.0.0.0 &
```

## 3. Verificacion

```bash
# Estado general
kubectl get all -n marketplace

# EC2-1: MongoDB
kubectl logs -n marketplace deployment/mongo-deployment

# EC2-2: Backend
curl http://localhost:30002/api/v1/partners/

# EC2-3: Frontend
curl http://localhost:30081
```

## 4. Security Groups (AWS)

| EC2 | Puerto | Origen | Descripcion |
|-----|--------|--------|-------------|
| EC2-1 (Mongo) | 27017 | IP privada de EC2-2 | MongoDB desde Backend |
| EC2-2 (Backend) | 30002 | 0.0.0.0/0 | API REST |
| EC2-3 (Frontend) | 30081 | 0.0.0.0/0 | Frontend React |

## 5. Limpieza

```bash
minikube delete --all
```
