# 🎥 Servidor RTMP/HLS con Nginx + Ngrok

Un servidor completo para streaming en tiempo real que permite conectar cámaras remotas y transmitir video a través de RTMP con exposición automática a internet mediante Ngrok.

## 🚀 Características

- **Servidor RTMP** en puerto 1935 para recibir streams
- **Servidor HTTP** en puerto 8080 para visualización web
- **Ngrok integrado** para exposición automática a internet
- **Conversión automática** de RTMP a HLS
- **Interfaz web** moderna y responsive
- **Múltiples streams** simultáneos
- **Grabación automática** de transmisiones
- **Estadísticas en tiempo real**

## 📋 Requisitos

- Docker y Docker Compose instalados
- Puertos 8080, 1935 y 4040 disponibles
- Token de Ngrok (ya configurado)

## 🛠️ Instalación y Uso

### Inicio Simple
```cmd
start.bat
```

### Manual con Docker Compose
```cmd
# Iniciar todos los servicios
docker compose up -d

# Ver logs
docker compose logs -f

# Detener
docker compose down
```

## 🌐 URLs de Acceso

Una vez iniciado el servidor:

- **Panel Ngrok**: http://localhost:4040 (URLs públicas aquí)
- **Servidor local**: http://localhost:8080
- **Estadísticas**: http://localhost:8080/stats

## 🎬 Configurar tu Cámara Remota

### 1. Obtener URLs Públicas
Ve a http://localhost:4040 y verás:
- **URL TCP**: Para conectar tu cámara (ej: `tcp://x.tcp.ngrok.io:12345`)
- **URL HTTPS**: Para ver la transmisión (ej: `https://abc123.ngrok.io`)

### 2. Configurar OBS Studio (en ubicación remota)
1. Configuración → Stream
2. Servicio: Personalizado
3. Servidor: `tcp://x.tcp.ngrok.io:12345` (URL TCP de ngrok)
4. Clave de stream: `mycamera`

### 3. Configurar FFmpeg
```bash
ffmpeg -i [fuente] -c:v libx264 -c:a aac -f flv tcp://x.tcp.ngrok.io:12345/live/mycamera
```

### 4. Configurar Cámaras IP
- **Protocolo**: RTMP
- **URL**: `tcp://x.tcp.ngrok.io:12345/live`
- **Stream Key**: `mycamera`

## 🌐 Ver la Transmisión

Usa la URL HTTPS de ngrok en cualquier navegador:
- `https://abc123.ngrok.io`
- Haz clic en "Cargar Stream"
- ¡Disfruta tu transmisión desde cualquier lugar!

## 📁 Estructura del Proyecto

```
gnix-server/
├── nginx.conf              # Configuración de Nginx (puerto 8080)
├── docker-compose.yml      # Configuración completa con Ngrok
├── ngrok-docker.yml        # Configuración de Ngrok
├── Dockerfile             # Imagen Docker personalizada
├── start.bat              # Script de inicio simple
├── www/static/index.html  # Interfaz web de visualización
└── README.md              # Esta documentación
```

## 🔧 Configuración

### Token de Ngrok
Ya configurado: `30YIyCCiLqNSd1XuJZgP8hgFy1q_4XyPGVp85jv7J9DrxEMJ2`

### Puertos Configurados
- **8080**: Servidor web nginx
- **1935**: Servidor RTMP
- **4040**: Panel de control Ngrok

### Túneles Ngrok Automáticos
- **TCP**: `nginx-rtmp:1935` → URL pública para cámaras
- **HTTP**: `nginx-rtmp:8080` → URL pública para visualización

## 🐛 Resolución de Problemas

### El servidor no inicia
```cmd
# Ver estado de contenedores
docker compose ps

# Ver logs
docker compose logs
```

### Ngrok no se conecta
- Verifica que el token esté correcto en `ngrok-docker.yml`
- Revisa logs: `docker compose logs ngrok`
- Ve al panel: http://localhost:4040

### No aparecen túneles
- Espera 30-60 segundos después del inicio
- Refresca http://localhost:4040
- Reinicia: `docker compose restart ngrok`

### Cámara no conecta
- Usa la URL TCP completa de ngrok
- Incluye `/live` al final de la URL
- Verifica que el stream key sea `mycamera`

## 📊 Monitoreo

- **Panel Ngrok**: http://localhost:4040
- **Estadísticas RTMP**: http://localhost:8080/stats  
- **Logs en tiempo real**: `docker compose logs -f`

## 🎯 Ejemplo Completo

1. **Ejecutar**: `start.bat`
2. **Esperar**: 30 segundos
3. **Ir a**: http://localhost:4040
4. **Copiar URL TCP**: `tcp://4.tcp.ngrok.io:12345`
5. **En OBS remoto**: Servidor = URL TCP, Stream Key = `mycamera`
6. **Ver stream**: URL HTTPS de ngrok en navegador

## 🔒 Seguridad

- URLs de ngrok cambian al reiniciar (versión gratuita)
- Para URLs fijas, considera ngrok Pro
- En producción, configura autenticación en nginx

---

🎉 **¡Listo para streaming global!** Tu cámara puede estar en cualquier parte del mundo y transmitir a través de internet.