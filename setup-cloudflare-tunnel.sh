#!/bin/bash

# Cloudflare Tunnel setup script for n8n

echo "☁️ Cloudflare Tunnel Setup for n8n"
echo "==================================="
echo ""

# Check if cloudflared is installed
if ! command -v cloudflared &> /dev/null; then
    echo "📥 Installing Cloudflare Tunnel (cloudflared)..."
    
    # Download and install cloudflared
    curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o cloudflared.deb
    
    if sudo dpkg -i cloudflared.deb; then
        echo "✅ Cloudflared installed successfully!"
        rm cloudflared.deb
    else
        echo "❌ Failed to install cloudflared. Please check your system and try again."
        exit 1
    fi
else
    echo "✅ Cloudflared is already installed!"
fi

echo ""

# Check if user is already logged in
if cloudflared tunnel list &> /dev/null; then
    echo "✅ Already logged into Cloudflare!"
else
    echo "🔐 Please login to Cloudflare..."
    echo "   This will open a browser window for authentication."
    read -p "Press Enter to continue..."
    
    if cloudflared tunnel login; then
        echo "✅ Successfully logged into Cloudflare!"
    else
        echo "❌ Failed to login to Cloudflare. Please try again."
        exit 1
    fi
fi

echo ""

# Get tunnel configuration from user
echo "🌐 Domain Configuration:"
echo "1) Use free Cloudflare domain (yourname.cfargotunnel.com)"
echo "2) Use your own custom domain"
echo ""
read -p "Choose option (1/2): " domain_option

if [ "$domain_option" = "2" ]; then
    read -p "Enter your custom domain (e.g., n8n.yourdomain.com): " custom_domain
    if [ -z "$custom_domain" ]; then
        echo "❌ Custom domain cannot be empty."
        exit 1
    fi
    hostname="$custom_domain"
    echo "✅ Using custom domain: $hostname"
else
    read -p "Enter the name for your tunnel (this will be part of your URL): " tunnel_name
    if [ -z "$tunnel_name" ]; then
        echo "❌ Tunnel name cannot be empty."
        exit 1
    fi
    
    # Validate tunnel name (basic validation)
    if [[ ! "$tunnel_name" =~ ^[a-zA-Z0-9-]+$ ]]; then
        echo "❌ Tunnel name can only contain letters, numbers, and hyphens."
        exit 1
    fi
    
    hostname="$tunnel_name.cfargotunnel.com"
    echo "✅ Using Cloudflare domain: $hostname"
fi

echo ""

# Check if tunnel already exists (use tunnel_name for both cases)
tunnel_name_for_creation=${tunnel_name:-$(echo "$custom_domain" | cut -d'.' -f1)}

if cloudflared tunnel list | grep -q "$tunnel_name_for_creation"; then
    echo "⚠️  Tunnel '$tunnel_name_for_creation' already exists!"
    read -p "Do you want to use the existing tunnel? (Y/n): " use_existing
    use_existing=${use_existing:-Y}
    
    if [[ ! $use_existing =~ ^[Yy]$ ]]; then
        echo "❌ Please choose a different tunnel name and run the script again."
        exit 1
    fi
    echo "✅ Using existing tunnel: $tunnel_name_for_creation"
else
    # Create the tunnel
    echo "🔧 Creating tunnel: $tunnel_name_for_creation"
    if cloudflared tunnel create "$tunnel_name_for_creation"; then
        echo "✅ Tunnel '$tunnel_name_for_creation' created successfully!"
    else
        echo "❌ Failed to create tunnel. Please check your permissions and try again."
        exit 1
    fi
fi

echo ""

# Get tunnel ID
tunnel_id=$(cloudflared tunnel list | grep "$tunnel_name_for_creation" | awk '{print $1}')
if [ -z "$tunnel_id" ]; then
    echo "❌ Could not find tunnel ID. Please check the tunnel was created properly."
    exit 1
fi

echo "🔍 Found tunnel ID: $tunnel_id"

# Create config directory if it doesn't exist
config_dir="$HOME/.cloudflared"
mkdir -p "$config_dir"

# Create configuration file
config_file="$config_dir/config.yml"
echo "📝 Creating tunnel configuration..."

cat > "$config_file" << EOF
tunnel: $tunnel_id
credentials-file: $config_dir/$tunnel_id.json

ingress:
  - hostname: $hostname
    service: http://localhost:5678
  - service: http_status:404
EOF

echo "✅ Configuration file created at: $config_file"
echo ""

# Show configuration
echo "📋 Tunnel Configuration:"
echo "========================"
echo "Tunnel Name: $tunnel_name_for_creation"
echo "Tunnel ID: $tunnel_id"
echo "Local Service: http://localhost:5678"
echo "Public URL: https://$hostname"
echo ""

# Set up DNS (route traffic)
echo "🌐 Setting up DNS routing..."
if [ "$domain_option" = "2" ]; then
    echo "⚠️  For custom domains, you need to manually add a CNAME record in Cloudflare:"
    echo "   CNAME: $custom_domain -> $tunnel_id.cfargotunnel.com"
    echo "   Or run: cloudflared tunnel route dns $tunnel_name_for_creation $custom_domain"
else
    if cloudflared tunnel route dns "$tunnel_name_for_creation" "$hostname"; then
        echo "✅ DNS routing configured successfully!"
    else
        echo "⚠️  DNS routing failed. You may need to set this up manually in the Cloudflare dashboard."
    fi
fi

echo ""

# Ask if user wants to start the tunnel now
read -p "🚀 Do you want to start the tunnel now? (Y/n): " start_tunnel
start_tunnel=${start_tunnel:-Y}

if [[ $start_tunnel =~ ^[Yy]$ ]]; then
    echo ""
    echo "🚀 Starting Cloudflare Tunnel..."
    echo "   Your n8n instance will be available at: https://$hostname"
    echo "   Press Ctrl+C to stop the tunnel"
    echo ""
    
    # Start the tunnel
    cloudflared tunnel run "$tunnel_name_for_creation"
else
    echo ""
    echo "📝 Tunnel setup complete! To start the tunnel later, run:"
    echo "   cloudflared tunnel run $tunnel_name_for_creation"
    echo ""
    echo "🌐 Your n8n instance will be available at:"
    echo "   https://$hostname"
    echo ""
    echo "🔧 To run tunnel as a service (background), run:"
    echo "   sudo cloudflared service install"
    echo "   sudo systemctl start cloudflared"
    echo "   sudo systemctl enable cloudflared"
fi

echo ""
echo "🎯 Cloudflare Tunnel setup completed successfully!"
echo ""
echo "💡 Tips:"
echo "   - Your tunnel is now secure and accessible from anywhere"
echo "   - No need to open firewall ports"
echo "   - Traffic is encrypted end-to-end"
echo "   - Manage your tunnel at: https://one.dash.cloudflare.com/"
