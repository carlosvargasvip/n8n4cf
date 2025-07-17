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
    if [[ $overwrite =~ ^[Yy]$ ]]; then
        create_new_env=true
    else
        echo "Using existing .env file..."
        create_new_env=false
    fi
else
    create_new_env=true
fi

# Create new .env file if needed
if [ "$create_new_env" = true ]; then
    echo ""
    echo "Enter PostgreSQL configuration:"
    echo ""
    
    read -p "PostgreSQL admin user: " pg_user
    read -p "PostgreSQL admin password: " pg_password
    read -p "Database name: " pg_db
    read -p "Non-root user: " pg_nonroot_user
    read -p "Non-root password: " pg_nonroot_password
    
    echo ""
    echo "Enter n8n domain configuration:"
    echo ""
    
    read -p "Domain name (e.g., yourdomain.com): " domain_name
    read -p "Subdomain for n8n (e.g., n8n): " subdomain
    read -p "Timezone (e.g., America/New_York): " timezone
    
    echo ""
    echo "Enter n8n SMTP configuration (for email notifications):"
    echo ""
    
    read -p "SMTP Host (e.g., smtp.gmail.com): " smtp_host
    read -p "SMTP Port (e.g., 587): " smtp_port
    read -p "SMTP Username: " smtp_user
    read -p "SMTP Password: " smtp_pass
    read -p "SMTP Sender email: " smtp_sender
    
    # Set default values if empty
    timezone=${timezone:-UTC}
    smtp_port=${smtp_port:-587}
    
    # Create .env file
    echo "POSTGRES_USER=$pg_user" > .env
    echo "POSTGRES_PASSWORD=$pg_password" >> .env
    echo "POSTGRES_DB=$pg_db" >> .env
    echo "POSTGRES_NON_ROOT_USER=$pg_nonroot_user" >> .env
    echo "POSTGRES_NON_ROOT_PASSWORD=$pg_nonroot_password" >> .env
    echo "DOMAIN_NAME=$domain_name" >> .env
    echo "SUBDOMAIN=$subdomain" >> .env
    echo "GENERIC_TIMEZONE=$timezone" >> .env
    echo "N8N_SMTP_HOST=$smtp_host" >> .env
    echo "N8N_SMTP_PORT=$smtp_port" >> .env
    echo "N8N_SMTP_USER=$smtp_user" >> .env
    echo "N8N_SMTP_PASS=$smtp_pass" >> .env
    echo "N8N_SMTP_SENDER=$smtp_sender" >> .env
    echo "✅ .env file created!"
fi

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

# Start the services
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
    
    # Wait for n8n to be fully ready
    echo "⏳ Waiting for n8n to be fully ready..."
    max_attempts=30
    attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s -o /dev/null -w "%{http_code}" http://localhost:5678 | grep -q "200"; then
            echo "✅ n8n is responding and ready!"
            break
        else
            echo "   Attempt $((attempt + 1))/$max_attempts - n8n is starting up..."
            sleep 5
            attempt=$((attempt + 1))
        fi
    done
    
    if [ $attempt -eq $max_attempts ]; then
        echo "⚠️  n8n may still be starting up. Please wait a moment and try accessing it."
    fi
    
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
    echo ""
    
    # Ask if user wants to set up Cloudflare Tunnel
    read -p "🔒 Do you want to set up Cloudflare Tunnel for secure remote access? (y/N): " setup_tunnel
    if [[ $setup_tunnel =~ ^[Yy]$ ]]; then
        echo ""
        if [ -f "setup-cloudflare-tunnel.sh" ]; then
            chmod +x setup-cloudflare-tunnel.sh
            ./setup-cloudflare-tunnel.sh
        else
            echo "❌ setup-cloudflare-tunnel.sh not found in current directory."
            echo "💡 You can set up Cloudflare Tunnel manually with these steps:"
            echo "   1. Install Cloudflare Tunnel (cloudflared):"
            echo "      curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o cloudflared.deb"
            echo "      sudo dpkg -i cloudflared.deb"
            echo "   2. Login to Cloudflare:"
            echo "      cloudflared tunnel login"
            echo "   3. Create a tunnel:"
            echo "      cloudflared tunnel create n8n-tunnel"
            echo "   4. Configure tunnel to point to localhost:5678"
            echo "   5. Run tunnel to secure your n8n instance"
            echo ""
            echo "   📖 Full tutorial: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/"
        fi
    else
        echo "🔒 Cloudflare Tunnel setup skipped."
        echo "💡 You can set it up later by running: ./setup-cloudflare-tunnel.sh"
        echo "   📖 Or follow the manual steps at: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/"
    fi
else
    echo "❌ Some services failed to start. Check logs with:"
    echo "   docker compose logs"
fi

echo ""
echo "🎯 Setup completed successfully!"
