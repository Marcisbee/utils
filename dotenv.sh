#!/bin/bash

# dotenv.sh
# Usage: ./dotenv.sh [env_file] -- <command_to_run>

# Default to .env if no env_file is provided
if [ "$1" == "--" ]; then
  ENV_FILE=".env"
else
  ENV_FILE=$1
  shift
fi

# Ensure '--' separates the command
if [ "$1" != "--" ]; then
  echo "Usage: $0 [env_file] -- <command_to_run>"
  exit 1
fi

# Shift to move past the '--'
shift

# Check if the environment file exists
if [ ! -f "$ENV_FILE" ]; then
  echo "Error: Environment file '$ENV_FILE' not found!"
  exit 1
fi

# Read .env file and build the environment variables string
ENV_VARS=""
while IFS='=' read -r key value; do
  # Skip comments and empty lines
  if [[ "$key" =~ ^#.*$ ]] || [[ -z "$key" ]]; then
    continue
  fi

  # Trim whitespace from key and value
  key=$(echo "$key" | tr -d '[:space:]')
  value=$(echo "$value" | tr -d '[:space:]')

  # Remove surrounding quotes if present
  if [[ "$value" =~ ^\".*\"$ ]] || [[ "$value" =~ ^\'.*\'$ ]]; then
    value="${value:1:${#value}-2}"
  fi

  # Escape double quotes in the value
  value=${value//\"/\\\"}

  # Append to the environment variables string
  ENV_VARS+="$key=\"$value\" "
done < "$ENV_FILE"

# Execute the command with the environment variables prepended
eval "$ENV_VARS""$@"
