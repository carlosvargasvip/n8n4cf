#!/bin/bash

# Get the actual user (not root) even if script is run with sudo
ACTUAL_USER=${SUDO_USER:-$(whoami)}
echo "Installing Docker for user: $ACTUAL_USER"

# Update package index
sudo apt-get update

# Install prerequisites
sudo apt-get install ca-certificates curl gnupg -y

# Create keyrings directory
sudo install -m 0755 -d /etc/apt/keyrings

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index with Docker packages
sudo apt-get update

# Install Docker packages
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

# Add the actual user to docker group
echo "Adding user '$ACTUAL_USER' to docker group..."
sudo usermod -aG docker $ACTUAL_USER

# Start and enable Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Verify the user was added to docker group
if getent group docker | grep -q $ACTUAL_USER; then
    echo "Successfully added $ACTUAL_USER to docker group"
else
    echo "Warning: Failed to add $ACTUAL_USER to docker group"
fi

echo "Docker installation complete!"
echo "Rebooting in 5 seconds to apply group changes..."
sleep 5
sudo reboot
