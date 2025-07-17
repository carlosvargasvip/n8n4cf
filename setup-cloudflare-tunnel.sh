#!/bin/bash

# Cloudflare Tunnel setup script for n8n using installed cloudflared

echo "☁️ Cloudflare Tunnel Setup for n8n"
echo "===================================="
echo ""

# Check if cloudflared is installed, if not install it
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

# Detect the machine's IP address
echo ""
echo "🔍 Detecting machine IP address..."

# Try multiple methods to get IP address
ip_address=""

# Method 1: Try to get IP from default route
if [ -z "$ip_address" ]; then
    ip_address=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' | head -1)
fi

# Method 2: Try hostname -I
if [ -z "$ip_address" ]; then
    ip_address=$(hostname -I 2>/dev/null | awk '{print $1}')
fi

# Method 3: Try ip addr show
if [ -z "$ip_address" ]; then
    ip_address=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d'/' -f1 | head -1)
fi

# Method 4: Fallback to ifconfig if available
if [ -z "$ip_address" ] && command -v ifconfig &> /dev/null; then
    ip_address=$(ifconfig | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | head -1)
fi

if [ -z "$ip_address" ]; then
    echo "❌ Could not automatically detect IP address."
    read -p "Please enter your machine's IP address: " ip_address
    if [ -z "$ip_address" ]; then
        echo "❌ IP address cannot be empty."
        exit 1
    fi
fi

echo "✅ Detected IP address: $ip_address"

# Create config directory if it doesn't exist
config_dir="$HOME/.cloudflared"
mkdir -p "$config_dir"

# Create configuration file
config_file="$config_dir/config.yml"
echo "📝 Creating tunnel configuration..."

cat > "$config_file" << EOF
tunnel: $tunnel_id
credentials-file: $config_dir/$tunnel_id.json

# Disable ICMP proxy to avoid permission warnings
no-icmp-proxy: true

ingress:
  - hostname: $hostname
    service: http://$ip_address:5678
  - service: http_status:404
EOF

echo "✅ Configuration file created at: $config_file"
echo ""

# Set up DNS routing
echo "🌐 Setting up DNS routing..."
if cloudflared tunnel route dns "$tunnel_name" "$hostname"; then
    echo "✅ DNS routing configured successfully!"
else
    echo "⚠️  DNS routing failed. You may need to set this up manually in the Cloudflare dashboard."
    echo "   Add a CNAME record: $subdomain -> $tunnel_id.cfargotunnel.com"
fi

echo ""

# Show configuration
echo "📋 Tunnel Configuration:"
echo "========================"
echo "Tunnel Name: $tunnel_name"
echo "Tunnel ID: $tunnel_id"
echo "Local Service: http://$ip_address:5678"
echo "Public URL: https://$hostname"
echo ""

# Install and start tunnel as a service
echo "🔧 Installing Cloudflare Tunnel as a system service..."

# Clean up any existing conflicting configs
if [ -f "/etc/cloudflared/config.yml" ]; then
    echo "⚠️  Removing existing system config to avoid conflicts..."
    sudo rm -f /etc/cloudflared/config.yml
    sudo rm -f /etc/cloudflared/*.json
fi

# Try different methods to install the service
echo "📝 Attempting service installation..."

# Method 1: Install with explicit config path using correct flag syntax
if sudo cloudflared --config="$config_file" service install; then
    echo "✅ Cloudflare Tunnel service installed successfully!"
    service_installed=true
else
    # Method 2: Copy config to system location and install
    echo "⚠️  User config installation failed. Trying system config location..."
    sudo mkdir -p /etc/cloudflared
    sudo cp "$config_file" /etc/cloudflared/config.yml
    sudo cp "$config_dir/$tunnel_id.json" /etc/cloudflared/
    
    # Update config to use system paths
    sudo sed -i "s|$config_dir|/etc/cloudflared|g" /etc/cloudflared/config.yml
    
    if sudo cloudflared service install; then
        echo "✅ Cloudflare Tunnel service installed successfully!"
        service_installed=true
    else
        echo "❌ All installation methods failed."
        service_installed=false
    fi
fi

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
echo "🎯 Cloudflare Tunnel setup completed successfully!"
