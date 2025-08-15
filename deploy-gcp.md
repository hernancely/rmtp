# Despliegue del Servidor RTMP en Google Cloud Platform

## Script de Despliegue Automático

Para desplegar automáticamente el servidor RTMP en GCP, usar el script `deploy-gcp.sh`:

```bash
# 1. Configurar PROJECT_ID en el script
nano deploy-gcp.sh
# Cambiar "your-project-id" por tu ID de proyecto real

# 2. Dar permisos de ejecución
chmod +x deploy-gcp.sh

# 3. Ejecutar el despliegue
./deploy-gcp.sh
```

El script automáticamente:
- ✅ Configura el proyecto GCP
- ✅ Crea reglas de firewall
- ✅ Crea la instancia VM
- ✅ Instala Docker y dependencias
- ✅ Transfiere archivos del proyecto
- ✅ Inicia el servidor RTMP

## Despliegue Manual (Alternativo)

### Preparativos

### 1. Crear VM en GCP

```bash
# Crear instancia VM
gcloud compute instances create rtmp-server \
    --zone=us-central1-a \
    --machine-type=e2-medium \
    --network-tier=PREMIUM \
    --maintenance-policy=MIGRATE \
    --service-account=default \
    --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.read,https://www.googleapis.com/auth/trace.append \
    --image=ubuntu-2204-jammy-v20231030 \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size=20GB \
    --boot-disk-type=pd-standard \
    --boot-disk-device-name=rtmp-server \
    --metadata-from-file startup-script=startup-script.sh
```

### 2. Configurar Reglas de Firewall

```bash
# Permitir tráfico HTTP (puerto 80)
gcloud compute firewall-rules create allow-http-rtmp \
    --allow tcp:80 \
    --source-ranges 0.0.0.0/0 \
    --description "Allow HTTP traffic for RTMP server"

# Permitir tráfico RTMP (puerto 1935)
gcloud compute firewall-rules create allow-rtmp \
    --allow tcp:1935 \
    --source-ranges 0.0.0.0/0 \
    --description "Allow RTMP traffic"
```

### 3. Transferir archivos al servidor

```bash
# Conectar a la VM
gcloud compute ssh rtmp-server --zone=us-central1-a

# En la VM, crear directorio del proyecto
mkdir -p ~/gnix-server
cd ~/gnix-server
```

Luego transferir todos los archivos del proyecto excepto:
- `node_modules/`
- `ngrok-docker.yml`
- `docker-compose.yml` (usar `docker-compose.gcp.yml`)

### 4. Ejecutar el servidor

```bash
# En la VM
cd ~/gnix-server

# Construir y ejecutar con Docker Compose
docker-compose -f docker-compose.gcp.yml up -d

# Verificar que esté funcionando
docker-compose -f docker-compose.gcp.yml logs -f
```

### 5. Obtener IP externa

```bash
# Obtener IP externa de la VM
gcloud compute instances describe rtmp-server \
    --zone=us-central1-a \
    --format='get(networkInterfaces[0].accessConfigs[0].natIP)'
```

## URLs de acceso

- **Página web**: `http://[IP_EXTERNA]`
- **Servidor RTMP**: `rtmp://[IP_EXTERNA]:1935/live`
- **Stream HLS**: `http://[IP_EXTERNA]/hls/[STREAM_KEY].m3u8`

## Comandos útiles

```bash
# Ver logs
docker-compose -f docker-compose.gcp.yml logs -f

# Reiniciar servicio
docker-compose -f docker-compose.gcp.yml restart

# Parar servicio
docker-compose -f docker-compose.gcp.yml down

# Ver estado
docker-compose -f docker-compose.gcp.yml ps
```

## Configuración de streaming

Para enviar stream desde OBS o similar:
- **Servidor**: `rtmp://[IP_EXTERNA]:1935/live`
- **Clave de stream**: cualquier nombre (ej: `mycam`)

Para ver el stream:
- **URL HLS**: `http://[IP_EXTERNA]/hls/mycam.m3u8`
- **Página web**: `http://[IP_EXTERNA]`

## Consideraciones de seguridad

1. **Limitar IPs**: Editar `nginx.conf` para permitir solo IPs específicas en `allow publish`
2. **Autenticación**: Agregar autenticación RTMP si es necesario
3. **HTTPS**: Configurar certificado SSL para producción
4. **Firewall**: Limitar acceso solo a IPs necesarias