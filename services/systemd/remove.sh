#!/usr/bin/env bash

# THIS SCRIPT SHOULD REMOVE ALL SERVICES INSTALLED BY THE INSTALL.SH SCRIPT
# AND AS SUCH IT IS NOT TO BE SOURCED. ONLY THE USER SHOULD RUN IT.
# =========================================================================== #
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
	echo "This script is not to be sourced. Please run it directly."
	return 1
fi
# =========================================================================== #

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
	script_dir="$(dirname "$script_path")"
	script_name="$(basename "$script_path")"
	readonly script_dir script_name

	# Important to always set as we use it in the exit handler
	# shellcheck disable=SC2155
	readonly ta_none="$(tput sgr0 2>/dev/null || true)"

	if [[ -f "$script_dir/../.env" ]]; then
		# shellcheck source=.env
		source "$script_dir/../.env"
	fi
}

# DESC: Remove a single service
# ARGS: $1 - The service path
# OUTS: None
function remove_service() {
	local service_name service_path
	service_name=$(basename "$1")
	service_path="$1"

	if [[ ! -f "$service_path" ]]; then
		echo "Service does not exist: ${service_path}"
		return 1
	fi
	echo "Removing service: ${service_name}"

	# shellcheck disable=SC2154
	run_as_root rm -f "${services_folder}/${service_name}"

	if [[ -f "${services_folder}/${service_name}" ]]; then
		# shellcheck disable=SC2154
		script_exit "${fg_red}Failed to remove service: ${service_path}" 1
	fi
}

# DESC: Stop a single service
# ARGS: $1 - The service name
# OUTS: None
function stop_service() {
	if [[ -z "$1" ]]; then
		echo "Service name not provided."
		return 1
	fi
	local service_name
	service_name=$1

	if [[ -z "$stop_cmd" ]]; then
		echo "Stop command not set."
		return 1
	fi

	# GLOB: s/@/$service_name/ in $stop_cmd
	# shellcheck disable=SC2154
	run_as_root eval "${stop_cmd/@/$service_name}"
}

# DESC: Disable a single service
# ARGS: $1 - The service name
# OUTS: None
function disable_service() {
	if [[ -z "$1" ]]; then
		echo "Service name not provided."
		return 1
	fi
	local service_name
	service_name=$1

	if [[ -z "$disable_cmd" ]]; then
		echo "Disable command not set."
		return 1
	fi

	# GLOB: s/@/$service_name/ in $disable_cmd
	# shellcheck disable=SC2154
	run_as_root eval "${disable_cmd/@/$service_name}"
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
	run_as_root eval "$reload_cmd"
}

# DESC: Remove function called by the main script
# ARGS: None
# OUTS: None
function remove_services() {
	local services_files timers_files services
	services_files=("$script_dir/services/$init_name"/*.service)
	timers_files=("$script_dir/services/$init_name"/*.timer)
	services=("${services_files[@]}" "${timers_files[@]}")

	for service in "${services[@]}"; do
		service_name=$(basename "$service")
		stop_service "$service_name"
		disable_service "$service_name"
		remove_service "$service"
	done

	reload_daemons

	# ----[ SERVICES REMOVED ]-------------------------------------------- #
	echo "${fg_green}Services removed.${ta_none}"
}

# DESC: Preinitializes the script environment
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: None
function script_init() {
	# shellcheck source=utils.sh
	source "$(dirname "$script_dir")/../utils.sh"

	trap script_trap_err ERR
	trap script_trap_exit EXIT

	# Enable xtrace if the DEBUG environment variable is set
	if [[ ${DEBUG-} =~ ^1|yes|true$ ]]; then
		set -o xtrace # Trace the execution of the script (debug)
	fi

	colour_init
	shared_init

	check_superuser "" ||
		script_exit 'User does not have superuser privileges.' 1

	lock_init system

	SYSTEMD=$(check_systemd "")

	if [[ -z ${SYSTEMD} ]]; then
		echo "SystemD is not available. 
	    Checking alternative config in ${CUSTOM_INIT_CONFIG}"

		config_custom_init "$CUSTOM_INIT_CONFIG"
	else
		echo "SystemD is available."
		config_systemd
	fi

	# ----[ INITIALIZED ]------------------------------------------------ #
}

# =========================================================================== #

# DESC: Main script function
# ARGS: None
# OUTS: None
function main() {
	env_init """$@"
	script_init
	read -rp "${fg_red}${ta_bold}Are you SURE you want to remove the services?\
[y/N] ====> ${ta_none}" response

	if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		remove_services
	else
		echo "Services not removed."
	fi
}

# Invoke main with args if not sourced
# Approach via: https://stackoverflow.com/a/28776166/8787985
if ! (return 0 2>/dev/null); then
	main """$@"
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
#
