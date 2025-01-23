#!/usr/bin/env bash

# THIS SCRIPT IS INTENDED TO BE SOURCED, DO NOT EXECUTE IT DIRECTLY

# DESC: Parse the service file for environment variables in $VAR or ${VAR}
# ARGS: $1 - The service file
# OUTS: None
function parse_service_file() {
    local file_path="$1"

    if [[ ! -f "$file_path" ]]; then
        # shellcheck disable=SC2154
        echo "${fg_yellow}File not found: $file_path"
        return 1
    fi

    local file_dir temp_file
    file_dir=$(dirname "$file_path")
    temp_file="${file_dir}/.temp_$(basename "$file_path")"

    envsubst <"$file_path" >"$temp_file"
}

# DESC: Enable a single service
# ARGS: $1 - The service name
# OUTS: None
function enable_service() {
    if [[ -z "$1" ]]; then
        echo "Service name not provided."
        return 1
    fi
    local service_name
    service_name="$1"

    if [[ -z "$enable_cmd" ]]; then
        echo "Enable command not set."
        return 1
    fi

    # GLOB: s/@/$service_name/ in $enable_cmd
    # shellcheck disable=SC2154
    eval run_as_root "${enable_cmd/@/$service_name}"
}

# DESC: Start a single service
# ARGS: $1 - The service name
# OUTS: None
function start_service() {
    if [[ -z "$1" ]]; then
        echo "Service name not provided."
        return 1
    fi
    local service_name
    service_name="$1"

    if [[ -z "$start_cmd" ]]; then
        echo "Start command not set."
        return 1
    fi

    # GLOB: s/@/$service_name/ in $start_cmd
    # shellcheck disable=SC2154
    eval run_as_root "${start_cmd/@/$service_name}"
}

# DESC: Reload the init daemons
# ARGS: None
# OUTS: None
function reload_daemons() {
    if [[ -z "$reload_cmd" ]]; then
        echo "Reload command not set."
        return 1
    fi

    # shellcheck disable=SC2154
    eval run_as_root "$reload_cmd"
}

# DESC: Install a single service
# ARGS: $1 - The service path
# OUTS: None
function install_service() {
    local service_name service_path service_dir
    service_path="$1"
    service_dir=$(dirname "$service_path")
    service_name=$(basename "$service_path")

    if [[ ! -f "$service_path" ]]; then
        echo "Service does not exist: ${service_path}"
        return 1
    fi
    echo "Installing service: ${service_name}"

    parse_service_file "$service_path"

    local temp_service="${service_dir}/.temp_${service_name}"
    # shellcheck disable=SC2154
    local dest_service="${services_folder}/${service_name}"

    run_as_root cp "$temp_service" "$dest_service"

    if [[ ! -f "$dest_service" ]]; then
        # shellcheck disable=SC2154
        script_exit "${fg_red}Failed to copy service: ${service_path}" 1
    fi

    reload_daemons
    enable_service "$service_name"
    start_service "$service_name"
}

# DESC: Find on dispatch rule in the workflow file
# ARGS: $1 - The workflow file
# OUTS: Boolean if the rule is found (STDOUT)
function find_on_dispatch_rule() {
    local workflow_file="$1"
    if [[ ! -f "$workflow_file" ]]; then
        echo "Workflow file not found: $workflow_file"
        return 1
    fi

    if ! grep -qE '^on:' "$workflow_file" ||
        ! grep -qE 'workflow_dispatch:' "$workflow_file"; then
        echo "false"
    else
        echo "true"
    fi
}

# DESC: Check if diff is as expected
# ARGS: $1 - The workflow file
#       $2 - The temporary file
# OUTS: Boolean if the diff is as the user expects (STDOUT)
function check_diff() {
    local workflow_file="$1"

    if [[ ! -f "$workflow_file" ]]; then
        echo "Workflow file not found: $workflow_file"
        return 1
    fi

    diff=$(diff -u "$workflow_file" "$2")

    if [[ -n "$diff" ]]; then
        echo "false"
    else
        # Ask the user if the diff is as expected
        echo "Is the diff as expected?"
        echo "$diff"
        read -rp "Continue? [y/N]: " continue_diff
        if [[ "$continue_diff" =~ ^[Yy][Ee][Ss]$ ]]; then
            echo "true"
        else
            echo "false"
        fi
    fi
}

# DESC: Add on:workflow_dispatch rule to the workflow file
# ARGS: $1 - The workflow file
# OUTS: None
function add_on_dispatch_rule() {
    local workflow_file="$1"
    if [[ ! -f "$workflow_file" ]]; then
        echo "Workflow file not found: $workflow_file"
        return 1
    fi

    awk '
    BEGIN { on_found = 0 }
    /^on:/ {
        on_found = 1
        print $0
        print "  workflow_dispatch:" # Add workflow_dispatch under on:
        next
    }
    END {
        if (!on_found) {
        print "on:"
        print "  workflow_dispatch:" # Add the whole on: block if missing
        }
    }
    { print $0 }
    ' "$workflow_file" >"$workflow_file.tmp"


    rule_exists=$(find_on_dispatch_rule "$workflow_file.tmp")

    if [[ "$rule_exists" != "false" ]]; then
        echo "${fg_red}Failed to add on:workflow_dispatch rule to the workflow"
        # shellcheck disable=SC2154
        echo "file: $workflow_file${ta_none}"
        return 1
    fi

    user_confirmed=$(check_diff "$workflow_file" "$workflow_file.tmp")
    if [[ "$user_confirmed" != "true" ]]; then
        echo "${fg_red}User did not confirm the diff.${ta_none}"
        return 1
    else
        mv "$workflow_file.tmp" "$workflow_file"
    fi
}

# DESC: Commit and PR create the workflow_dispatch
# ARGS: $1 - The workflow file
# OUTS: None
function commit_and_pr_workflow_dispatch() {
    local workflow_file="$1"
    if [[ ! -f "$workflow_file" ]]; then
        echo "Workflow file not found: $workflow_file"
        return 1
    fi

    add_on_dispatch_rule "$workflow_file"

    git add "$workflow_file"
    git commit -m "feat: Add on:workflow_dispatch rule"
    git branch feat/add-on-workflow_dispatch-rule
    git checkout feat/add-on-workflow_dispatch-rule
    git push origin feat/add-on-workflow_dispatch-rule

    # Create PR
    gh pr create --title "feat: Add on:workflow_dispatch rule" \
    --body "Add on:workflow_dispatch rule to the workflow file: $workflow_file"
}

# DESC: Dispatch actions on reboot
# ARGS: None
# OUTS: None
function install_actions_dispatch_on_reboot() {
    DOCKER_ACTION_FILE=".github/workflows/docker-image.yml"
    # shellcheck disable=SC2154
    project_dir=$(realpath "$script_dir/..")

    if [[ ! -d "$project_dir/.github" ]]; then
        echo "No .github folder found."
        return 1
    fi

    if [[ ! -f "$project_dir/$DOCKER_ACTION_FILE" ]]; then
        echo "No actions file found: $DOCKER_ACTION_FILE"
        return 1
    fi
    
    # Find on dispatch rule in the workflow file
    rule_exists=$(find_on_dispatch_rule "$project_dir/$DOCKER_ACTION_FILE")
    if [[ "$rule_exists" == "false" ]]; then
        # shellcheck disable=SC2154
        echo "${fg_yellow}No on:workflow_dispatch rule found in the workflow\
file.${ta_none}"
        read -rp "Do you want to add it? [y/N]: " add_rule
        if [[ "$add_rule" =~ ^[Yy][Ee][Ss]$ ]]; then
            echo "Adding on:workflow_dispatch rule to the workflow file."
            commit_and_pr_workflow_dispatch "$project_dir/$DOCKER_ACTION_FILE"
        else
            echo "${fg_yellow}Skipping the on:workflow_dispatch rule."
            # shellcheck disable=SC2154
            echo "${ta_none}${bg_blue}You can add it manually to the workflow"
            echo "file: $DOCKER_ACTION_FILE"
            echo "on: workflow_dispatch:${ta_none}"
        fi

    fi

    # ----[ GH DISPATCHED ]---------------------------------------------- #
    payload="

# CUSTSOM #
old_pwd=\"\$(pwd)\"
if [[ -d ${project_dir} ]]; then
        cd \"${project_dir}\" &&
        git pull
        gh workflow run \"${}\" &
        cd \"\$old_pwd\"
fi
# CUSTSOM #"

    # shellcheck disable=SC2154
    actions_run_file="$script_dir/../actions-runner/run.sh"

    # Create temp file to annex the payload

    temp_file="${actions_run_file}.tmp"
    cp "$actions_run_file" "$temp_file"
    # ----[ PAYLOAD ]---------------------------------------------------- #

    if [[ ! -f "$temp_file" ]]; then
        echo "Failed to create temp file: $temp_file"
        return 1
    fi

    # Annex the payload after the first line

    sed -i "1 a $payload" "$temp_file"
    bash -n "$temp_file" || return 1

    mv "$temp_file" "$actions_run_file"

    # Check if the payload was annexed
    sed -n '/# CUSTSOM #/p' "$actions_run_file" || return 1

    # ----[ INSTALLED ]-------------------------------------------------- #
    echo "Actions dispatch on reboot installed."
}

# DESC: Get the to install services
# ARGS: None
# OUTS: None
function get_services() {
    declare -A services_map=()

    # shellcheck disable=SC2154
    for file in "$script_dir/services/$init_name"/*/*.{service,timer}; do
        [[ -e "$file" ]] || continue # Skip if no matching files
        service_name=$(basename "$file")
        services_map["$service_name"]="$file"
    done

    if [[ ${#services_map[@]} -eq 0 ]]; then
        echo "No services to install."
        return 1
    fi

    for service_name in "${!services_map[@]}"; do
        install_service "${services_map[$service_name]}"
    done
    return 0
}

# DESC: Systemd services installer
# ARGS: None
# OUTS: None
function install() {
    # Check if the services folder exists
    if [[ ! -d "$services_folder" ]]; then
        # shellcheck disable=SC2154
        script_exit "${fg_red}Services folder does not exist: \
            $services_folder" 1
    fi

    get_services
    install_actions_dispatch_on_reboot
    # ----[ INSTALLED ]-------------------------------------------------- #
}

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
#
