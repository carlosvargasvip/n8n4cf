#!/bin/bash

# Complete setup script for n8n with PostgreSQL and Watchtower

echo "🚀 n8n with PostgreSQL Setup Script"
echo "===================================="
echo ""

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

echo "📁 Working in directory: $(pwd)"
echo ""

# Create .env file
echo "Creating .env file for n8n with PostgreSQL..."
echo ""

# Check if .env file already exists
if [ -f ".env" ]; then
    echo "Warning: .env file already exists!"
    read -p "Do you want to overwrite it? (y/N): " overwrite
    if [[ ! $overwrite =~ ^[Yy]$ ]]; then
        echo "Using existing .env file..."
    else
        echo ""
        echo "Enter PostgreSQL configuration:"
        echo ""
        
        read -p "PostgreSQL admin user: " pg_user
        read -p "PostgreSQL admin password: " pg_password
        read -p "Database name: " pg_db
        read -p "Non-root user: " pg_nonroot_user
        read -p "Non-root password: " pg_nonroot_password
        
        # Create .env file
        cat > .env << EOF
POSTGRES_USER=$pg_user
POSTGRES_PASSWORD=$pg_password
POSTGRES_DB=$pg_db
POSTGRES_NON_ROOT_USER=$pg_nonroot_user
POSTGRES_NON_ROOT_PASSWORD=$pg_nonroot_password
EOF
        echo "✅ .env file created!"
    fi
else
    echo "Enter PostgreSQL configuration:"
    echo ""
    
    read -p "PostgreSQL admin user: " pg_user
    read -p "PostgreSQL admin password: " pg_password
    read -p "Database name: " pg_db
    read -p "Non-root user: " pg_nonroot_user
    read -p "Non-root password: " pg_nonroot_password
    
    # Create .env file
    cat > .env << EOF
POSTGRES_USER=$pg_user
POSTGRES_PASSWORD=$pg_password
POSTGRES_DB=$pg_db
POSTGRES_NON_ROOT_USER=$pg_nonroot_user
POSTGRES_NON_ROOT_PASSWORD=$pg_nonroot_password
EOF
    echo "✅ .env file created!"
fi

echo ""

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ docker-compose.yml not found in current directory!"
    echo "   Make sure you're running this script from the correct directory."
    exit 1
fi

echo "✅ Found docker-compose.yml"
echo ""

# Create init-data.sh for PostgreSQL initialization
echo "📝 Creating PostgreSQL initialization script..."

cat > init-data.sh << 'EOF'
#!/bin/bash
set -e

echo "Creating database and user for n8n..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER $POSTGRES_NON_ROOT_USER WITH PASSWORD '$POSTGRES_NON_ROOT_PASSWORD';
    GRANT ALL PRIVILEGES ON DATABASE $POSTGRES_DB TO $POSTGRES_NON_ROOT_USER;
    GRANT ALL ON SCHEMA public TO $POSTGRES_NON_ROOT_USER;
EOSQL

echo "Database initialization complete!"
EOF

chmod +x init-data.sh
echo "✅ PostgreSQL initialization script created!"
echo ""

# Show configuration summary
echo "📋 Configuration Summary:"
echo "========================="
echo "Working Directory: $(pwd)"
echo "Database: PostgreSQL 16"
echo "n8n Port: 5678"
echo "Auto-updates: n8n (weekly), PostgreSQL (monthly)"
echo ""

# Ask if user wants to start the services
read -p "🚀 Do you want to start the n8n services now? (y/N): " start_services

if [[ $start_services =~ ^[Yy]$ ]]; then
    echo ""
    echo "🔄 Starting n8n with PostgreSQL..."
    
    # Pull images first
    echo "📥 Pulling Docker images..."
    docker compose pull
    
    # Start services
    echo "🚀 Starting services..."
    docker compose up -d
    
    echo ""
    echo "⏳ Waiting for services to be ready..."
    sleep 10
    
    # Check if services are running
    if docker compose ps | grep -q "Up"; then
        echo ""
        echo "🎉 Success! n8n is now running!"
        echo ""
        echo "🌐 Access n8n at: http://localhost:5678"
        echo "📊 Check status: docker compose ps"
        echo "📋 View logs: docker compose logs -f"
        echo "🛑 Stop services: docker compose down"
        echo ""
        echo "💡 First time setup:"
        echo "   1. Go to http://localhost:5678"
        echo "   2. Create your admin account"
        echo "   3. Start building your workflows!"
    else
        echo "❌ Some services failed to start. Check logs with:"
        echo "   docker compose logs"
    fi
else
    echo ""
    echo "📝 Setup complete! To start n8n later, run:"
    echo "   cd $project_dir"
    echo "   docker compose up -d"
    echo ""
    echo "🌐 n8n will be available at: http://localhost:5678"
fi

echo ""
echo "🎯 Setup completed successfully!"
