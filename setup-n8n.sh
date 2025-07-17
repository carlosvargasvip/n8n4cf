#!/bin/bash

# Complete setup script for n8n with PostgreSQL and Watchtower

echo "🚀 n8n with PostgreSQL Setup Script"
echo "===================================="
echo ""

# Check if docker and docker-compose are installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Create project directory
read -p "Enter project directory name [n8n-postgres]: " project_dir
project_dir=${project_dir:-n8n-postgres}

if [ -d "$project_dir" ]; then
    echo "Warning: Directory '$project_dir' already exists!"
    read -p "Do you want to continue and potentially overwrite files? (y/N): " continue_setup
    if [[ ! $continue_setup =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
else
    mkdir -p "$project_dir"
fi

cd "$project_dir"
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

# Create docker-compose.yml file
echo "📝 Creating docker-compose.yml..."

cat > docker-compose.yml << 'EOF'
version: '3.8'

volumes:
  db_storage:
  n8n_storage:

services:
  postgres:
    image: postgres:16
    restart: always
    environment:
      - POSTGRES_USER
      - POSTGRES_PASSWORD
      - POSTGRES_DB
      - POSTGRES_NON_ROOT_USER
      - POSTGRES_NON_ROOT_PASSWORD
    volumes:
      - db_storage:/var/lib/postgresql/data
      - ./init-data.sh:/docker-entrypoint-initdb.d/init-data.sh
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -h localhost -U ${POSTGRES_USER} -d ${POSTGRES_DB}']
      interval: 5s
      timeout: 5s
      retries: 10
    labels:
      - "com.centurylinklabs.watchtower.schedule=0 0 2 1 * *"  # Monthly update on 1st day at 2 AM

  n8n:
    image: docker.n8n.io/n8nio/n8n
    restart: always
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=${POSTGRES_DB}
      - DB_POSTGRESDB_USER=${POSTGRES_NON_ROOT_USER}
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_NON_ROOT_PASSWORD}
    ports:
      - 5678:5678
    links:
      - postgres
    volumes:
      - n8n_storage:/home/node/.n8n
    depends_on:
      postgres:
        condition: service_healthy
    labels:
      - "com.centurylinklabs.watchtower.schedule=0 0 2 * * 1"  # Weekly update on Monday at 2 AM

  watchtower:
    image: containrrr/watchtower
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - WATCHTOWER_SCHEDULE=0 0 1 * * *  # Check for updates daily at 1 AM
      - WATCHTOWER_CLEANUP=true  # Remove old images after update
      - WATCHTOWER_INCLUDE_STOPPED=true  # Also update stopped containers
      - WATCHTOWER_INCLUDE_RESTARTING=true  # Also update restarting containers
    labels:
      - "com.centurylinklabs.watchtower.enable=false"  # Don't update watchtower itself
EOF

echo "✅ docker-compose.yml created!"
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
echo "Project Directory: $project_dir"
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
    docker-compose pull
    
    # Start services
    echo "🚀 Starting services..."
    docker-compose up -d
    
    echo ""
    echo "⏳ Waiting for services to be ready..."
    sleep 10
    
    # Check if services are running
    if docker-compose ps | grep -q "Up"; then
        echo ""
        echo "🎉 Success! n8n is now running!"
        echo ""
        echo "🌐 Access n8n at: http://localhost:5678"
        echo "📊 Check status: docker-compose ps"
        echo "📋 View logs: docker-compose logs -f"
        echo "🛑 Stop services: docker-compose down"
        echo ""
        echo "💡 First time setup:"
        echo "   1. Go to http://localhost:5678"
        echo "   2. Create your admin account"
        echo "   3. Start building your workflows!"
    else
        echo "❌ Some services failed to start. Check logs with:"
        echo "   docker-compose logs"
    fi
else
    echo ""
    echo "📝 Setup complete! To start n8n later, run:"
    echo "   cd $project_dir"
    echo "   docker-compose up -d"
    echo ""
    echo "🌐 n8n will be available at: http://localhost:5678"
fi

echo ""
echo "🎯 Setup completed successfully!"
