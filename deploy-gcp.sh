#!/bin/bash

# GNIX RTMP Server - Google Cloud Deployment Script
# Este script automatiza el deployment del servidor RTMP en Google Cloud Platform

set -e

# Configuraciones
PROJECT_ID=""
ZONE="us-central1-a"
INSTANCE_NAME="gnix-rtmp-server"
MACHINE_TYPE="e2-standard-2"
BOOT_DISK_SIZE="20GB"
FIREWALL_RULE_NAME="gnix-rtmp-ports"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
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
        print_error "Google Cloud SDK no está instalado"
        print_status "Instala Google Cloud SDK: https://cloud.google.com/sdk/docs/install"
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        print_warning "Docker no está instalado localmente, pero no es necesario para el deployment"
    fi
    
    print_success "Dependencias verificadas"
}

# Configurar proyecto
setup_project() {
    if [ -z "$PROJECT_ID" ]; then
        print_status "Selecciona tu proyecto de Google Cloud:"
        gcloud projects list
        echo
        read -p "Ingresa el PROJECT_ID: " PROJECT_ID
    fi
    
    print_status "Configurando proyecto: $PROJECT_ID"
    gcloud config set project $PROJECT_ID
    
    print_status "Habilitando APIs necesarias..."
    gcloud services enable compute.googleapis.com
    gcloud services enable container.googleapis.com
    
    print_success "Proyecto configurado"
}

# Crear reglas de firewall
create_firewall_rules() {
    print_status "Creando reglas de firewall..."
    
    # Verificar si la regla ya existe
    if gcloud compute firewall-rules list --filter="name=$FIREWALL_RULE_NAME" --format="value(name)" | grep -q "$FIREWALL_RULE_NAME"; then
        print_warning "La regla de firewall $FIREWALL_RULE_NAME ya existe"
    else
        gcloud compute firewall-rules create $FIREWALL_RULE_NAME \
            --direction=INGRESS \
            --priority=1000 \
            --network=default \
            --action=ALLOW \
            --rules=tcp:1935,tcp:3000,tcp:80,tcp:8080 \
            --source-ranges=0.0.0.0/0 \
            --target-tags=rtmp-server
        
        print_success "Reglas de firewall creadas"
    fi
}

# Crear instancia de VM
create_vm_instance() {
    print_status "Creando instancia de VM..."
    
    # Verificar si la instancia ya existe
    if gcloud compute instances list --filter="name=$INSTANCE_NAME" --format="value(name)" | grep -q "$INSTANCE_NAME"; then
        print_warning "La instancia $INSTANCE_NAME ya existe"
        print_status "¿Deseas recrearla? (y/N)"
        read -r recreate
        if [[ $recreate =~ ^[Yy]$ ]]; then
            print_status "Eliminando instancia existente..."
            gcloud compute instances delete $INSTANCE_NAME --zone=$ZONE --quiet
        else
            return 0
        fi
    fi

    # Startup script
    cat > startup-script.sh << 'EOF'
#!/bin/bash

# Update system
apt-get update
apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
systemctl enable docker
systemctl start docker

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create app directory
mkdir -p /app
cd /app

# Get external IP
EXTERNAL_IP=$(curl -s ifconfig.me)
echo "EXTERNAL_IP=$EXTERNAL_IP" > .env

# Clone repository (replace with your actual repository)
# git clone https://github.com/your-username/gnix-server.git .

# For now, we'll create the minimal structure
echo "Application will be deployed manually or via CI/CD"

# Create directories
mkdir -p data/hls data/recordings www public

# Set up log rotation
cat > /etc/logrotate.d/gnix-rtmp << 'EOLR'
/var/lib/docker/containers/*/*-json.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}
EOLR

# Create systemd service for auto-start
cat > /etc/systemd/system/gnix-rtmp.service << 'EOSYS'
[Unit]
Description=GNIX RTMP Server
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/app
ExecStart=/usr/local/bin/docker-compose -f docker-compose.gcp.yml up -d
ExecStop=/usr/local/bin/docker-compose -f docker-compose.gcp.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOSYS

systemctl enable gnix-rtmp.service

echo "VM setup completed. Application files need to be uploaded manually."
EOF

    gcloud compute instances create $INSTANCE_NAME \
        --zone=$ZONE \
        --machine-type=$MACHINE_TYPE \
        --network-interface=network-tier=PREMIUM,subnet=default \
        --maintenance-policy=MIGRATE \
        --provisioning-model=STANDARD \
        --tags=rtmp-server,http-server,https-server \
        --create-disk=auto-delete=yes,boot=yes,device-name=$INSTANCE_NAME,image=projects/ubuntu-os-cloud/global/images/family/ubuntu-2004-lts,mode=rw,size=$BOOT_DISK_SIZE,type=projects/$PROJECT_ID/zones/$ZONE/diskTypes/pd-standard \
        --no-shielded-secure-boot \
        --shielded-vtpm \
        --shielded-integrity-monitoring \
        --reservation-affinity=any \
        --metadata-from-file startup-script=startup-script.sh

    print_success "Instancia de VM creada"
    
    # Clean up startup script
    rm startup-script.sh
}

# Obtener información de la instancia
get_instance_info() {
    print_status "Obteniendo información de la instancia..."
    
    EXTERNAL_IP=$(gcloud compute instances describe $INSTANCE_NAME \
        --zone=$ZONE \
        --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
    
    print_success "Instancia creada exitosamente!"
    echo
    echo "========================================="
    echo "  INFORMACIÓN DE DEPLOYMENT"
    echo "========================================="
    echo "Instancia: $INSTANCE_NAME"
    echo "Zona: $ZONE"
    echo "IP Externa: $EXTERNAL_IP"
    echo
    echo "URLs de acceso:"
    echo "  Dashboard: http://$EXTERNAL_IP:3000"
    echo "  Nginx Stats: http://$EXTERNAL_IP/stats"
    echo "  RTMP URL: rtmp://$EXTERNAL_IP:1935/live"
    echo "  HLS URL: http://$EXTERNAL_IP/hls"
    echo
    echo "========================================="
    echo
}

# Subir archivos
upload_files() {
    print_status "¿Deseas subir los archivos del proyecto ahora? (y/N)"
    read -r upload
    if [[ $upload =~ ^[Yy]$ ]]; then
        print_status "Subiendo archivos..."
        
        # Crear archivo tar con todos los archivos necesarios
        tar -czf gnix-server.tar.gz \
            docker-compose.gcp.yml \
            Dockerfile.nginx \
            Dockerfile.web \
            nginx.conf \
            package.json \
            server.js \
            public/ \
            www/ || true
            
        # Subir archivo
        gcloud compute scp gnix-server.tar.gz $INSTANCE_NAME:/tmp/ --zone=$ZONE
        
        # Extraer y ejecutar en la VM
        gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="
            cd /app &&
            sudo tar -xzf /tmp/gnix-server.tar.gz &&
            sudo chown -R \$USER:docker /app &&
            echo 'EXTERNAL_IP=$EXTERNAL_IP' | sudo tee .env &&
            docker-compose -f docker-compose.gcp.yml pull &&
            docker-compose -f docker-compose.gcp.yml up -d
        "
        
        # Limpiar archivo local
        rm gnix-server.tar.gz
        
        print_success "Archivos subidos y aplicación iniciada"
    else
        print_warning "Recuerda subir los archivos manualmente usando:"
        echo "  gcloud compute scp [archivos] $INSTANCE_NAME:/app/ --zone=$ZONE"
    fi
}

# Función principal
main() {
    echo
    echo "========================================="
    echo "  GNIX RTMP SERVER - GCP DEPLOYMENT"
    echo "========================================="
    echo
    
    check_dependencies
    setup_project
    create_firewall_rules
    create_vm_instance
    
    # Esperar a que la instancia esté lista
    print_status "Esperando a que la instancia esté lista..."
    sleep 30
    
    get_instance_info
    upload_files
    
    print_success "Deployment completado!"
    print_status "La aplicación tardará unos minutos en estar completamente disponible."
    print_status "Puedes monitorear el progreso con:"
    echo "  gcloud compute ssh $INSTANCE_NAME --zone=$ZONE"
    echo "  sudo journalctl -u gnix-rtmp -f"
}

# Función de limpieza
cleanup() {
    print_status "¿Deseas eliminar todos los recursos creados? (y/N)"
    read -r cleanup
    if [[ $cleanup =~ ^[Yy]$ ]]; then
        print_status "Eliminando recursos..."
        
        gcloud compute instances delete $INSTANCE_NAME --zone=$ZONE --quiet || true
        gcloud compute firewall-rules delete $FIREWALL_RULE_NAME --quiet || true
        
        print_success "Recursos eliminados"
    fi
}

# Verificar argumentos
case "${1:-deploy}" in
    "deploy")
        main
        ;;
    "cleanup")
        cleanup
        ;;
    "info")
        get_instance_info
        ;;
    *)
        echo "Uso: $0 [deploy|cleanup|info]"
        echo "  deploy  - Despliega el servidor RTMP en GCP"
        echo "  cleanup - Elimina todos los recursos creados"
        echo "  info    - Muestra información de la instancia"
        exit 1
        ;;
esac