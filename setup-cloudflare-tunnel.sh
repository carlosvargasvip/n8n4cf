#!/bin/bash

# Cloudflare Tunnel setup script for n8n using Docker

echo "☁️ Cloudflare Tunnel Setup for n8n (Docker)"
echo "============================================="
echo ""

# Check if docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose plugin is not available. Please update Docker to a recent version."
    exit 1
fi

echo "✅ Docker and Docker Compose are available!"
echo ""

# Get tunnel configuration from user
echo "🌐 Domain Configuration:"
echo ""
read -p "Enter your domain (e.g., yourdomain.com): " user_domain

if [ -z "$user_domain" ]; then
    echo "❌ Domain cannot be empty."
    exit 1
fi

read -p "Enter subdomain for n8n (e.g., n8n): " subdomain
if [ -z "$subdomain" ]; then
    echo "❌ Subdomain cannot be empty."
    exit 1
fi

# Validate subdomain (basic validation)
if [[ ! "$subdomain" =~ ^[a-zA-Z0-9-]+$ ]]; then
    echo "❌ Subdomain can only contain letters, numbers, and hyphens."
    exit 1
fi

hostname="$subdomain.$user_domain"
tunnel_name="$subdomain"

echo "✅ Using domain: $hostname"
echo ""

# Check if user is logged in to Cloudflare
echo "🔐 Logging into Cloudflare..."
echo "   This will open a browser window for authentication."
read -p "Press Enter to continue..."

# Login using Docker
if docker run --rm -v ~/.cloudflared:/home/nonroot/.cloudflared cloudflare/cloudflared:latest tunnel login; then
    echo "✅ Successfully logged into Cloudflare!"
else
    echo "❌ Failed to login to Cloudflare. Please try again."
    exit 1
fi

echo ""

# Check if tunnel already exists
echo "🔍 Checking for existing tunnels..."
if docker run --rm -v ~/.cloudflared:/home/nonroot/.cloudflared cloudflare/cloudflared:latest tunnel list | grep -q "$tunnel_name"; then
    echo "⚠️  Tunnel '$tunnel_name' already exists!"
    read -p "Do you want to use the existing tunnel? (Y/n): " use_existing
    use_existing=${use_existing:-Y}
    
    if [[ ! $use_existing =~ ^[Yy]$ ]]; then
        echo "❌ Please choose a different tunnel name and run the script again."
        exit 1
    fi
    echo "✅ Using existing tunnel: $tunnel_name"
else
    # Create the tunnel
    echo "🔧 Creating tunnel: $tunnel_name"
    if docker run --rm -v ~/.cloudflared:/home/nonroot/.cloudflared cloudflare/cloudflared:latest tunnel create "$tunnel_name"; then
        echo "✅ Tunnel '$tunnel_name' created successfully!"
    else
        echo "❌ Failed to create tunnel. Please check your permissions and try again."
        exit 1
    fi
fi

echo ""

# Get tunnel ID
echo "🔍 Getting tunnel ID..."
tunnel_id=$(docker run --rm -v ~/.cloudflared:/home/nonroot/.cloudflared cloudflare/cloudflared:latest tunnel list | grep "$tunnel_name" | awk '{print $1}')
if [ -z "$tunnel_id" ]; then
    echo "❌ Could not find tunnel ID. Please check the tunnel was created properly."
    exit 1
fi

echo "🔍 Found tunnel ID: $tunnel_id"

# Create configuration file
config_file="$HOME/.cloudflared/config.yml"
echo "📝 Creating tunnel configuration..."

cat > "$config_file" << EOF
tunnel: $tunnel_id
credentials-file: /home/nonroot/.cloudflared/$tunnel_id.json

ingress:
  - hostname: $hostname
    service: http://host.docker.internal:5678
  - service: http_status:404
EOF

echo "✅ Configuration file created at: $config_file"
echo ""

# Show configuration
echo "📋 Tunnel Configuration:"
echo "========================"
echo "Tunnel Name: $tunnel_name"
echo "Tunnel ID: $tunnel_id"
echo "Local Service: http://host.docker.internal:5678"
echo "Public URL: https://$hostname"
echo ""

# Start the tunnel service using the tunnel profile
echo "🚀 Starting Cloudflare Tunnel service..."

if docker compose --profile tunnel up -d cloudflared; then
    echo "✅ Cloudflare Tunnel service started!"
    
    # Check service status
    echo ""
    echo "📊 Service Status:"
    docker compose ps cloudflared
    
    echo ""
    echo "🎉 Cloudflare Tunnel setup complete!"
    echo ""
    echo "🌐 Your n8n instance is now available at: https://$hostname"
    echo "🔧 Service commands:"
    echo "   Check status: docker compose ps cloudflared"
    echo "   View logs: docker compose logs cloudflared -f"
    echo "   Stop tunnel: docker compose --profile tunnel stop cloudflared"
    echo "   Start tunnel: docker compose --profile tunnel start cloudflared"
    echo ""
    echo "💡 Note: You still need to add a CNAME record in Cloudflare DNS:"
    echo "   Type: CNAME"
    echo "   Name: $subdomain"
    echo "   Target: $tunnel_id.cfargotunnel.com"
    echo "   Proxy status: Proxied (orange cloud)"
else
    echo "❌ Failed to start Cloudflare Tunnel service."
    echo "📋 Check logs with: docker compose logs cloudflared"
    exit 1
fi

echo ""
echo "🎯 Cloudflare Tunnel setup completed successfully!"
