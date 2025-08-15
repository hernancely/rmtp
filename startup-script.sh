#!/bin/bash

# Script de inicialización para VM de GCP
# Instalar Docker y Docker Compose

# Actualizar sistema
sudo apt-get update -y

# Instalar dependencias
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Agregar clave GPG oficial de Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Agregar repositorio de Docker
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar Docker
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Instalar Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Iniciar Docker
sudo systemctl start docker
sudo systemctl enable docker

# Agregar usuario actual al grupo docker
sudo usermod -aG docker $USER

# Crear directorio del proyecto
mkdir -p /home/$(whoami)/gnix-server
cd /home/$(whoami)/gnix-server

# El código del proyecto debe estar aquí
# Puedes usar git clone o transferir los archivos

echo "Docker y Docker Compose instalados correctamente"
echo "Reinicia la sesión SSH para usar Docker sin sudo"