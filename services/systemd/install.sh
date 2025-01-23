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

    if [[ -z "$enable_service" ]]; then
        echo "Enable command not set."
        return 1
    fi

    # GLOB: s/@/$service_name/ in $enable_cmd
    # shellcheck disable=SC2154
    run_as_root "${enable_cmd/@/$service_name}"
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
    run_as_root "${start_cmd/@/$service_name}"
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
    run_as_root "$reload_cmd"
}

# DESC: Install a single service
# ARGS: $1 - The service path
# OUTS: None
function install_service() {
    local service_name service_path service_dir
    service_dir=$(dirname "$1")
    service_name=$(basename "$1")
    service_path="$1"

    if [[ ! -f "$service_path" ]]; then
        echo "Service does not exist: ${service_path}"
        return 1
    fi
    echo "Installing service: ${service_name}"

    parse_service_file "$service_path"

    # shellcheck disable=SC2154
    run_as_root cp "$service_dir/.temp_${service_name} \
        ${services_folder}/${service_name}"

    if [[ ! -f "${services_folder}/$(basename "$service_path")" ]]; then
        # shellcheck disable=SC2154
        script_exit "${fg_red}Failed to copy service: ${service_path}" 1
    fi

    reload_daemons
    enable_service "$service_name"
    start_service "$service_name"
}

# DESC: Get the to install services
# ARGS: None
# OUTS: None
function get_services() {
    # Get the services to install
    services_files=("$script_dir/services/$init_name"/*.service)
    timers_files=("$script_dir/services/$init_name"/*.timer)
    services=("${services_files[@]}" "${timers_files[@]}")

    if [[ ${#services[@]} -eq 0 ]]; then
        echo "No services to install."
        return 1
    fi

    for service in "${services[@]}"; do
        service_name=$(basename "$service")
        service_name="${service_name%.*}"
        install_service "$service_name"
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
    # ----[ INSTALLED ]-------------------------------------------------- #
}

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
#
