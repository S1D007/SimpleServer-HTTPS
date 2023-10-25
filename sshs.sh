#!/bin/bash

# Function to revert changes
revert_changes() {
  echo "Reverting changes..."
  # Revert the system to the initial state
  # Add necessary commands here to revert changes made by the script
  echo "Reverted successfully."
}

# Function to display help
display_help() {
  echo "This script automates the setup and deployment process for your project."
  echo "Usage: bash script_name.sh"
  echo "Options:"
  echo "  -h, --help     Display this help message."
  echo "  -r, --revert   Revert changes made by this script."
  exit 0
}

# Error handling function
handle_error() {
  echo "An error occurred. Reverting changes..."
  revert_changes
  exit 1
}

# Trap errors
trap 'handle_error' ERR

# Display help if requested
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
  display_help
fi

# Function to display a loading animation
show_spinner() {
  local -r pid="$1"
  local -r delay='0.75'
  local spinstr='|/-\'
  while [ "$(ps a | awk '{print $1}' | grep "$pid")" ]; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep "$delay"
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
}

# Update the system
echo "Updating the system..."
sudo apt-get update &> /dev/null &
show_spinner "$!"

# Pull your repository from the specified URL
echo "Enter the repository URL:"
read -r repo_url
repo_directory=$(basename "$repo_url" .git)
echo "Downloading the repository..."
git clone "$repo_url" "$repo_directory" &> /dev/null &
show_spinner "$!"

# Install NVM
echo "Installing NVM..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash &> /dev/null &
show_spinner "$!"

# Load NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install Node.js 18
echo "Installing Node.js 18..."
nvm install 18 &> /dev/null &
show_spinner "$!"

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

  # Check if the source file or folder exists
  if [ ! -e "$source_path" ]; then
    echo "Source file or folder does not exist: $source_path"
  else
    # Add the source and destination paths to the array
    files_to_copy+=("$source_path" "$destination_path")
  fi
done

# Copy files from source to destination
for ((i = 0; i < ${#files_to_copy[@]}; i+=2)); do
  source="${files_to_copy[$i]}"
  destination="${files_to_copy[$i + 1]}"
  mkdir -p "$(dirname "$destination")"
  cp -r "$source" "$destination"
done

# Build the project
npm run build

# Install PM2
npm install pm2 -g

# Start your application with PM2
echo "Enter your PM2 app name:"
read pm2_app_name
echo "Type the Entry File Name (ex: dist/index.js, index.js, src/index.js etc):"
read entry_file
pm2 start "$entry_file" --name "$pm2_app_name"

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

caddy_config="${ec2_ip}.nip.io {
  reverse_proxy localhost:$app_port
}"
echo "$caddy_config" | sudo tee /etc/caddy/Caddyfile > /dev/null

# Start Caddy
cd /etc/caddy
caddy stop
caddy start
#Before Running the Caddfile we have to reload the caddy so that it can use the newly added config File :)
caddy reload
# Now Running makes Sense
caddy run
# Exit with a message
echo "Thanks For Using SSHS! Happy Coding!"
