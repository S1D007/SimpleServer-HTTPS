#!/bin/bash

# Update the system
sudo apt-get update

# Pull your repository from the specified URL
echo "Enter the repository URL:"
read repo_url
# extract the directory name from the Git repo 
repo_directory=$(basename "$repo_url" .git)
git clone "$repo_url" "$repo_directory"


# Install NVM
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash

# Load NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install Node.js 18
nvm install 18

# Install npm packages
cd "$repo_directory"
npm install

# Initialize an array to store files to be copied
files_to_copy=()

# Prompt the user for source and destination paths
while true; do
  echo "Enter the source file or folder path (or 'done' to finish):"
  read source_path
  if [ "$source_path" = "done" ]; then
    break
  fi

  echo "Enter the destination path:"
  read destination_path

  # Add the source and destination paths to the array
  files_to_copy+=("$source_path" "$destination_path")
done

# Copy files from source to destination
for ((i = 0; i < ${#files_to_copy[@]}; i+=2)); do
  source="${files_to_copy[$i]}"
  destination="${files_to_copy[$i + 1]}"
  cp -r "$source" "$destination"
done

# Build the project
npm run build

# Install PM2
npm install pm2 -g

# Start your application with PM2
echo "Enter your PM2 app name:"
read pm2_app_name
pm2 start app.js --name "$pm2_app_name"

# Start PM2 on system startup
pm2 startup

# Install Caddy
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt-get install caddy

# Create a CaddyFile with reverse proxy configuration
echo "Enter your EC2 IP:"
read ec2_ip
echo "Enter the port of your app:"
read app_port
echo "${ec2_ip}.nip.io {
  reverse_proxy localhost:$app_port
}" | sudo tee /etc/caddy/Caddyfile

# Start Caddy
sudo systemctl start caddy

# Exit with a message
echo "Thanks! Happy Coding!"