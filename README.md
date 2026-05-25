# Market Manifest — Despliegue en Kubernetes (AWS EC2)

Repositorio de manifiestos Kubernetes y documentacion para el despliegue del **Marketplace Turistico** en un cluster K8s sobre AWS EC2.

---

## Prerrequisitos

- **Docker Desktop** instalado localmente
- **kubectl** configurado contra el cluster K8s
- **Cluster Kubernetes** en AWS EC2 (kubeadm, k3s, o EKS)
- Cuenta en **Docker Hub** (o el registro de contenedores que uses)

---

## 1. Construir y subir imagenes Docker

Primero, clona los repositorios de aplicacion:

```bash
git clone https://github.com/tian-net/AS242S4_PII_T05-be.git
git clone https://github.com/tian-net/AS242S4_PII_T05-fe.git
```

### Backend (Flask + Gunicorn)

```bash
docker build -f backend/Dockerfile \
  -t docker.io/tu-usuario/market-backend:latest \
  ./ruta/a/AS242S4_PII_T05-be

docker push docker.io/tu-usuario/market-backend:latest
```

### Frontend (React + Vite + Nginx)

```bash
docker build -f frontend/Dockerfile \
  -t docker.io/tu-usuario/market-frontend:latest \
  ./ruta/a/AS242S4_PII_T05-fe

docker push docker.io/tu-usuario/market-frontend:latest
```

### MongoDB (imagen personalizada o usar la oficial)

```bash
# Opcion 1: Usar la imagen oficial directamente (no requiere build)
docker pull mongo:7

# Opcion 2: Construir imagen personalizada
docker build -f mongo/Dockerfile \
  -t docker.io/tu-usuario/market-mongodb:latest \
  ./ruta/a/tu-config-mongo

docker push docker.io/tu-usuario/market-mongodb:latest
```

> **Nota:** Reemplaza `tu-usuario` por tu nombre de usuario de Docker Hub.  
> Si usas otro registro (ECR, GHCR), actualiza las referencias en los archivos `k8s/*-deployment.yaml`.

---

## 2. Configurar el Backend para entorno K8s

Antes de construir la imagen, asegurate de que el backend lea la variable de entorno `MONGO_URI`:

```python
# app/config.py
import os

MONGO_URI = os.getenv("MONGO_URI", "mongodb://localhost:27017/tourism_marketplace")
DB_NAME = "tourism_marketplace"
```

Agrega `gunicorn` a `requirements.txt`:

```
gunicorn
```

---

## 3. Desplegar en Kubernetes

```bash
# Crear namespace y todos los recursos
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/

# Verificar el estado
kubectl get all -n marketplace
```

El orden de creacion no importa, pero por claridad los recursos se aplican en este orden:

1. `k8s/namespace.yaml` — Namespace `marketplace`
2. `k8s/mongodb-pvc.yaml` — Volumen persistente 5Gi
3. `k8s/mongodb-deployment.yaml` — MongoDB 1 replica
4. `k8s/mongodb-service.yaml` — Servicio interno MongoDB
5. `k8s/backend-deployment.yaml` — Backend Flask 2 replicas
6. `k8s/backend-service.yaml` — Servicio interno Backend
7. `k8s/frontend-deployment.yaml` — Frontend React 2 replicas
8. `k8s/frontend-service.yaml` — LoadBalancer publico

---

## 4. Acceder a la aplicacion

```bash
kubectl get svc frontend-service -n marketplace
```

Toma el `EXTERNAL-IP` del LoadBalancer y abrelo en el navegador.

Si estas usando un entorno on-premise o kubeadm sin LoadBalancer, cambia el Service a `type: NodePort`:

```bash
kubectl patch svc frontend-service -n marketplace -p '{"spec":{"type":"NodePort"}}'
```

Luego accede via `http://<EC2-PUBLIC-IP>:<NODE-PORT>`.

---

## 5. Comandos utiles

```bash
# Ver todos los recursos
kubectl get all -n marketplace

# Logs de un pod
kubectl logs -n marketplace -l app=backend
kubectl logs -n marketplace -l app=frontend
kubectl logs -n marketplace -l app=mongodb

# Escalar servicios
kubectl scale deployment backend -n marketplace --replicas=3
kubectl scale deployment frontend -n marketplace --replicas=3

# Eliminar todo
kubectl delete namespace marketplace

# Eliminar solo el despliegue (conserva datos MongoDB)
kubectl delete -f k8s/backend-deployment.yaml
kubectl delete -f k8s/frontend-deployment.yaml
```

---

## 6. Resolver problemas comunes

| Problema | Causa posible | Solucion |
|----------|---------------|----------|
| Backend no conecta a MongoDB | `MONGO_URI` incorrecta | Verificar env en `backend-deployment.yaml` |
| Frontend muestra 502 | Nginx no resuelve `backend-service` | Verificar que el backend este corriendo |
| MongoDB no arranca | PVC sin storage class | Configurar StorageClass o usar hostPath |
| LoadBalancer sin External-IP | Cluster on-premise sin metalLB | Cambiar a `type: NodePort` |

---

## 7. Arquitectura

```
Usuario → LoadBalancer (frontend-service:80)
              ↓
         [Nginx Pod]
              ↓  /api/ → backend-service:8000
         [Flask Gunicorn Pod]
              ↓  mongodb://mongodb-service:27017
         [MongoDB Pod]
              ↓
         [PVC 5Gi]
```

Cada componente esta aislado en su propio Pod dentro del namespace `marketplace`.  
Las comunicaciones internas usan los nombres de servicio de Kubernetes.
