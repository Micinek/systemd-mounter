#!/bin/bash

CONFIG_FILE="mounts.yaml"
SYSTEMD_DIR="/etc/systemd/system"
LAST_FILE="/tmp/mounts.last"

# Check if yq is installed
if ! command -v yq &> /dev/null; then
    echo "Error: 'yq' is not installed. Please install it first."
    exit 1
fi

# Read YAML and generate .mount files
echo "Reading $CONFIG_FILE..."
MOUNTS=$(yq e '.mounts | length' "$CONFIG_FILE")

# Create an array to store current mount units
CURRENT_MOUNTS=()

# Read the last run units from the .last file (if it exists)
if [ -f "$LAST_FILE" ]; then
    mapfile -t LAST_MOUNTS < "$LAST_FILE"
else
    LAST_MOUNTS=()
fi

# Generate new mount units and store the names
for ((i=0; i<MOUNTS; i++)); do
    NAME=$(yq e ".mounts[$i].name" "$CONFIG_FILE")
    WHAT=$(yq e ".mounts[$i].what" "$CONFIG_FILE")
    WHERE=$(yq e ".mounts[$i].where" "$CONFIG_FILE")
    TYPE=$(yq e ".mounts[$i].type" "$CONFIG_FILE")
    OPTIONS=$(yq e ".mounts[$i].options" "$CONFIG_FILE")
    BEFORE_DOCKER=$(yq e ".mounts[$i].before_docker" "$CONFIG_FILE")

    # Convert path to systemd-friendly unit name
    MOUNT_UNIT_NAME="$(echo "${WHERE}" | sed 's|^/||; s|/|-|g').mount"
    MOUNT_UNIT_PATH="$SYSTEMD_DIR/$MOUNT_UNIT_NAME"
    echo "Creating systemd mount unit: $MOUNT_UNIT_PATH"

    # Create new unit file
    cat <<EOF | sudo tee "$MOUNT_UNIT_PATH" > /dev/null
[Unit]
Description=Mount $NAME
Requires=network-online.target
After=network-online.target
$( [[ "$BEFORE_DOCKER" == "true" ]] && echo "Before=docker.service")

[Mount]
What=$WHAT
Where=$WHERE
Type=$TYPE
Options=$OPTIONS

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start the mount unit
    sudo systemctl daemon-reload
    sudo systemctl enable --now "$MOUNT_UNIT_NAME"

    # Add the unit to the list of current mounts
    CURRENT_MOUNTS+=("$MOUNT_UNIT_NAME")
done

# Cleanup old mount units that are no longer in the current list
for OLD_UNIT in "${LAST_MOUNTS[@]}"; do
    if [[ ! " ${CURRENT_MOUNTS[@]} " =~ " ${OLD_UNIT} " ]]; then
        echo "Removing old mount unit: $OLD_UNIT"
        sudo systemctl stop "$OLD_UNIT"
        sudo systemctl disable "$OLD_UNIT"
        sudo rm -f "$SYSTEMD_DIR/$OLD_UNIT"
    fi
done

# Save the current list of mounts to the .last file for the next run
printf "%s\n" "${CURRENT_MOUNTS[@]}" | sudo tee "$LAST_FILE" > /dev/null

# Reload systemd again after cleanup
sudo systemctl daemon-reload
