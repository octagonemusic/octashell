#!/bin/bash

# Define the standard XDG paths
TARGET_DIR="$HOME/.cache/quickshell"
TARGET_FILE="$TARGET_DIR/emojis.json"
TMP_FILE="$TARGET_DIR/emojis_tmp.json"
URL="https://raw.githubusercontent.com/muan/emojilib/main/dist/emoji-en-US.json"

# Create cache directory if it doesn't exist
mkdir -p "$TARGET_DIR"

# Set up base curl arguments
CURL_CMD="curl -sL -f -R --connect-timeout 3 --max-time 15"

echo "Checking for emoji database updates..."

if [ -f "$TARGET_FILE" ]; then
    # Download to a temporary file to prevent QML from reading a half-written file
    $CURL_CMD -z "$TARGET_FILE" -o "$TMP_FILE" "$URL"
    EXIT_CODE=$?

    # If successful AND the temporary file is larger than 0 bytes
    if [ $EXIT_CODE -eq 0 ] && [ -s "$TMP_FILE" ]; then
        mv "$TMP_FILE" "$TARGET_FILE"
        echo "Emojis successfully updated to the latest version!"
    else
        rm -f "$TMP_FILE"
        echo "Emojis are up to date or network is offline. Using local cache."
    fi
else
    # First time download
    $CURL_CMD -o "$TMP_FILE" "$URL"
    if [ $? -eq 0 ] && [ -s "$TMP_FILE" ]; then
        mv "$TMP_FILE" "$TARGET_FILE"
        echo "Done! Database downloaded to $TARGET_FILE."
    else
        rm -f "$TMP_FILE"
        echo "Error: Download failed and no local cache exists."
    fi
fi
