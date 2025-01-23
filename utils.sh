#!/usr/bin/env bash

# DESC: Shared environment initialisation if not already set
# ARGS: None
# OUTS: $CUSTOM_INIT_CONFIG: The path to the custom init configuration file
#       $ACTION_RUNNER_DOWNLOAD_URL: The URL to download the GitHub Actions
#       Runner
#       $REQUIREMENTS_FILE: The path to the requirements file
function shared_init() {
    # shellcheck disable=SC2154
    readonly CUSTOM_INIT_CONFIG=${CUSTOM_INIT_CONFIG:-"$script_dir/sys-init.sh"}

    readonly ACTIONS_RUNNER_DOWNLOAD_URL=${ACTIONS_RUNNER_DOWNLOAD_URL:-$(curl \
        -s https://api.github.com/repos/actions/runner/releases |
        jq -r \
            '.[0].assets[] | select(.name | contains("actions-runner-linux-x64")) | .browser_download_url' |
        head -n 1)}

    # ----[ CAN CHANGE ] ------------------------------------------------- #

    readonly REQUIREMENTS_FILE="$script_dir/requirements.txt"

    # ----[ DO NOT CHANGE ]----------------------------------------------- #

    export CUSTOM_INIT_CONFIG ACTIONS_RUNNER_DOWNLOAD_URL REQUIREMENTS_FILE
}

# DESC: Display the art for the script
# ARGS: None
# OUTS: None
function display_banner() {
    cat <<EOF
${fg_cyan-}
    ██████╗ ███████╗██████╗ ██╗      ██████╗ ██╗   ██╗
    ██╔══██╗██╔════╝██╔══██╗██║     ██╔═══██╗╚██╗ ██╔╝
    ██║  ██║█████╗  ██████╔╝██║     ██║   ██║ ╚████╔╝ 
    ██║  ██║██╔══╝  ██╔═══╝ ██║     ██║   ██║  ╚██╔╝  
    ██████╔╝███████╗██║     ███████╗╚██████╔╝   ██║   
    ╚═════╝ ╚══════╝╚═╝     ╚══════╝ ╚═════╝    ╚═╝   ${fg_yellow-}
    ▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃${fg_cyan-}

    GitHub Actions Runner & Environment Setup Script
           Author: Saulo José de Lucas Silva
                License: MIT (c) 2025

EOF
}

# DESC: Handler for unexpected errors
# ARGS: $1 (optional): Exit code (defaults to 1)
# OUTS: None
function script_trap_err() {
    local exit_code=1

    # Disable the error trap handler to prevent potential recursion
    trap - ERR

    # Consider any further errors non-fatal to ensure we run to completion
    set +o errexit
    set +o pipefail

    # Validate any provided exit code
    if [[ ${1-} =~ ^[0-9]+$ ]]; then
        exit_code="$1"
    fi

    # Output debug data if in Cron mode
    if [[ -n ${cron-} ]]; then
        # Restore original file output descriptors
        if [[ -n ${script_output-} ]]; then
            exec 1>&3 2>&4
        fi

        local path params
        # shellcheck disable=SC2154
        path=$(realpath "$script_path")
        # shellcheck disable=SC2154
        params="$script_params"

        # Print basic debugging information
        # shellcheck disable=SC2154
        printf '%b\n' "$ta_none"
        printf '***** Abnormal termination of script *****\n'
        printf 'Script Path:            %s\n' "$path"
        printf 'Script Parameters:      %s\n' "$params"
        printf 'Script Exit Code:       %s\n' "$exit_code"

        # Print the script log if we have it. It's possible we may not if we
        # failed before we even called cron_init(). This can happen if bad
        # parameters were passed to the script so we bailed out very early.
        if [[ -n ${script_output-} ]]; then
            # shellcheck disable=SC2312
            printf 'Script Output:\n\n%s' "$(cat "$script_output")"
        else
            printf 'Script Output:          None (failed before log init)\n'
        fi
    fi

    # Exit with failure status
    exit "$exit_code"
}

# DESC: Handler for exiting the script
# ARGS: None
# OUTS: None
function script_trap_exit() {
    # shellcheck disable=SC2154
    cd "$orig_cwd"

    # Remove Cron mode script log
    if [[ -n ${cron-} && -f ${script_output-} ]]; then
        rm "$script_output"
    fi

    # Remove script execution lock
    if [[ -d ${script_lock-} ]]; then
        rmdir "$script_lock"
    fi

    # Restore terminal colours
    printf '%b' "$ta_none"
}

# DESC: Exit script with the given message
# ARGS: $1 (required): Message to print on exit
#       $2 (optional): Exit code (defaults to 0)
# OUTS: None
# NOTE: The convention used in this script for exit codes is:
#       0: Normal exit
#       1: Abnormal exit due to external error
#       2: Abnormal exit due to script error
function script_exit() {
    if [[ $# -eq 1 ]]; then
        printf '%s\n' "$1"
        exit 0
    fi

    if [[ ${2-} =~ ^[0-9]+$ ]]; then
        printf '%b\n' "$1"
        # If we've been provided a non-zero exit code run the error trap
        if [[ $2 -ne 0 ]]; then
            script_trap_err "$2"
        else
            exit 0
        fi
    fi

    script_exit 'Missing required argument to script_exit()!' 2
}

# DESC: Initialise colour variables
# ARGS: None
# OUTS: Read-only variables with ANSI control codes
# NOTE: If --no-colour was set the variables will be empty. The output of the
#       $ta_none variable after each tput is redundant during normal execution,
#       but ensures the terminal output isn't mangled when running with xtrace.
# shellcheck disable=SC2034,SC2155
function colour_init() {
    if [[ -z ${no_colour-} ]]; then
        # Text attributes
        readonly ta_bold="$(tput bold 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly ta_uscore="$(tput smul 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly ta_blink="$(tput blink 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly ta_reverse="$(tput rev 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly ta_conceal="$(tput invis 2>/dev/null || true)"
        printf '%b' "$ta_none"

        # Foreground codes
        readonly fg_black="$(tput setaf 0 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_blue="$(tput setaf 4 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_cyan="$(tput setaf 6 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_green="$(tput setaf 2 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_magenta="$(tput setaf 5 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_red="$(tput setaf 1 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_white="$(tput setaf 7 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_yellow="$(tput setaf 3 2>/dev/null || true)"
        printf '%b' "$ta_none"

        # Background codes
        readonly bg_black="$(tput setab 0 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_blue="$(tput setab 4 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_cyan="$(tput setab 6 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_green="$(tput setab 2 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_magenta="$(tput setab 5 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_red="$(tput setab 1 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_white="$(tput setab 7 2>/dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_yellow="$(tput setab 3 2>/dev/null || true)"
        printf '%b' "$ta_none"
    else
        # Text attributes
        readonly ta_bold=''
        readonly ta_uscore=''
        readonly ta_blink=''
        readonly ta_reverse=''
        readonly ta_conceal=''

        # Foreground codes
        readonly fg_black=''
        readonly fg_blue=''
        readonly fg_cyan=''
        readonly fg_green=''
        readonly fg_magenta=''
        readonly fg_red=''
        readonly fg_white=''
        readonly fg_yellow=''

        # Background codes
        readonly bg_black=''
        readonly bg_blue=''
        readonly bg_cyan=''
        readonly bg_green=''
        readonly bg_magenta=''
        readonly bg_red=''
        readonly bg_white=''
        readonly bg_yellow=''
    fi
}

# DESC: Initialise Cron mode
# ARGS: None
# OUTS: $script_output: Path to the file stdout & stderr was redirected to
function cron_init() {
    if [[ -n ${cron-} ]]; then
        # Redirect all output to a temporary file
        # shellcheck disable=SC2154
        script_output="$(mktemp --tmpdir "$script_name".XXXXX)"
        readonly script_output
        exec 3>&1 4>&2 1>"$script_output" 2>&1
    fi
}

# DESC: Acquire script lock
# ARGS: $1 (optional): Scope of script execution lock (system or user)
# OUTS: $script_lock: Path to the directory indicating we have the script lock
# NOTE: This lock implementation is extremely simple but should be reliable
#       across all platforms. It does *not* support locking a script with
#       symlinks or multiple hardlinks as there's no portable way of doing so.
#       If the lock was acquired it's automatically released on script exit.
function lock_init() {
    local lock_dir
    if [[ $1 = 'system' ]]; then
        lock_dir="/tmp/$script_name.lock"
    elif [[ $1 = 'user' ]]; then
        lock_dir="/tmp/$script_name.$UID.lock"
    else
        script_exit 'Missing or invalid argument to lock_init()!' 2
    fi

    if mkdir "$lock_dir" 2>/dev/null; then
        readonly script_lock="$lock_dir"
        verbose_print "Acquired script lock: $script_lock"
    else
        script_exit "Unable to acquire script lock: $lock_dir" 1
    fi
}

# DESC: Pretty print the provided string
# ARGS: $1 (required): Message to print (defaults to a green foreground)
#       $2 (optional): Colour to print the message with. This can be an ANSI
#                      escape code or one of the prepopulated colour variables.
#       $3 (optional): Set to any value to not append a new line to the message
# OUTS: None
function pretty_print() {
    if [[ $# -lt 1 ]]; then
        script_exit 'Missing required argument to pretty_print()!' 2
    fi

    if [[ -z ${no_colour-} ]]; then
        if [[ -n ${2-} ]]; then
            printf '%b' "$2"
        else
            printf '%b' "$fg_green"
        fi
    fi

    # Print message & reset text attributes
    if [[ -n ${3-} ]]; then
        printf '%s%b' "$1" "$ta_none"
    else
        printf '%s%b\n' "$1" "$ta_none"
    fi
}

# DESC: Only pretty_print() the provided string if verbose mode is enabled
# ARGS: $@ (required): Passed through to pretty_print() function
# OUTS: None
function verbose_print() {
    if [[ -n ${verbose-} ]]; then
        pretty_print "$@"
    fi
}

# DESC: Combines two path variables and removes any duplicates
# ARGS: $1 (required): Path(s) to join with the second argument
#       $2 (optional): Path(s) to join with the first argument
# OUTS: $build_path: The constructed path
# NOTE: Heavily inspired by: https://unix.stackexchange.com/a/40973
function build_path() {
    if [[ $# -lt 1 ]]; then
        script_exit 'Missing required argument to build_path()!' 2
    fi

    local new_path path_entry temp_path

    temp_path="$1:"
    if [[ -n ${2-} ]]; then
        temp_path="$temp_path$2:"
    fi

    new_path=
    while [[ -n $temp_path ]]; do
        path_entry="${temp_path%%:*}"
        case "$new_path:" in
        *:"$path_entry":*) ;;
        *)
            new_path="$new_path:$path_entry"
            ;;
        esac
        temp_path="${temp_path#*:}"
    done

    # shellcheck disable=SC2034
    build_path="${new_path#:}"
}

# DESC: Check a binary exists in the search path
# ARGS: $1 (required): Name of the binary to test for existence
#       $2 (optional): Set to any value to treat failure as a fatal error
# OUTS: None
function check_binary() {
    if [[ $# -lt 1 ]]; then
        script_exit 'Missing required argument to check_binary()!' 2
    fi

    if ! command -v "$1" >/dev/null 2>&1; then
        if [[ -n ${2-} ]]; then
            script_exit "Missing dependency: Couldn't locate $1." 1
        else
            verbose_print "Missing dependency: $1" "${fg_red-}"
            return 1
        fi
    fi

    verbose_print "Found dependency: $1"
    return 0
}

# DESC: Validate we have superuser access as root (via sudo if requested)
# ARGS: $1 (optional): Set to any value to not attempt root access via sudo
# OUTS: None
function check_superuser() {
    local superuser
    if [[ $EUID -eq 0 ]]; then
        superuser=true
    elif [[ -z ${1-} ]]; then
        # shellcheck disable=SC2310
        if check_binary sudo; then
            verbose_print 'Sudo: Updating cached credentials ...'
            if ! sudo -v; then
                verbose_print "Sudo: Couldn't acquire credentials ... \
                    ${fg_red-}"
            else
                local test_euid
                test_euid="$(sudo -H -- "$BASH" -c 'printf "%s" "$EUID"')"
                if [[ $test_euid -eq 0 ]]; then
                    superuser=true
                fi
            fi
        fi
    fi

    if [[ -z ${superuser-} ]]; then
        verbose_print 'Unable to acquire superuser credentials.' "${fg_red-}"
        return 1
    fi

    verbose_print 'Successfully acquired superuser credentials.'
    return 0
}

# DESC: Run the requested command as root (via sudo if requested)
# ARGS: $1 (optional): Set to zero to not attempt execution via sudo
#       $@ (required): Passed through for execution as root user
# OUTS: None
function run_as_root() {
    if [[ $# -eq 0 ]]; then
        script_exit 'Missing required argument to run_as_root()!' 2
    fi

    if [[ ${1-} =~ ^0$ ]]; then
        local skip_sudo=true
        shift
    fi

    if [[ $EUID -eq 0 ]]; then
        "$@"
    elif [[ -z ${skip_sudo-} ]]; then
        sudo -H -- "$@"
    else
        script_exit "Unable to run requested command as root: $*" 1
    fi
}

# DESC: Usage help
# ARGS: None
# OUTS: None
function script_usage() {
    cat <<EOF
Usage:
     -h|--help                  Displays this help
     -v|--verbose               Displays verbose output
    -nc|--no-colour             Disables colour output
EOF
}

# DESC: Parameter parser
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: Variables indicating command-line parameters and options
function parse_params() {
    local param
    while [[ $# -gt 0 ]]; do
        param="$1"
        shift
        case $param in
        -h | --help)
            script_usage
            exit 0
            ;;
        -v | --verbose)
            verbose=true
            ;;
        -nc | --no-colour)
            no_colour=true
            ;;
            # -cr | --cron)
            #     cron=true
            #     ;;
        "")
            continue
            ;;
        *)
            script_exit "Invalid parameter was provided: $param" 1
            ;;
        esac
    done
}

# DESC: Check if systemd is the init system
# ARGS: None
# OUTS: Boolean value indicating if systemd is the init system
# NOTE: This script only works on Linux, if the user is found using
# MacOS it should be exited with an error.
function check_systemd() {
    if [[ $(uname) != 'Linux' ]]; then
        script_exit 'This script only works on Linux.' 1
    fi

    systemd_folder="$([ -d /run/systemd/system ] && echo true || echo false)"
    systemd_bin=$(command -v systemctl && true)

    systemd="$([ "$systemd_bin" != "" ] && [ "$systemd_folder" = true ] &&
        echo 'true' || echo 'false')"

    echo "$systemd"
}

# DESC: Configure custom init system
# ARGS: $1 (required): The init configuration file
# OUTS: service_folder: The path to the services folder
# 		  init_name: Init name for selecting the service type
# 		  enable_cmd: The command to enable the service
# 		  start_cmd: The command to start the service
# 		  			  (defaults to "service @ start")
# 		  stop_cmd: The command to stop the service
# 		  			  (defaults to "service @ stop")
# 		  reload_cmd: The command to reload the daemons
# 		  		  			  (defaults to "service @ reload")
# NOTE: This function is only used when the user is not using systemd.
# 		  The config should have:
# 		  	1. (required) The path to the services folder
# 		  	2. (required) Init name for selecting the service type
# 		  	3. (optional) The command to start the service
# 		  	4. (optional) The command to stop the service
# 		  	5. (optional) The command to reload the daemons
function config_custom_init() {
    if [[ $# -lt 1 ]]; then
        script_exit 'Missing required argument to configure_init()!' 2
    fi

    # shellcheck source=/dev/null
    source "$1"

    if [[ -z ${services_folder-} || -z ${init_name-} ]]; then
        script_exit 'The configuration file is missing required parameters.' 2
    fi

    # Default values
    export services_folder=${services_folder}
    export init_name=${init_name}
    export enable_cmd=${enable_cmd:-"service @ enable"}
    export disable_cmd=${disable_cmd:-"service @ disable"}
    export start_cmd=${start_cmd:-"service @ start"}
    export stop_cmd=${stop_cmd:-"service @ stop"}
    export reload_cmd=${reload_cmd:-"service reload"}
}

# DESC: Configure the systemd init system
# ARGS: None
# OUTS: services_folder: The path to the services folder
# 		  init_name: Init name for selecting the service type
# 		  start_cmd: The command to start the service
# 		  stop_cmd: The command to stop the service
# 		  reload_cmd: The command to reload the daemons
function config_systemd() {
    export services_folder="/etc/systemd/system"
    export init_name="systemd"
    export enable_cmd="systemctl enable @"
    export disable_cmd="systemctl disable @"
    export start_cmd="systemctl start @"
    export stop_cmd="systemctl stop @"
    export reload_cmd="systemctl daemon-reload"
}

# DESC: Get system distro name
# ARGS: None
# OUTS: distro_name: The name of the distro
function get_distro() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        distro_name=$NAME
    elif [[ -f /etc/lsb-release ]]; then
        # shellcheck disable=SC1091
        source /etc/lsb-release
        distro_name=$DISTRIB_ID
    else
        distro_name=$(uname -s)
    fi

    export distro_name
}

# DESC: Get the package manager for the current distribution.
# ARGS: None
# OUTS: The package manager name (stdout)
function get_package_manager() {
    if command -v apt-get &>/dev/null; then
        echo "apt-get"
    elif command -v yum &>/dev/null; then
        echo "yum"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v zypper &>/dev/null; then
        echo "zypper"
    elif command -v pacman &>/dev/null; then
        echo "pacman"
    elif command -v apk &>/dev/null; then
        echo "apk"
    elif command -v emerge &>/dev/null; then
        echo "emerge"
    elif command -v pkg &>/dev/null; then
        echo "pkg"
    elif command -v slackpkg &>/dev/null; then
        echo "slackpkg"
    elif command -v swupd &>/dev/null; then
        echo "swupd"
    elif command -v xbps-install &>/dev/null; then
        echo "xbps-install"
    else
        script_exit \
            'Unable to determine the package manager for this system.' 1
    fi

    return 0
}

# DESC: Install a package using the system's package manager.
# ARGS: $1 (required): The name of the package to install.
# OUTS: None
function install_package() {
    if [[ $# -lt 1 ]]; then
        script_exit 'Missing required argument to install_package()!' 2
    fi

    local package_line package_name bin_name
    package_line="$1"

    # package_name:bin_name (optional)
    if [[ $package_line == *":"* ]]; then
        package_name="${package_line%%:*}"
        bin_name="${package_line#*:}"
    else
        package_name="$package_line"
        bin_name="$package_line"
    fi

    if command -v "$bin_name" &>/dev/null; then
        verbose_print "Package already installed: $1"
        return 0
    fi

    check_internet_connection
    local package_manager
    package_manager=$(get_package_manager)

    echo "${fg_cyan}Installing package: $package_name${ta_none}"

    case "$package_manager" in
    apt-get) run_as_root apt-get install -y "$package_name" >/dev/null ;;
    yum) run_as_root yum install -y "$package_name" >/dev/null ;;
    dnf) run_as_root dnf install -y "$package_name" >/dev/null ;;
    zypper) run_as_root zypper install -y "$package_name" >/dev/null ;;
    pacman) run_as_root pacman -S --noconfirm "$package_name" >/dev/null ;;
    apk) run_as_root apk add "$package_name" >/dev/null ;;
    emerge) run_as_root emerge "$package_name" >/dev/null ;;
    pkg) run_as_root pkg install -y "$package_name" >/dev/null ;;
    slackpkg) run_as_root slackpkg install "$package_name" >/dev/null ;;
    swupd) run_as_root swupd bundle-add "$package_name" >/dev/null ;;
    xbps-install) run_as_root xbps-install -y "$package_name" >/dev/null ;;
    *)
        script_exit "Unknown package manager: $package_manager" 1
        ;;
    esac

    # Reload the shell to ensure the new binary is in the PATH
    hash -r

    if check_binary "$bin_name" true; then
        script_exit \
            "Error installing package: $package_name. Try install manually." 1
    fi

    return 0
}

# DESC: Ping a remote server to check for an active Internet connection
# ARGS: $1 (required): The IP address or domain name to ping
# OUTS: Boolean value indicating if the system reached the remote server
function ping_server() {
    if [[ $# -lt 1 ]]; then
        script_exit 'Missing required argument to ping_server()!' 2
    fi

    if ping -q -c 1 -W 1 "$1" &>/dev/null; then
        echo "true"
    else
        echo "false"
    fi
}

# DESC: Check Internet connection
# ARGS: None
# OUTS: None
function check_internet_connection() {
    google_dns=$(ping_server '8.8.8.8')
    cloudflare_dns=$(ping_server '1.1.1.1')
    if [[ $google_dns == "true" || $cloudflare_dns == "true" ]]; then
        echo "true"
    else
        script_exit 'No Internet connection available.' 1
    fi
}

# DESC: Get the repo owner
# ARGS: None
# OUTS: The repo owner (stdout)
function get_repo_owner() {
    if command -v gh &>/dev/null; then
        gh repo view --json owner --jq '.owner.login'
    else
        script_exit 'GitHub CLI (gh) is required to get the repo owner.' 1
    fi
}

# DESC: Get the repo name
# ARGS: None
# OUTS: The repo name (stdout)
function get_repo_name() {
    if command -v gh &>/dev/null; then
        gh repo view --json name --jq '.name'
    else
        script_exit 'GitHub CLI (gh) is required to get the repo name.' 1
    fi
}

# DESC: Get the repo username/reponame with gh-cli
# ARGS: None
# OUTS: The repo username/reponame (stdout)
function get_repo() {
    if command -v gh &>/dev/null; then
        echo "$(get_repo_owner)/$(get_repo_name)"
    else
        script_exit 'GitHub CLI (gh) is required to get the repo name.' 1
    fi
}

# DESC: Multiple choice prompt with arrow keys and color highlights
# ARGS: $1 (required): The prompt message
#       $2 (required): The options to choose from (comma-separated)
# OUTS: The selected option (stdout)
function multiple_choice() {
    if [[ $# -lt 2 ]]; then
        script_exit 'Missing required arguments to multiple_choice()!' 2
    fi

    local prompt="$1"
    local options_string="$2"
    local options
    IFS=',' read -ra options <<<"$options_string"

    # Construct input for fzf
    local formatted_options
    formatted_options=$(printf "%s\n" "${options[@]}")

    # Display fzf for selection
    local selected_option
    selected_option=$(echo "$formatted_options" | fzf --prompt="$prompt > " --height=10 --border --ansi)

    # If no selection is made, return an error
    if [[ -z $selected_option ]]; then
        script_exit 'No option selected.' 1
    fi

    echo "$selected_option"
}

# DESC: Get the firewall common binary
# ARGS: None
# OUTS: The firewall binary (stdout)
# NOTE: If more than one firewall is available, the routine will ask the user
#       to choose one.
function get_firewall_binary() {
    local firewall_bin
    if command -v iptables &>/dev/null; then
        firewall_bin=("iptables")
    elif command -v nft &>/dev/null; then
        firewall_bin=(firewall_bin "nft")
    elif command -v firewalld &>/dev/null; then
        firewall_bin=(firewall_bin "firewalld")
    elif command -v ufw &>/dev/null; then
        firewall_bin=(firewall_bin "ufw")
    else
        script_exit 'No firewall binary found.' 1
    fi

    if [[ ${#firewall_bin[@]} -gt 1 ]]; then
        local firewall_bin
        firewall_bin=$(multiple_choice "Select a firewall" "$(
            IFS=,
            echo "${firewall_bin[*]}"
        )")
    fi

    echo "$firewall_bin"
}

# DESC: Read the firewall rules from a file
# ARGS: $1 (required): The file with the firewall rules
# OUTS: $receive_ports: The ports to receive
#       $send_ports: The ports to send
# NOTE: To set up OPEN SEND and OPEN RECEIVE rules, the user must have the
#      necessary permissions and declare the ports in the ports.txt file.
#      The ports.txt file should have the following format:
#      RECEIVE 80,443,8080,8081
#      SEND 80,443,8080,8081
function read_firewall_rules() {
    if [[ $# -lt 1 ]]; then
        script_exit 'Missing required argument to read_firewall_rules()!' 2
    fi

    local rules_file
    rules_file="$1"

    if [[ ! -f "$rules_file" ]]; then
        script_exit "File not found: $rules_file" 1
    fi

    local -a receive_ports_array=()
    local -a send_ports_array=()

    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*$ ]] && continue

        if [[ $line =~ ^RECEIVE ]]; then
            IFS=',' read -ra ports <<<"${line#RECEIVE}"
            receive_ports_array+=("${ports[@]}")
        elif [[ $line =~ ^SEND ]]; then
            IFS=',' read -ra ports <<<"${line#SEND}"
            send_ports_array+=("${ports[@]}")
        elif [[ $line =~ ^# ]]; then
            continue
        else
            script_exit "Invalid port rule: $line" 1
        fi
    done <"$rules_file"

    receive_ports=("${receive_ports_array[@]}")
    send_ports=("${send_ports_array[@]}")
}

# DESC: Set rules on the selected firewall
# ARGS: $1 (required): The firewall binary
# OUTS: None
function setup_firewall_rules() {
    if [[ $# -lt 1 ]]; then
        script_exit 'Missing required argument to set_up_firewall_rules()!' 2
    fi

    local firewall_bin
    firewall_bin="$1"

    echo "${fg_yellow}Setting up firewall rules in $firewall_bin...${ta_none}"

    read_firewall_rules "$script_dir/ports.txt"

    join_by() {
        local IFS="$1"
        shift
        echo "$*"
    }

    local receive_ports_csv send_ports_csv
    receive_ports_csv=$(join_by ',' "${receive_ports[@]}")
    send_ports_csv=$(join_by ',' "${send_ports[@]}")

    # RECEIVE PORTS FIRST
    echo "Setting up receive ports: ${receive_ports[*]}"
    case "$firewall_bin" in
    iptables)
        echo "iptables -A INPUT -p tcp -m multiport --dports \
            $receive_ports_csv -j ACCEPT"
        run_as_root iptables -A INPUT -p tcp -m multiport --dports \
            "$receive_ports_csv" -j ACCEPT
        ;;
    nft)
        echo "nft add rule inet filter input tcp dport { $receive_ports_csv } accept"
        run_as_root nft add rule inet filter input tcp dport \
            "{ $receive_ports_csv }" accept
        ;;
    firewalld)
        for port in "${receive_ports[@]}"; do
            echo "firewall-cmd --zone=public --add-port=\"$port/tcp\" \
--permanent"
            run_as_root firewall-cmd --zone=public --add-port="$port/tcp" \
                --permanent
        done
        ;;
    ufw)
        for port in "${receive_ports[@]}"; do
            echo "ufw allow \"$port/tcp\""
            run_as_root ufw allow "$port/tcp"
        done
        ;;
    *)
        script_exit "${fg_red}Unsupported firewall binary: $firewall_bin" 1
        ;;
    esac

    # SEND PORTS SECOND
    echo "Setting up send ports: ${send_ports[*]}"
    case "$firewall_bin" in
    iptables)
        echo "iptables -A OUTPUT -p tcp -m multiport --dports \
            $send_ports_csv -j ACCEPT"
        run_as_root iptables -A OUTPUT -p tcp -m multiport --dports \
            "$send_ports_csv" -j ACCEPT
        ;;
    nft)
        echo "nft add rule inet filter output tcp dport { $send_ports_csv } accept"
        run_as_root nft add rule inet filter output tcp dport \
            "{ $send_ports_csv }" accept
        ;;
    firewalld)
        for port in "${send_ports[@]}"; do
            echo "firewall-cmd --zone=public --add-port=\"$port/tcp\" \
--permanent"
            run_as_root firewall-cmd --zone=public --add-port="$port/tcp" \
                --permanent
        done
        ;;
    ufw)
        for port in "${send_ports[@]}"; do
            echo "ufw allow out \"$port/tcp\""
            run_as_root ufw allow out "$port/tcp"
        done
        ;;
    *)
        script_exit "${fg_red}Unsupported firewall binary: $firewall_bin" 1
        ;;
    esac

    # Reload firewalld if used
    if [[ "$firewall_bin" == "firewalld" ]]; then
        run_as_root firewall-cmd --reload
    fi
}

# DESC: Debug all functions by capturing and printing their outputs
# ARGS: None
# OUTS: Prints debugging information for functions
# NOTE: This will only be sourced if DEBUG is set to true.
if [[ $DEBUG =~ ^(yes|true)$ ]]; then
    echo "Debugging functions enabled."
    function debug_all_functions() {
        output="$(read_firewall_rules "$script_dir/ports.txt")"
        echo "====[ FIREWALL PORTS ]========================="
        echo "Receive Ports: ${receive_ports[*]}"
        echo "Send Ports: ${send_ports[*]}"
        echo "OUTPUT: $output [[END]]"
        echo "==============================================="

        output="$(get_firewall_binary)"
        echo "====[ FIREWALL BINARY ]========================"
        echo "Firewall Binary: $output"
        echo "==============================================="

        output="$(get_repo)"
        echo "====[ REPO ]==================================="
        echo "Repo: $output"
        echo "==============================================="

        # output="$(get_repo_name)"
        # echo "====[ REPO NAME ]=============================="
        # echo "Repo Name: $output"
        # echo "==============================================="

        # output="$(get_repo_owner)"
        # echo "====[ REPO OWNER ]============================="
        # echo "Repo Owner: $output"
        # echo "==============================================="

        output="$(get_distro)"
        echo "====[ DISTRO ]================================="
        echo "Distro: $output"
        echo "==============================================="

        output="$(get_package_manager)"
        echo "====[ PACKAGE MANAGER ]========================"
        echo "Package Manager: $output"
        echo "==============================================="

        output="$(check_systemd)"
        echo "====[ SYSTEMD ]================================"
        echo "Systemd: $output"
        echo "==============================================="

        output="$(check_binary "ls")"
        echo "====[ CHECK BINARY ]==========================="
        echo "Check Binary: $output"
        echo "==============================================="

        output="$(build_path "/usr/bin" "/usr/local/bin")"
        echo "====[ BUILD PATH ]============================="
        echo "Build Path: $output"
        echo "==============================================="

        output="$(parse_params "-v")"
        echo "====[ PARSE PARAMS ]==========================="
        echo "Parse Params: $output"
        echo "==============================================="

        output="$(pretty_print "Hello, World!")"
        echo "====[ PRETTY PRINT ]==========================="
        echo "Pretty Print: $output"
        echo "==============================================="

        output="$(verbose_print "Hello, World!")"
        echo "====[ VERBOSE PRINT ]=========================="
        echo "Verbose Print: $output"
        echo "==============================================="
    }
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
#
