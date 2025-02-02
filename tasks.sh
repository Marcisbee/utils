#!/bin/bash

# Usage: ./tasks.sh <task_name|task_group>
#
# Instructions:
# 1. Ensure that a 'task.sh' file is present in your project's root directory.
# 2. The 'task.sh' file should define bash functions prefixed with `task_`, such as the following example:
#
# ```
# #!/usr/bin/env bash
#
# task_dev() {
#     start_task build
#     start_task db+server
# }
#
# task_server() {
#   echo "Start server process"
# }
#
# task_db() {
#   echo "Start db process"
# }
#
# task_build() {
#   echo "This is build"
# }
# ```
#
# Command Line Interface (CLI):
# Usage: ./tasks.sh <task_name|task_group>
#
# Examples:
# - `./tasks.sh build` executes the function `task_build`.
# - `./tasks.sh build+lint` initiates both `task_build` and `task_lint` to run concurrently in parallel.
#
# Functionality Overview:
# The `start_task <task_name|task_group>` function is responsible for executing one or more tasks. When combined task names (e.g., `build+lint`) are provided, each specified task runs concurrently; otherwise, they run sequentially.

# Array to store the PIDs and PGIDs of running tasks
RUNNING_TASKS=()
RUNNING_GROUPS=()

# Function to start a task and capture its output
start_task() {
  local TASK_NAME=$1

  # Split combined task names by '+'
  IFS='+' read -r -a TASK_LIST <<< "$TASK_NAME"

  for SINGLE_TASK in "${TASK_LIST[@]}"; do
    # Check if the specified task exists and is executable
    if ! type -t "task_${SINGLE_TASK}" &>/dev/null || ! declare -f "task_${SINGLE_TASK}" &>/dev/null; then
      echo -e "\033[31m[ERROR] Task '${SINGLE_TASK}' does not exist or is not executable.\033[0m"
      continue  # Skip to the next task if this one doesn't exist
    fi

    # Start the task in a new process group and store its PID and PGID
    (
      local task_name="${SINGLE_TASK}"
      echo -e "\033[32m[INFO] Starting '${task_name}'.\033[0m"

      task_"${task_name}" "$@"
      TASK_STATUS=$?

      # Check if task status is not an error and display message accordingly
      if [ $TASK_STATUS -eq 0 ]; then
        echo -e "\033[32m[INFO] Done '${task_name}'.\033[0m"
      else
        echo -e "\033[31m[ERROR] Task '${task_name}' finished with an error status of ${TASK_STATUS}.\033[0m"
      fi
    ) &
    PID=$!
    PGID=$(ps -o pgid= -p "$PID" | tr -d ' ')

    # Add the current PID and PGID to the arrays of running tasks
    RUNNING_TASKS+=("$PID")
    RUNNING_GROUPS+=("$PGID")
  done

  # Wait for all running task PIDs
  wait "${RUNNING_TASKS[@]}"
}

# Function to list available tasks
list_tasks() {
  echo "Available tasks:"
  local TASKS=()
  for name in $(compgen -A function | grep '^task_'); do
    TASKS+=("- ${name#task_}")
  done
  printf "%s\n" "${TASKS[@]}"
}

# Function to perform cleanup
cleanup() {
  echo -e "\033[33m[INFO] Cleanup initiated.\033[0m"

  # Iterate over the array of running tasks and attempt to kill each one
  for pid in "${RUNNING_TASKS[@]}"; do
    kill -TERM "$pid" 2>/dev/null || true
  done

  for pgid in "${RUNNING_GROUPS[@]}"; do
    kill -TERM -$pgid 2>/dev/null || true
  done

  # Clear the array of running tasks
  RUNNING_TASKS=()
  RUNNING_GROUPS=()
  echo -e "\033[33m[INFO] Cleanup completed.\033[0m"
}

# Check if task.sh exists and is readable
if [ ! -r "task.sh" ]; then
  echo -e "\033[31m[ERROR] 'task.sh' file is missing or not readable.\033[0m"
  exit 1
fi

# Load the task functions from task.sh
source task.sh

# Check if a task name is provided as an argument
if [ $# -eq 0 ]; then
  # echo "Usage: $0 <task_name>"
  list_tasks
  exit 1
fi

# Set up the trap for cleanup
trap cleanup EXIT

TASK_NAMES=("$@")
for TASK_NAME in "${TASK_NAMES[@]}"; do
  start_task "$TASK_NAME"
done

# Wait for all tasks to finish and store their exit statuses
TASK_STATUSES=()
for pid in "${RUNNING_TASKS[@]}"; do
  wait "$pid"
  TASK_STATUSES+=($?)

  # Remove completed tasks from RUNNING_TASKS
  RUNNING_TASKS=("${RUNNING_TASKS[@]/$pid}")
done

# Print a message indicating that the script has stopped
if [[ ${TASK_STATUSES[*]} =~ [1-9] ]]; then
  echo -e "\033[31m[ERROR] One or more tasks failed.\033[0m"
else
  echo -e "\033[32m[INFO] All tasks have completed successfully.\033[0m"
fi

# Return the highest exit status from all tasks
exit ${TASK_STATUSES[*]}
