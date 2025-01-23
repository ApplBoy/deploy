#!/usr/bin/env bash

# LICENSE MIT
# Copyright (c) 2025
# Saulo José de Lucas Silva <saulojosesilva030@gmail.com>

# This script will deploy the server application in GitHub actions-runner,
# and configure the environment and services for stable operation.

# Only enable these shell behaviours if we're not being sourced
# Approach via: https://stackoverflow.com/a/28776166/8787985
if ! (return 0 2>/dev/null); then
    # A better class of script...
    set -o errexit  # Exit on most errors (see the manual)
    set -o nounset  # Disallow expansion of unset variables
    set -o pipefail # Use last non-zero exit code in a pipeline
fi

# Enable errtrace or the error trap handler will not work as expected
set -o errtrace # Ensure the error trap handler is inherited

# DESC: Generic environment initialisation
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: $orig_cwd: The current working directory when the script was run
#       $script_path: The full path to the script
#       $script_dir: The directory path of the script
#       $script_name: The file name of the script
#       $script_params: The original parameters provided to the script
#       $ta_none: The ANSI control code to reset all text attributes
#       $... ENVIROMENT VARS AT .env
# NOTE: $script_path only contains the path that was used to call the script
#       and will not resolve any symlinks which may be present in the path.
#       You can use a tool like realpath to obtain the "true" path. The same
#       caveat applies to both the $script_dir and $script_name variables.
# shellcheck disable=SC2034
function env_init() {
    # Useful variables
    readonly orig_cwd="$PWD"
    readonly script_params="$*"
    readonly script_path="${BASH_SOURCE[0]}"
    local script_rel_dir dir name
    script_rel_dir="$(dirname "$script_path")"
    dir="$(realpath "$script_rel_dir")"
    name="$(basename "$script_path")"
    readonly script_dir="$dir"
    readonly script_name="$name"

    # Important to always set as we use it in the exit handler
    # shellcheck disable=SC2155
    readonly ta_none="$(tput sgr0 2>/dev/null || true)"

    if [[ -f "$script_dir/.env" ]]; then
        # shellcheck source=.env
        source "$script_dir/.env"
    fi

}

# DESC: Preinitializes the script environment
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: None
function script_init() {
    # 0 - PREPARE THE SCRIPT
    # 0.1 - Load the shellscript dependencies
    source "$script_dir/utils.sh"

    trap script_trap_err ERR
    trap script_trap_exit EXIT

    # Enable xtrace if the DEBUG environment variable is set
    if [[ ${DEBUG-} =~ ^1|yes|true$ ]]; then
        set -o xtrace # Trace the execution of the script (debug)
    fi

    parse_params """$@"
    cron_init
    colour_init
    shared_init

    lock_init system
    display_banner

    # ----[ SOURCED ]---------------------------------------------------- #
    echo "${fg_green}Environment successfully initialized.${ta_none}"

    # 1 - PREPARE THE SCRIPT ENVIRONMENT
    # We will start by checking the environment for the necessary tools and
    # dependencies to run the script.

    # 1.1 - Check if the script is running as root
    check_superuser "" ||
        script_exit 'User does not have superuser privileges.' 1

    # 0.2 - Check if the script is running in a SystemD environment
    systemd=$(check_systemd "")

    if [[ $systemd == "false" ]]; then
        echo "${fg_yellow}SystemD is not available. 
Checking alternative config in ${CUSTOM_INIT_CONFIG}${ta_none}"

        # config_custom_init "$CUSTOM_INIT_CONFIG"
    else
        echo "${fg_green}SystemD is available.${ta_none}"
        config_systemd
    fi

    # 0.3 - Install the necessary packages
    while read -r package; do
        install_package "$package"
    done <"$REQUIREMENTS_FILE"

    # ----[ INITIALIZED ]------------------------------------------------ #
    echo "${fg_green}Script environment successfully initialized.${ta_none}"
}

# DESC: Setup the GitHub Actions runner
# ARGS: None
# OUTS: None
function setup_github_actions_runner() {
    mkdir -p "../actions-runner"
    cd "../actions-runner" || script_exit \
        "Failed to change directory to ../actions-runner" 1

    curl -o actions-runner-linux-x64.tar.gz -L "$ACTIONS_RUNNER_DOWNLOAD_URL"
    tar xzf ./actions-runner-linux-x64.tar.gz
    # ----[ INSTALLED ]-------------------------------------------------- #

    token=$(
        read -r -p "${ta_bold}Enter the GitHub Actions runner token \
====> ${ta_none}"
    )

    ./config.sh --url "https://github.com/$(get_repo)" --token "$token"
    # ----[ CONFIGURED ]------------------------------------------------- #
    echo "${fg_green}GitHub Actions runner configured successfully.${ta_none}"
}

# DESC: Setup the services
# ARGS: None
# OUTS: None
function setup_services() {
    to_install="$script_dir/services/$init_name"
    install_script="$to_install/install.sh"

    if [[ -f "$install_script" ]]; then
        # shellcheck source=services/systemd/install.sh
        source "$install_script"
        install
    else
        script_exit "${fg_red}No install script found in $to_install \
        ${ta_none}" 1
    fi

    # ----[ INSTALLED ]-------------------------------------------------- #
    echo "${fg_green}Services installed successfully.${ta_none}"
}

# DESC: Setup the database
# ARGS: None
# OUTS: None
# NOTE: This is just a placeholder function
function setup_database() {

    # ----[ INSTALLED ]-------------------------------------------------- #
    # echo "${fg_green}Database installed successfully.${ta_none}"
    echo "${fg_yellow}Database setup skipped.${ta_none}"
}

# DESC: Setup the Nginx
# ARGS: None
# OUTS: None
# NOTE: This is just a placeholder function
function setup_nginx() {

    # ----[ INSTALLED ]-------------------------------------------------- #
    # echo "${fg_green}Nginx installed successfully.${ta_none}"
    echo "${fg_yellow}Nginx setup skipped.${ta_none}"
}

# DESC: Setup the firewall
# ARGS: None
# OUTS: None
# NOTE: It won't setup the firewall if is AWS, GCP or Azure, and if setted in
# the environment variable FIREWALL_SETUP=false or if the user
function setup_firewall() {
    if [[ "${FIREWALL_SETUP:-}" == "false" ]]; then
        echo "Firewall setup is disabled."
        return 0
    fi

    if [[ -n "${AWS_REGION:-}" || -n "${GCP_REGION:-}" || -n "${AZURE_REGION:-}" ]]; then
        echo "Firewall setup is disabled in cloud environments."
        return 0
    fi

    if [[ "${FIREWALL_SETUP:-}" == "true" ]]; then
        echo "Setting up the firewall."
    else
        read -r -p "${ta_bold}Do you want to setup the firewall? [y/N] \
====> ${ta_none}" response
        if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            echo "Firewall setup skipped."
            return 0
        fi
    fi

    # ----[ PERMISSION GRANTED ]----------------------------------------- #

    local bin

    bin=$(get_firewall_binary)
    if [[ -z "$bin" ]]; then
        script_exit "${fg_red}Firewall binary not found.${ta_none}" 1
    fi

    setup_firewall_rules "$bin"

    # ----[ INSTALLED ]-------------------------------------------------- #
    echo "${fg_green}Firewall installed successfully.${ta_none}"
}

# DESC: Main control flow
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: None
function main() {
    env_init """$@"
    script_init """$@"
    setup_github_actions_runner
    setup_services
    setup_database
    setup_nginx
    setup_firewall
    script_exit 'Script completed successfully.' 0
}

# Invoke main with args if not sourced
# Approach via: https://stackoverflow.com/a/28776166/8787985
if ! (return 0 2>/dev/null); then
    main """$@"
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
#
