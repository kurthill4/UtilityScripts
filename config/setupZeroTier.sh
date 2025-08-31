#!/bin/bash

# =================================================================
# ZeroTier Configuration Script for Ephemeral Environments
# =================================================================
# This script automates the process of managing a persistent ZeroTier identity
# in environments like JupyterHub where the file system resets on each session.
# It saves the ZeroTier identity files to your home directory, allowing you to
# join a network only once without needing re-authorization.
# =================================================================

# --- Configuration ---
# Set the desired persistent directory within your home folder.
# This directory will store your ZeroTier identity and configuration.
PERSISTENT_ZT_DIR="$HOME/.zerotier"

# Set the Network ID you wish to join (optional, but convenient)
NETWORK_ID="db64858fedbd3c8b"

# =================================================================
# PART 1: FIRST-RUN SETUP
# Run this block only ONE time. It installs ZeroTier, saves the identity,
# and performs the initial network join.
# If the /var/lib/zerotier directory exists, we have already installed ZT
# =================================================================
if [ ! -d "/var/lib/zerotier-one" ]; then
    # Install ZeroTier
    echo "-> Installing ZeroTier..."
    curl -s 'https://raw.githubusercontent.com/zerotier/ZeroTierOne/main/doc/contact@zerotier.com.gpg' | gpg --import && \
    if z=$(curl -s 'https://install.zerotier.com/' | gpg); 
        then echo "$z" | sudo bash; 
    fi

fi

# At this point ZT has either already been installed (and therefore is starting or runnning as a service)
# Wait for the service to start and create the identity.  Using wait is not the best approach, but OK for
# now; if it somehow errors out, we can just re-run the script.
echo "-> Waiting for service to start and generate identity..."
sleep 5

# Stop the default ZeroTier service
echo "-> Stopping default service to copy identity files..."
sudo systemctl stop zerotier-one.service

# At this point, ther service has been installed and is stopped.
# Now check for the existence of persisted files and create them if needed.

if [ ! -d "$PERSISTENT_ZT_DIR" ]; then

    # Create the persistent directory
    mkdir -p "$PERSISTENT_ZT_DIR"
    
    # Copy identity and network files
    echo "-> Copying identity files to persistent storage ($PERSISTENT_ZT_DIR)..."
    sudo cp /var/lib/zerotier-one/identity.* "$PERSISTENT_ZT_DIR"/
    sudo cp -r /var/lib/zerotier-one/networks.d "$PERSISTENT_ZT_DIR"/

    # Fix permissions on the copied files
    sudo chown -R $USER:$USER "$PERSISTENT_ZT_DIR"

    echo "-> ZeroTier identity saved. This is a one-time process."
    echo "-> Please authorize this device in the ZeroTier Central web UI now."
fi

# At this point ZT is installed, stopped and persisted data exists.
# Start ZeroTier with the new persistent identity
echo "-> Starting ZeroTier with the persistent identity..."
sudo /usr/sbin/zerotier-one -d "$PERSISTENT_ZT_DIR"

# Join the network (you'll only need to authorize it once)
if [ -n "$NETWORK_ID" ]; then
    echo "-> Joining network: $NETWORK_ID"
    sudo /usr/sbin/zerotier-cli -D "$PERSISTENT_ZT_DIR" join "$NETWORK_ID"
fi

# Check the status to confirm it's working
echo "-> Checking ZeroTier status..."
sudo /usr/sbin/zerotier-cli -D "$PERSISTENT_ZT_DIR" status

echo "ZeroTier has been started and is using the persistent identity."