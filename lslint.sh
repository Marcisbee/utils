#!/bin/bash

# Usage: ./lslint.sh
#
# Before running this script, please create a .lslint configuration file in your project root directory.
# This file should contain valid file patterns you want to lint. For example:
#
# /package.json
# /node_modules/**/*
#
# Example syntax matches:
# /file.ts                  => /file.ts
# /test/*                   => /test/file.ts, /test/any.css
# /test/**/*                => /test/file.ts, /test/a/b/c/any.css
# /test/**/file.ts          => /test/file.ts, /test/a/file.ts, /test/a/b/c/file.ts
# /test/**/*.ts             => /test/file.ts, /test/a/any.ts, /test/a/b/c/any.ts
# /test/start/**/end/*.ts   => /test/start/end/file.ts, /test/start/a/end/any.ts, /test/start/a/b/c/end/any.ts
# /test/**/<kebabcase>.ts   => /test/paper-bag.ts, /test/a/paper-bag.ts, /test/a/b/c/paper-bag.ts
# /test/<kebabcase>**/<kebabcase>.ts   => /test/paper-bag.ts, /test/component-setup/paper-bag.ts, /test/component-setup/b/component-files/paper-bag.ts
# /test/<:[A-Z]+>**/mod.<:ts|tsx|css>   => /test/any.ts, /test/component-setup/file.tsx, /test/component-setup/b/component-files/paper-bag.css

file_count=0
error_count=0

# Function to escape regex characters outside brackets
escape_regex_outside_brackets() {
  local input="$1"
  local result=""
  local in_brackets=false

  # Loop through each character in the input string
  for ((i=0; i<${#input}; i++)); do
    char="${input:$i:1}"

    # If encountering an opening bracket, mark as inside brackets and append to result
    if [[ "$char" == "<" ]]; then
      in_brackets=true
      result+="$char"
    # If encountering a closing bracket, mark as outside brackets and append to result
    elif [[ "$char" == ">" ]]; then
      in_brackets=false
      result+="$char"
    # If not inside brackets, escape certain regex characters
    elif [[ "$in_brackets" == false ]]; then
      case "$char" in
        "." | "$" | "[" | "]" | "^" | "?" | "+" | "*" | "{" | "}" | "|") result+="\\";;
      esac
      result+="$char"
    else
      result+="$char"
    fi
  done

  echo "$result"
}

# Function to parse .lslint rules into usable regex patterns
parse_lslint_rules() {
  local rule
  # Read each line from the .lslint file
  while IFS= read -r rule; do
    if [[ $rule == /* ]]; then
      # Escape regex characters outside brackets
      rule=$(escape_regex_outside_brackets "$rule")

      # Determine the type of rule (file, directory, or all directories)
      if [[ $rule == *"/\*\*/\*" ]]; then
        rule_type="all"
        rule="${rule%/*/*}/.*"
      elif [[ $rule == *"/\*" ]]; then
        rule_type="directory"
        rule="${rule%/*}[^\/]+$"
      else
        rule_type="file"
      fi

      # Replace ** with regex pattern to match zero, one, or multiple directories
      rule=${rule//\/\*\*\//"(/[^/]+)*/"}

      # Handle <...> pattern in the rule
      while [[ $rule == *\<*\>* ]]; do
        pattern="${rule#*<}"
        pattern="${pattern%%>*}"
        regex="$pattern"

        # Map placeholders to specific regex patterns
        if [[ $pattern == "kebabcase" ]]; then
          regex="[a-z0-9\-]+"
        elif [[ $pattern == "snakecase" ]]; then
          regex="[a-z0-9_]+"
        elif [[ $pattern == "pascalcase" ]]; then
          regex="[A-Z][a-zA-Z0-9]+"
        elif [[ $pattern == "lowercase" ]]; then
          regex="[a-z0-9]+"
        elif [[ $pattern == "uppercase" ]]; then
          regex="[A-Z0-9]+"
        elif [[ $pattern == "pointcase" ]]; then
          regex="[a-z0-9\.]+"
        fi

        # Handle regex <:[regex]>
        if [[ $regex =~ ^: ]]; then
          regex="${regex//:/}"
        fi

        # Replace <...> with the corresponding regex pattern in the rule
        if [[ $rule == *"<$pattern>\*\*"* ]]; then
          slash="/"
          rule=${rule//"<$pattern>\*\*$slash"/"($regex(/[^/]*)*)"}
          rule=${rule//"<$pattern>\*\*"/"($regex(/[^/]*)*)"}
        else
          rule=${rule//"<$pattern>"/"($regex)"}
        fi
      done

      rule="^${rule}\$"

      # Append the cleaned and processed rule to LSLINT_RULES array
      LSLINT_RULES+=("${rule}")
    fi
  done < .lslint

  # Print how many rules were loaded from .lslint file
  echo -e "\033[0;34mLoaded ${#LSLINT_RULES[@]} rules from .lslint file.\033[0m"
}

# Function to check file paths against defined rules
check_file_paths() {
  local ignore_regex=""
  # Build a regex pattern from all defined rules
  for path in "${LSLINT_RULES[@]}"; do
    if [[ -n $ignore_regex ]]; then
      ignore_regex+="|"
    fi
    ignore_regex+="$path"
  done

  local file_paths=""

  # If .gitignore exists, use it to filter files
  if [ -e ".gitignore" ]; then
    echo -e "\033[33mFound .gitignore, will use it to ignore files\033[0m\n"
    local file_paths=$(git ls-files --cached --others --exclude-standard | sed 's|^|/|')
  else
    # Otherwise, find all files in the directory
    local file_paths=$(find . -type f | sed 's|^./|/|')
  fi

  # Count total number of files checked
  file_count=($(echo -n "$file_paths" | wc -l))

  # Filter out paths that match the ignore rules
  local file_paths_invalid="$(echo "$file_paths" | grep -Ev "($ignore_regex)")"
  error_count=($(echo -n "$file_paths_invalid" | wc -l))

  # Print invalid paths in red
  echo "$file_paths_invalid" | while read -r path; do
    if [[ -n "$path" ]]; then
      echo -e "\033[31minvalid\033[0m \033[4;30m${path#\/}\033[0m"
    fi
  done
}

# Main function to execute the script
main() {
# Initialize rule list with .lslint file path
  LSLINT_RULES=("^/\.lslint\$")

  # Read and parse .lslint if it exists
  if [[ -f .lslint ]]; then
    parse_lslint_rules
  else
    echo "No .lslint file found. Exiting."
    exit 1
  fi

  check_file_paths

  # Print the total number of files checked
  echo -e "\n\033[0;34mChecked ${file_count} files.\033[0m"

  # If any errors are found, print the count in red and exit with error status
  if [[ $error_count -ne 0 ]]; then
    echo -e "\033[31mFound ${error_count} errors.\033[0m"
    exit 1
  fi

  # Print success message if no errors are found
  echo -e "\033[0;32mFound no errors.\033[0m"
}

# Run the main function to execute the script
main
