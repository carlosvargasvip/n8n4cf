#!/bin/bash

# Install script for n8n with PostgreSQL from GitHub repository

echo "🚀 n8n with PostgreSQL Installer"
echo "================================="
echo "Repository: https://github.com/carlosvargasvip/n8n4cf.git"
echo ""

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "❌ Git is not installed. Please install Git first."
    exit 1
fi

# Check if docker and docker compose are installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose plugin is not available. Please update Docker to a recent version."
    echo "💡 Docker Compose is now built into Docker. Update Docker to get the compose plugin."
    exit 1
fi

# Check if user can run Docker commands without sudo
if ! docker ps &> /dev/null; then
    if sudo docker ps &> /dev/null; then
        echo "⚠️  Docker requires sudo privileges."
        echo "💡 Consider adding your user to the docker group:"
        echo "   sudo usermod -aG docker $USER"
        echo "   Then log out and log back in."
        echo ""
        read -p "Continue with sudo for Docker commands? (y/N): " use_sudo
        if [[ ! $use_sudo =~ ^[Yy]$ ]]; then
            echo "❌ Installation aborted."
            exit 1
        fi
        export DOCKER_SUDO="sudo"
    else
        echo "❌ Cannot access Docker. Please check Docker installation and permissions."
        exit 1
    fi
else
    export DOCKER_SUDO=""
fi

# Set installation directory
install_dir="n8ncf"

# Check if directory already exists
if [ -d "$install_dir" ]; then
    echo "Warning: Directory '$install_dir' already exists!"
    read -p "Do you want to remove it and clone fresh? (y/N): " remove_dir
    if [[ $remove_dir =~ ^[Yy]$ ]]; then
        echo "🗑️  Removing existing directory..."
        rm -rf "$install_dir"
    else
        echo "❌ Installation aborted. Please choose a different directory name."
        exit 1
    fi
fi

# Clone the repository
echo "📥 Cloning repository..."
if git clone https://github.com/carlosvargasvip/n8n4cf.git "$install_dir"; then
    echo "✅ Repository cloned successfully!"
else
    echo "❌ Failed to clone repository. Please check your internet connection and try again."
    exit 1
fi

# Change to the cloned directory
cd "$install_dir"
echo "📁 Working in directory: $(pwd)"
echo ""

# Check if required files exist
required_files=("docker-compose.yml" "setup-n8n.sh")
missing_files=()

for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        missing_files+=("$file")
    fi
done

if [ ${#missing_files[@]} -ne 0 ]; then
    echo "❌ Missing required files in repository:"
    printf '   - %s\n' "${missing_files[@]}"
    echo "Please check the repository contents."
    exit 1
fi

# Make setup script executable
chmod +x setup-n8n.sh

echo "🔧 Repository setup complete!"
echo ""

# Ask if user wants to run the setup immediately
read -p "🚀 Do you want to run the n8n setup now? (Y/n): " run_setup
run_setup=${run_setup:-Y}

if [[ $run_setup =~ ^[Yy]$ ]]; then
    echo ""
    echo "🔄 Running n8n setup script..."
    echo "=============================="
    cd n8ncf
    ./setup-n8n.sh
else
    echo ""
    echo "📝 Installation complete! To set up n8n later:"
    echo "   cd n8ncf"
    echo "   ./setup-n8n.sh"
    echo ""
    echo "🌐 After setup, n8n will be available at: http://localhost:5678"
fi

echo ""
echo "🎯 Installation completed successfully!"
