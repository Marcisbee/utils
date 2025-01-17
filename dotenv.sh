#!/bin/bash

# Usage: ./dotenv [env_file] -- <command_to_run>

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
  # Skip lines that are comments or empty
  if [[ "$key" =~ ^#.*$ ]] || [[ -z "$key" ]]; then
    continue
  fi
  # Trim surrounding whitespace
  key=$(echo "$key" | xargs)
  value=$(echo "$value" | xargs)
  # Escape double quotes in value
  value=$(echo "$value" | sed 's/"/\\"/g')
  # Append to environment variables string
  ENV_VARS+="$key=\"$value\" "
done < "$ENV_FILE"

# Execute the command with the environment variables in a subshell
# Use "$@" to preserve all quotes and special characters in the original command
eval "$ENV_VARS" "$@"
