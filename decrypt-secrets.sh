#!/usr/bin/env bash

# DESC: Decrypt secrets
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: $decrypted_files: Array of encrypted files
function encrypt_secrets() {
  # ALL ENCRYPTED SECRETS FILES ENDS WITH .secrets.env.encrypted
  local encrypted_files=()
  local secrets_files=()

  mapfile -t encrypted_files < <(find . -type f -name "*.secrets.env.encrypted")
  local password
  # If no $ENCRYPTION_PASSWORD is set, prompt for password
  if [[ -z "$ENCRYPTION_PASSWORD" ]]; then
    read -r -s -p "Enter password for encryption: ====> " password
  else
    echo "Using the provided encryption password."
    password="$ENCRYPTION_PASSWORD"
  fi

  # Check if any encrypted files were found
  if [[ ${#encrypted_files[@]} -eq 0 ]]; then
    echo "No encrypted files found."
    return 0
  fi

  # Loop through each encrypted file, and decrypt it
  for encrypted_file in "${encrypted_files[@]}"; do
    # Check if the file exists
    if [[ ! -f "$encrypted_file" ]]; then
      echo "File $encrypted_file does not exist."
      continue
    fi

    # Decrypt the encrypted file
    local secrets_file="${encrypted_file%.secrets.env.encrypted}.secrets.env"
    echo "$password" | gpg --decrypt --batch --yes --passphrase-fd 0 \
        --output "$secrets_file" "$encrypted_file"


    # Check if the decryption was successful
    if [[ $? -eq 0 ]]; then
      secrets_files+=("$secrets_file")
      echo "Decrypted $encrypted_file to $secrets_file"
      # Optionally, remove the original encrypted file
      if [[ "${KEEP_ORIGINAL_ENC:-false}" != "true" ]]; then
        rm -f "$encrypted_file"
      fi
    else
      echo "Failed to decrypt $encrypted_file"
    fi
  done
}

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
#
