# Imagen base con nginx y módulo RTMP
FROM alfg/nginx-rtmp:latest

# Instalar herramientas adicionales (Alpine Linux)
RUN apk add --no-cache \
    curl \
    wget \
    htop

# Crear directorios necesarios
RUN mkdir -p /opt/data/hls \
    && mkdir -p /opt/data/recordings \
    && mkdir -p /www/static \
    && chmod -R 755 /opt/data \
    && chmod -R 755 /www/static

# Copiar configuración personalizada
COPY nginx.conf /etc/nginx/nginx.conf
COPY www/static/ /www/static/

# Exponer puertos
EXPOSE 8080 1935

# Variables de entorno
ENV NGINX_WORKER_PROCESSES=auto
ENV RTMP_CHUNK_SIZE=4000

# Comando de inicio
CMD ["nginx", "-g", "daemon off;"]