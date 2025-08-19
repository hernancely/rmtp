# 🎥 GNIX RTMP Server

Servidor RTMP completo con dashboard web para transmisión en vivo, diseñado para deployarse en Google Cloud Platform.

## ✨ Características

- **Servidor RTMP** con nginx-rtmp-module
- **Dashboard web** con visualización en tiempo real
- **Grabación automática** de streams
- **Compatible con OBS** para agregar publicidad
- **Visualización HLS** en tiempo real
- **Estadísticas detalladas** de streams y viewers
- **Deploy automático** en Google Cloud Platform

## 🚀 Despliegue en Google Cloud Platform

### Prerequisitos

- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) instalado localmente
- Cuenta de Google Cloud Platform activa
- VM creada en Google Cloud

### Opción 1: Deploy Automático (Recomendado)

1. **Desde tu máquina local**
   ```bash
   git clone https://github.com/hernancely/rmtp.git
   cd rmtp
   chmod +x deploy-gcp.sh
   ./deploy-gcp.sh
   ```

### Opción 2: Deploy Manual en VM

#### **Paso 1: Conectarse a la VM**
```bash
# Desde tu máquina local
gcloud compute ssh [NOMBRE_VM] --zone=[ZONA]
# Ejemplo: gcloud compute ssh mi-servidor --zone=us-central1-a
```

#### **Paso 2: Instalar Docker en la VM**
```bash
# Actualizar sistema
sudo apt update && sudo apt upgrade -y

# Instalar Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Instalar Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verificar instalación
docker --version
docker-compose --version

# Reiniciar sesión para aplicar permisos
exit
```

#### **Paso 3: Reconectarse y configurar el proyecto**
```bash
# Conectarse nuevamente
gcloud compute ssh [NOMBRE_VM] --zone=[ZONA]

# Clonar el repositorio
git clone https://github.com/hernancely/rmtp.git
cd rmtp

# Configurar variables de entorno
EXTERNAL_IP=$(curl -s ifconfig.me)
echo "IP Externa detectada: $EXTERNAL_IP"

# Crear archivo .env
echo "EXTERNAL_IP=$EXTERNAL_IP" > .env
echo "RTMP_SERVER=$EXTERNAL_IP" >> .env
echo "NODE_ENV=production" >> .env

# Verificar configuración
cat .env
```

#### **Paso 4: Deployar el servidor**
```bash
# Crear directorios necesarios
mkdir -p data/hls data/recordings

# Construir y ejecutar contenedores
docker-compose -f docker-compose.gcp.yml up -d

# Verificar que están corriendo
docker ps
```

#### **Paso 5: Configurar Firewall (si es necesario)**
```bash
# Ejecutar desde tu máquina local (NO en la VM)
gcloud compute firewall-rules create gnix-rtmp-ports \
    --direction=INGRESS \
    --priority=1000 \
    --network=default \
    --action=ALLOW \
    --rules=tcp:1935,tcp:3000,tcp:80,tcp:8080 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=rtmp-server

# Aplicar tag a la VM
gcloud compute instances add-tags [NOMBRE_VM] --tags=rtmp-server --zone=[ZONA]
```

#### **Paso 6: Verificar el deployment**
```bash
# Ver logs del dashboard
docker logs gnix-dashboard

# Ver logs del servidor RTMP
docker logs gnix-rtmp-server

# Verificar puertos abiertos
sudo netstat -tulpn | grep -E ':(1935|3000|80)'

# Ver estado de contenedores
docker ps -a
```

### 🔍 **Verificación Final**

Después del deployment, verifica que todo funciona:

1. **Dashboard**: `http://[IP_EXTERNA]:3000`
2. **Stats NGINX**: `http://[IP_EXTERNA]:8080/stats`
3. **Test RTMP**: `rtmp://[IP_EXTERNA]:1935/live`

### 🛠️ **Comandos de Mantenimiento**

```bash
# Reiniciar servicios
docker-compose -f docker-compose.gcp.yml restart

# Ver logs en tiempo real
docker logs -f gnix-dashboard
docker logs -f gnix-rtmp-server

# Parar servicios
docker-compose -f docker-compose.gcp.yml down

# Actualizar desde GitHub
git pull origin main
docker-compose -f docker-compose.gcp.yml up -d --build

# Ver uso de recursos
docker stats

# Limpiar logs antiguos
docker system prune -f
```

## 📡 Configuración OBS

### URLs del Servidor

Después del deployment, obtendrás:

- **Dashboard**: `http://[IP_EXTERNA]:3000`
- **RTMP URL**: `rtmp://[IP_EXTERNA]:1935/live`
- **Stream Key**: `live-stream` (o personalizable)

### Configuración en OBS

1. **Configuración → Stream**
2. **Servicio**: Custom Streaming Server
3. **Servidor**: `rtmp://[IP_EXTERNA]:1935/live`
4. **Stream Key**: `live-stream`

### Configuración Recomendada de Salida

- **Encoder**: x264
- **Bitrate**: 2500 Kbps
- **Keyframe Interval**: 2
- **Preset**: veryfast

## 🎯 Integración con Publicidad

### Opción 1: Escenas Múltiples en OBS

1. Crear escena "Stream Principal"
2. Crear escena "Publicidad"
3. Usar transiciones automáticas
4. Plugin recomendado: **Advanced Scene Switcher**

### Opción 2: RTMP Push/Pull

El servidor soporta múltiples aplicaciones RTMP para routing avanzado:

```nginx
application ads {
    live on;
    allow publish [IP_AUTORIZADA];
    push rtmp://localhost:1935/live/main-stream;
}
```

## 🔧 Desarrollo Local

### Con Docker Compose

```bash
# Desarrollo
docker-compose up -d

# Producción local
docker-compose -f docker-compose.gcp.yml up -d
```

### URLs Locales

- **Dashboard**: http://localhost:3000
- **RTMP**: rtmp://localhost:1935/live
- **HLS**: http://localhost:8080/hls
- **Stats**: http://localhost:8080/stats

## 📊 API Endpoints

### Información del Servidor
```
GET /api/server-info
```

### Streams Activos
```
GET /api/streams
```

### Grabaciones
```
GET /api/recordings
GET /api/download/:filename
```

## 🎮 Dashboard Features

- **Visualización en tiempo real** del stream
- **URLs copiables** para OBS
- **Lista de streams activos** con estadísticas
- **Descargas de grabaciones**
- **Guía de configuración OBS**
- **Estadísticas del servidor**

## 🔒 Configuración de Seguridad

### Firewall Rules (GCP)

El script crea automáticamente reglas para:
- Puerto 1935 (RTMP)
- Puerto 3000 (Dashboard)
- Puerto 80/8080 (HTTP/HLS)

### Autenticación RTMP (Opcional)

Descomentar en `nginx.conf`:
```nginx
on_publish http://web:3000/auth;
```

Implementar validación en `server.js`:
```javascript
app.post('/auth', (req, res) => {
    const { name } = req.body;
    // Implementar lógica de autenticación
    res.status(200).send('OK');
});
```

## 📁 Estructura del Proyecto

```
gnix-server/
├── docker-compose.yml          # Docker compose para desarrollo
├── docker-compose.gcp.yml      # Docker compose para GCP
├── deploy-gcp.sh              # Script de deployment
├── nginx.conf                 # Configuración nginx-rtmp
├── server.js                  # Servidor Node.js para dashboard
├── package.json               # Dependencias Node.js
├── Dockerfile.nginx           # Docker para nginx-rtmp
├── Dockerfile.web             # Docker para dashboard
├── public/                    # Frontend del dashboard
│   ├── index.html
│   ├── css/dashboard.css
│   └── js/dashboard.js
├── www/                       # Archivos estáticos nginx
│   └── stat.xsl              # Stylesheet para stats XML
└── data/                      # Volúmenes persistentes
    ├── hls/                   # Archivos HLS
    └── recordings/            # Grabaciones
```

## 🛠️ Personalización

### Variables de Entorno

```bash
# .env file
EXTERNAL_IP=tu.ip.externa
RTMP_SERVER=tu.servidor.com
PORT=3000
NODE_ENV=production
```

### Configuración Nginx

Editar `nginx.conf` para:
- Cambiar puertos
- Agregar aplicaciones RTMP
- Configurar autenticación
- Modificar configuración HLS

### Estilos del Dashboard

Modificar `public/css/dashboard.css` para personalizar la apariencia.

## 🔍 Troubleshooting

### Ver logs del contenedor

```bash
# Logs del dashboard
docker logs gnix-dashboard

# Logs del servidor RTMP
docker logs gnix-rtmp-server

# En GCP
gcloud compute ssh gnix-rtmp-server --zone=us-central1-a
sudo journalctl -u gnix-rtmp -f
```

### Verificar puertos

```bash
# Verificar que los puertos estén abiertos
sudo netstat -tulpn | grep -E ':(1935|3000|8080)'
```

### Problemas comunes

1. **Stream no se ve**: Verificar que el stream esté llegando a `/stats`
2. **No se puede conectar**: Verificar firewall rules
3. **Grabaciones no funcionan**: Verificar permisos de `/var/recordings`

## 📞 Soporte

- **Issues**: [GitHub Issues](https://github.com/tu-usuario/gnix-server/issues)
- **Documentación**: Este README
- **Stats en vivo**: `http://[servidor]/stats`

## 📄 Licencia

MIT License - ver [LICENSE](LICENSE) para más detalles.

---

**¿Preguntas?** Abre un issue o revisa la documentación del dashboard web.