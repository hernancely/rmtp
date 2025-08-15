#!/bin/bash

# Script de despliegue de servidor RTMP en Google Cloud Platform
# Configura la infraestructura y despliega el servidor

set -e

# Variables de configuración
PROJECT_ID="your-project-id"
ZONE="us-central1-a"
MACHINE_TYPE="e2-standard-2"
INSTANCE_NAME="gnix-rtmp-server"
DISK_SIZE="50GB"
NETWORK_TAG="rtmp-server"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar dependencias
check_dependencies() {
    print_status "Verificando dependencias..."
    
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI no está instalado"
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker no está instalado"
        exit 1
    fi
    
    print_status "Dependencias verificadas"
}

# Configurar proyecto
setup_project() {
    print_status "Configurando proyecto GCP..."
    
    # Verificar si el proyecto está configurado
    CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null)
    if [ "$CURRENT_PROJECT" != "$PROJECT_ID" ]; then
        print_warning "Configurando proyecto: $PROJECT_ID"
        gcloud config set project $PROJECT_ID
    fi
    
    # Habilitar APIs necesarias
    print_status "Habilitando APIs necesarias..."
    gcloud services enable compute.googleapis.com
    gcloud services enable container.googleapis.com
    
    print_status "Proyecto configurado"
}

# Crear reglas de firewall
create_firewall_rules() {
    print_status "Creando reglas de firewall..."
    
    # Regla para RTMP (puerto 1935)
    if ! gcloud compute firewall-rules describe rtmp-allow-1935 &> /dev/null; then
        gcloud compute firewall-rules create rtmp-allow-1935 \
            --allow tcp:1935 \
            --source-ranges 0.0.0.0/0 \
            --target-tags $NETWORK_TAG \
            --description "Permitir tráfico RTMP en puerto 1935"
        print_status "Regla de firewall para RTMP creada"
    else
        print_warning "Regla de firewall para RTMP ya existe"
    fi
    
    # Regla para HTTP (puerto 80)
    if ! gcloud compute firewall-rules describe rtmp-allow-http &> /dev/null; then
        gcloud compute firewall-rules create rtmp-allow-http \
            --allow tcp:80 \
            --source-ranges 0.0.0.0/0 \
            --target-tags $NETWORK_TAG \
            --description "Permitir tráfico HTTP en puerto 80"
        print_status "Regla de firewall para HTTP creada"
    else
        print_warning "Regla de firewall para HTTP ya existe"
    fi
    
    # Regla para SSH
    if ! gcloud compute firewall-rules describe rtmp-allow-ssh &> /dev/null; then
        gcloud compute firewall-rules create rtmp-allow-ssh \
            --allow tcp:22 \
            --source-ranges 0.0.0.0/0 \
            --target-tags $NETWORK_TAG \
            --description "Permitir SSH"
        print_status "Regla de firewall para SSH creada"
    else
        print_warning "Regla de firewall para SSH ya existe"
    fi
}

# Crear instancia de VM
create_instance() {
    print_status "Creando instancia de VM..."
    
    if gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE &> /dev/null; then
        print_warning "La instancia $INSTANCE_NAME ya existe"
        return
    fi
    
    gcloud compute instances create $INSTANCE_NAME \
        --zone=$ZONE \
        --machine-type=$MACHINE_TYPE \
        --network-interface=network-tier=PREMIUM,subnet=default \
        --maintenance-policy=MIGRATE \
        --provisioning-model=STANDARD \
        --tags=$NETWORK_TAG \
        --create-disk=auto-delete=yes,boot=yes,device-name=$INSTANCE_NAME,image=projects/ubuntu-os-cloud/global/images/ubuntu-2204-jammy-v20240319,mode=rw,size=$DISK_SIZE,type=projects/$PROJECT_ID/zones/$ZONE/diskTypes/pd-balanced \
        --metadata-from-file startup-script=startup-script.sh \
        --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append
    
    print_status "Instancia $INSTANCE_NAME creada"
}

# Obtener IP externa
get_external_ip() {
    print_status "Obteniendo IP externa..."
    
    EXTERNAL_IP=$(gcloud compute instances describe $INSTANCE_NAME \
        --zone=$ZONE \
        --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
    
    print_status "IP Externa: $EXTERNAL_IP"
}

# Transferir archivos a la instancia
transfer_files() {
    print_status "Esperando que la instancia esté lista..."
    sleep 60  # Esperar que termine el startup-script
    
    print_status "Transfiriendo archivos del proyecto..."
    
    # Crear directorio remoto
    gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="mkdir -p ~/gnix-server"
    
    # Transferir archivos
    gcloud compute scp --recurse . $INSTANCE_NAME:~/gnix-server --zone=$ZONE
    
    print_status "Archivos transferidos"
}

# Iniciar el servidor
start_server() {
    print_status "Iniciando servidor RTMP..."
    
    gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="
        cd ~/gnix-server
        sudo docker-compose -f docker-compose.gcp.yml up -d
    "
    
    print_status "Servidor RTMP iniciado"
}

# Mostrar información de conexión
show_connection_info() {
    print_status "==================== INFORMACIÓN DE CONEXIÓN ===================="
    echo ""
    echo "🖥️  IP Externa del servidor: $EXTERNAL_IP"
    echo ""
    echo "🎥 Para enviar stream RTMP:"
    echo "   URL del servidor: rtmp://$EXTERNAL_IP:1935/live"
    echo "   Stream Key: [tu_stream_key]"
    echo ""
    echo "📺 Para ver el stream:"
    echo "   HLS Playlist: http://$EXTERNAL_IP/hls/[tu_stream_key].m3u8"
    echo "   Player web: http://$EXTERNAL_IP"
    echo ""
    echo "📊 Estadísticas del servidor:"
    echo "   Stats: http://$EXTERNAL_IP/stats"
    echo ""
    echo "🔐 Para conectar por SSH:"
    echo "   gcloud compute ssh $INSTANCE_NAME --zone=$ZONE"
    echo ""
    echo "=============================================================="
}

# Función principal
main() {
    print_status "Iniciando despliegue del servidor RTMP en GCP..."
    
    if [ "$PROJECT_ID" = "your-project-id" ]; then
        print_error "Por favor, configura PROJECT_ID en el script"
        exit 1
    fi
    
    check_dependencies
    setup_project
    create_firewall_rules
    create_instance
    get_external_ip
    transfer_files
    start_server
    show_connection_info
    
    print_status "¡Despliegue completado exitosamente!"
}

# Ejecutar función principal
main "$@"