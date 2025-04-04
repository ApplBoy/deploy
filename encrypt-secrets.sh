#!/usr/bin/env bash

# DESC: Encrypt secrets
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: $encrypted_files: Array of encrypted files
function encrypt_secrets() {
  # ALL SECRETS FILES ENDS WITH .secrets.env
  local secrets_files=()
  local encrypted_files=()

  mapfile -t secrets_files < <(find . -type f -name "*.secrets.env")
  local password
  # If no $ENCRYPTION_PASSWORD is set, prompt for password
  if [[ -z "$ENCRYPTION_PASSWORD" ]]; then
    read -r -s -p "Enter password for encryption: ====> " password
  else
    echo "Using the provided encryption password."
    password="$ENCRYPTION_PASSWORD"
  fi

  # Check if any secrets files were found
  if [[ ${#secrets_files[@]} -eq 0 ]]; then
    echo "No secrets files found."
    return 0
  fi

  # Loop through each secrets file, and encrypt it
  for secrets_file in "${secrets_files[@]}"; do
    # Check if the file exists
    if [[ ! -f "$secrets_file" ]]; then
      echo "File $secrets_file does not exist."
      continue
    fi

    # Encrypt the secrets file
    local encrypted_file="${secrets_file%.secrets.env}.encrypted"
    echo "$password" | gpg --symmetric --cipher-algo AES256 --batch --yes \
        --passphrase-fd 0 --output "$encrypted_file" "$secrets_file"

    # Check if the encryption was successful
    if [[ $? -eq 0 ]]; then
      encrypted_files+=("$encrypted_file")
      echo "Encrypted $secrets_file to $encrypted_file"
      # Optionally, remove the original secrets file
      if [[ "${KEEP_ORIGINAL:-false}" != "true" ]]; then
        rm -f "$secrets_file"
      fi
    else
      echo "Failed to encrypt $secrets_file"
    fi
  done
}

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
#
