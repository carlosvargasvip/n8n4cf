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

# Check if docker and docker-compose are installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Get installation directory
read -p "Enter installation directory name [n8n-postgres]: " install_dir
install_dir=${install_dir:-n8n-postgres}

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
    ./setup-n8n.sh
else
    echo ""
    echo "📝 Installation complete! To set up n8n later:"
    echo "   cd $install_dir"
    echo "   ./setup-n8n.sh"
    echo ""
    echo "🌐 After setup, n8n will be available at: http://localhost:5678"
fi

echo ""
echo "🎯 Installation completed successfully!"
