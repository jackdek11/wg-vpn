#!/bin/sh
# Copyright (c) 2023, Cyber-Mint (Pty) Ltd
# License MIT: https://opensource.org/licenses/MIT

# Variables
wireguard_package_path="$HOME/{{ wireguard_package_path }}"
private_key="{{ private_key }}"
server_public_key="{{ server_public_key }}"
client_address="{{ client_address }}"
allowed_ips="{{ allowed_ips }}"
endpoint="{{ endpoint }}"
tunnels_file=$wireguard_package_path/tunnels.txt

# Config file
_file=$wireguard_package_path/wg0.conf

displayVersion() {
  # This function displays the version information and license for the application.

  echo "wg-vpn (https://github/com/cyber-mint/wg-vpn) version {{ wireguard_package_version }}"
  echo "Copyright (C) 2023, Cyber-Mint (Pty) Ltd"
  echo "License MIT: https://opensource.org/licenses/MIT"
  echo ""
}

alignTunnels(){
  # This function rebuilds the wg0.conf file (and particular the AllowedIps) to before post-up and connect.

  tunnels=$(cat "$tunnels_file")
  _allowed_ips=""
  while IFS= read -r _tunnel; do
    _tunnel="${_tunnel#"${_tunnel%%[![:space:]]*}"}"
    _tunnel="${_tunnel%"${_tunnel##*[![:space:]]}"}"
    if [ -z "$_allowed_ips" ]; then
      _allowed_ips="$_tunnel"
    else
      _allowed_ips="$_allowed_ips, $_tunnel"
    fi
  done <<END
    $tunnels
END
  allowed_ips="$_allowed_ips"
  rm $_file
  create_config_file
}

displayStatus() {
  # This function displays the status of the WireGuard VPN connection.

  echo "wg-vpn Status"
  echo "================================================"
  sudo wg
}

createpostUpScript() {
  touch "$wireguard_package_path/postUp.sh"
  echo "#!/bin/sh"
  echo 'echo "    _________        ___.                             _____  .__        __            "' >"$wireguard_package_path/postUp.sh"
  echo 'echo "    \_   ___ \___.__.\_ |__   ___________            /     \ |__| _____/  |_          "' >"$wireguard_package_path/postUp.sh"
  echo 'echo "    /    \  \<   |  | | __ \_/ __ \_  __ \  ______  /  \ /  \|  |/    \   __\         "' >"$wireguard_package_path/postUp.sh"
  echo 'echo "    \     \___\___  | | \_\ \  ___/|  | \/ /_____/ /    Y    \  |   |  \  |           "'>"$wireguard_package_path/postUp.sh"
  echo 'echo "     \______  / ____| |___  /\___  >__|            \____|__  /__|___|  /__| (Pty) Ltd "'>"$wireguard_package_path/postUp.sh"
  echo 'echo "            \/\/          \/     \/                        \/        \/               "'>"$wireguard_package_path/postUp.sh"
  echo 'wireguard_package_path='"$wireguard_package_path"''>"$wireguard_package_path/postUp.sh"
  echo 'tunnels_file='"$wireguard_package_path"'/tunnels.txt'>"$wireguard_package_path/postUp.sh"
  echo 'client_address="'$client_address'"'>"$wireguard_package_path/postUp.sh"
  echo 'tunnels=$(cat "$tunnels_file")'>"$wireguard_package_path/postUp.sh"
  echo 'while IFS= read -r _tunnel; do'>"$wireguard_package_path/postUp.sh"
  echo '    echo [#] ip -4 route change $_tunnel via $client_address'>"$wireguard_package_path/postUp.sh"
  echo '    eval "sudo ip -4 route change $_tunnel via $client_address"'>"$wireguard_package_path/postUp.sh"
  echo 'done <<END'>"$wireguard_package_path/postUp.sh"
  echo '    $tunnels'>"$wireguard_package_path/postUp.sh"
  echo 'END'>"$wireguard_package_path/postUp.sh"
  echo "">"$wireguard_package_path/postUp.sh"
  sudo chmod +x "$wireguard_package_path/postUp.sh"
}

initialize_tunnels() {
  # Read the contents of the tunnels_file into the list

  if [ -f "$tunnels_file" ]; then
    # If the file exists, read its contents into the list

    tunnels=$(cat "$tunnels_file")
  else
    touch "$tunnels_file"
    echo "{{ initial_tunnels }}" > "$tunnels_file"
    initialize_tunnels
  fi
}

save_tunnels() {
  # Save the content of the tunnels into the tunnels_file

  echo "$tunnels" >"$tunnels_file"
  show
}

add_to_tunnels() {
  # Check if $1 is not in tunnels

  if ! echo "$tunnels" | grep -q "$1"; then
    # Add the new routes to existing tunnels
    tunnels="$tunnels\n$1"

    # Update the tunnels_file
    save_tunnels
  else
    echo "$1 is already in tunnels."
    exit 1
  fi
}

remove_from_tunnels() {
  # Create a new tunnels without the element to be removed
  new_tunnels=""
  while IFS= read -r _tunnel; do
    if [ "$_tunnel" != "$1" ]; then
      [ -n "$new_tunnels" ] && new_tunnels="$new_tunnels\n"
      new_tunnels="$new_tunnels$_tunnel"
    fi
  done <<END
$tunnels
END
  # Assign the new_tunnels back to the tunnels variable
  tunnels="$new_tunnels"
  # Update the tunnels_file
  save_tunnels
}

show() {
  # Read the variables from the list_file and display with formatting
  index=1
  echo "wg-vpn routes"
  echo "====================="
  while IFS= read -r line; do
    echo " [$index] $line"
    index=$((index + 1))
  done <"$tunnels_file"
}

connect() {
  # This function is responsible for connecting to the WireGuard VPN.

  alignTunnels
  if [ "$_quiet" -eq 1 ]; then
    sudo wg-quick up "$_file" >/dev/null
  else
    sudo wg-quick up "$_file"
  fi
}
disconnect() {
  # This function is responsible for disconnecting from the WireGuard VPN.

  sudo wg-quick down $_file
}

install_wireguard() {
  # This function checks if WireGuard is installed and installs it if necessary.

  echo "Checking if WireGuard is installed..."

  # Check if the 'wireguard' command is available in the system's PATH using 'command -v'.
  # The output is redirected to /dev/null to suppress it.
  if ! command -v wireguard >/dev/null; then
    echo "WireGuard is not installed. Installing..."

    # Update the package lists and install WireGuard using the package manager (apt).
    sudo apt update
    sudo apt install wireguard
  else
    echo "WireGuard is already installed."
  fi
}

create_config_file() {
  # This function creates or recreates the configuration file for the WireGuard VPN.

  local file="$wireguard_package_path/wg0.conf"

  # Create / Recreate an empty config file., suppressing any errors that may occur.
  echo "Creating/recreating the config file: $file"
  rm "$file" >/dev/null 2>&1 || true
  touch "$file"

  # [Interface] section
  echo "[Interface]" >>"$file"
  echo "SaveConfig = false" >>"$file"
  echo "PrivateKey = $private_key" >>"$file"
  echo "Address = $client_address" >>"$file"
  echo "MTU = 1500" >>"$file"
  echo "PostUp = $wireguard_package_path/postUp.sh" >>"$file"
  echo "" >>"$file"

  # [Peer] section
  echo "[Peer]" >>"$file"
  echo "PublicKey = $server_public_key" >>"$file"
  echo "AllowedIPs = $allowed_ips" >>"$file"
  echo "Endpoint = $endpoint" >>"$file"

  echo "Config file created: $file"
  chmod 600 "$file"
}

install() {
  # This function installs WireGuard by executing a series of setup steps.

  mkdir -p "$wireguard_package_path"

  install_wireguard

  create_config_file
}

uninstall() {
  # This function performs the uninstallation of WireGuard.

  disconnect

  sudo apt remove wireguard

  sudo apt autoclean

  sudo apt autoremove

  rm -rf "$wireguard_package_path"
}

displayHelp() {
  # This function displays the help message with usage instructions for the wg-vpn script.

  echo "Usage wg-vpn [COMMAND].. [OPTION]"
  echo "   wg-vpn is a WireGuard wrapper to easily run a peer with a wg-vpn server"
  echo ""
  echo "  [COMMAND]:"
  echo "    up,UP           bring the peer VPN connection up"
  echo "    down,DOWN       bring the peer VPN connection down"
  echo "    status          show status of wg-vpn service"
  echo "    uninstall       uninstall wg-vpn"
  echo "    show            show destination IPs reached via VPN"
  echo "    add             add a new route to tunnels"
  echo ""
  echo "  [OPTION]:"
  echo "    -q, --quiet     produces no terminal output,"
  echo "                    except setting bash return value \$? = 1 if failures found."
  echo "        --version   display the version and exit"
  echo "        --help      display this help and exit"
  echo ""
  echo ""
  echo "  EXAMPLE(s):"
  echo "      wg-vpn up -q"
  echo "      wg-vpn down"
  echo "      wg-vpn status"
  echo ""
}

_quiet="0"
while [ $# -gt 0 ]; do
  case "$1" in
  "--status" | "-s" | "status")
    # Display the status of the WireGuard VPN connection
    displayStatus
    exit 0
    ;;
  "--help" | "-h" | "help")
    # Display the help message with usage instructions
    displayHelp
    exit 0
    ;;
  "--version" | "-v" | "version")
    # Display the version information
    displayVersion
    exit 0
    ;;
  "up" | "UP")
    # Connect to the WireGuard VPN
    initialize_tunnels
    connect
    exit 0
    ;;
  "-f" | "--file")
    _file="$2"
    shift
    ;;
  "down" | "DOWN")
    # Disconnect from the WireGuard VPN
    disconnect
    exit 0
    ;;
  "-q" | "--quiet")
    # Enable quiet mode with no terminal output, except for failure indications
    _quiet="1"
    ;;
  "add")
    initialize_tunnels
    add_to_tunnels $2
    exit 0
    ;;
  "reload")
    disconnect
    connect
    exit 0
    ;;
  "remove")
    initialize_tunnels
    remove_from_tunnels $2
    exit 0
    ;;
  "--show")
    # Enable quiet mode with no terminal output, except for failure indications
    show
    exit 0
    ;;
  "uninstall")
    # Uninstall WireGuard
    uninstall
    exit 0
    ;;
  *)
    # Unknown parameter passed
    echo "Unknown parameter passed: $1"
    exit 1
    ;;
  esac
  shift
done

FILE="$0"
if [ ! "$FILE" -ef "$wireguard_package_path/wg-vpn" ]; then
  # Check if the script file is not the same as "$wireguard_package_path/wg-vpn"

  if [ ! -f "$wireguard_package_path/wg-vpn" ]; then
    # If "$wireguard_package_path/wg-vpn" does not exist, perform uninstallation
    uninstall
  fi

  # Perform installation
  install
  initialize_tunnels

  # Create "$wireguard_package_path/wg-vpn" file and copy the script contents to it
  touch "$wireguard_package_path/wg-vpn"
  cat "$FILE" >"$wireguard_package_path/wg-vpn"

  # Remove the original script file
  rm -f "$FILE"

  # Change the permissions of "$wireguard_package_path/wg-vpn" to make it executable
  sudo chmod +x "$wireguard_package_path/wg-vpn"

  if [ -d "$HOME/.local/bin" ]; then
    # User has the folder "$HOME/.local/bin", put the executable file there
    ln -sf "$wireguard_package_path/wg-vpn" "$HOME/.local/bin/wg-vpn" >/dev/null
  else
    # User doesn't have the folder "$HOME/.local/bin", add "$wireguard_package_path" to PATH
    echo "export PATH=\"$wireguard_package_path:\$PATH\"" >>"$HOME/.bashrc"
    echo "Please run 'source ~/.bashrc' to update your paths"
  fi

  displayVersion
  exit 0
fi

# If none of the conditions are met, display a message to suggest using "--help" for help
echo "Try wg-vpn --help for help"
