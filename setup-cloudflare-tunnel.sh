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

# Check if tunnel already exists
if cloudflared tunnel list | grep -q "$tunnel_name"; then
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
    if cloudflared tunnel create "$tunnel_name"; then
        echo "✅ Tunnel '$tunnel_name' created successfully!"
    else
        echo "❌ Failed to create tunnel. Please check your permissions and try again."
        exit 1
    fi
fi

echo ""

# Get tunnel ID
tunnel_id=$(cloudflared tunnel list | grep "$tunnel_name" | awk '{print $1}')
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
echo "Tunnel Name: $tunnel_name"
echo "Tunnel ID: $tunnel_id"
echo "Local Service: http://localhost:5678"
echo "Public URL: https://$hostname"
echo ""

# Install and start tunnel as a service
echo "🔧 Installing Cloudflare Tunnel as a system service..."

# Verify config file exists
if [ ! -f "$config_file" ]; then
    echo "❌ Config file not found at $config_file"
    exit 1
fi

echo "✅ Config file found at: $config_file"

# Try different methods to install the service
echo "📝 Attempting service installation..."

# Method 1: Install with explicit config path
if sudo cloudflared --config "$config_file" service install; then
    echo "✅ Cloudflare Tunnel service installed successfully (Method 1)!"
    service_installed=true
elif sudo cloudflared service install --config "$config_file"; then
    echo "✅ Cloudflare Tunnel service installed successfully (Method 2)!"
    service_installed=true
else
    # Method 3: Copy config to system location and install
    echo "⚠️  Standard installation failed. Trying system config location..."
    sudo mkdir -p /etc/cloudflared
    sudo cp "$config_file" /etc/cloudflared/config.yml
    sudo cp "$config_dir/$tunnel_id.json" /etc/cloudflared/
    
    # Update config to use system paths
    sudo sed -i "s|$config_dir|/etc/cloudflared|g" /etc/cloudflared/config.yml
    
    if sudo cloudflared service install; then
        echo "✅ Cloudflare Tunnel service installed successfully (Method 3)!"
        service_installed=true
    else
        echo "❌ All installation methods failed."
        service_installed=false
    fi
fi

if [ "$service_installed" = true ]; then

if [ "$service_installed" = true ]; then
    # Start the service
    echo "🚀 Starting Cloudflare Tunnel service..."
    if sudo systemctl start cloudflared; then
        echo "✅ Cloudflare Tunnel service started!"
    else
        echo "❌ Failed to start Cloudflare Tunnel service."
        echo "📋 Checking service status..."
        sudo systemctl status cloudflared --no-pager -l
        exit 1
    fi

    # Enable service to start on boot
    echo "⚙️  Enabling Cloudflare Tunnel service to start on boot..."
    if sudo systemctl enable cloudflared; then
        echo "✅ Cloudflare Tunnel service enabled for auto-start!"
    else
        echo "⚠️  Warning: Failed to enable auto-start for Cloudflare Tunnel service."
    fi

    # Check service status
    echo ""
    echo "📊 Service Status:"
    sudo systemctl status cloudflared --no-pager -l

    echo ""
    echo "🎉 Cloudflare Tunnel setup complete!"
    echo ""
    echo "🌐 Your n8n instance is now available at: https://$hostname"
    echo "🔧 Service commands:"
    echo "   Check status: sudo systemctl status cloudflared"
    echo "   Stop service: sudo systemctl stop cloudflared"
    echo "   Start service: sudo systemctl start cloudflared"
    echo "   View logs: sudo journalctl -u cloudflared -f"
else
    echo ""
    echo "❌ Service installation failed. You can try running the tunnel manually:"
    echo "   cloudflared tunnel run $tunnel_name"
    echo ""
    echo "🌐 Your n8n instance should still be available at: https://$hostname"
    echo "   (when running the tunnel manually)"
fi
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
