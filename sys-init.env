#!/usr/bin/env bash

# THIS IS NOT A SCRIPT TO BE RUNNED, IT IS A SNIPPET TO BE USED IN OTHER
# SCRIPTS AS SOURCE
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script is not to be runned, it is a snippet to be used as" \
        " source for your custom init config."
    exit 1
fi

# =========================================================================== #
#
# DECLARE THE INIT CONFIG HERE:
#
# services_folder - The folder where the services are located
#
# export services_folder="/etc/init.d/"
#
#
# init_name - The name of the init service, used to separate services in
# ./services/
#
# export init_name="openrc"
#
#
# enable_cmd - The command to enable the service (@ to be replaced by the
# service name)
#
# export enable_cmd="rc-update add @ default"
#
# disable_cmd - The command to disable the service (@ to be replaced by the
# service name)
#
# export disable_cmd="rc-update del @ default"
#
#
# start_cmd - The command to start the service (@ to be replaced by the service
# name)
#
# export start_cmd="rc-service @ start"
#
#
# stop_cmd - The command to stop the service (@ to be replaced by the service
# name)
#
# export stop_cmd="rc-service @ stop"
#
#
# reload_cmd - The command to reload the init daemons (if available)
#
# export reload_cmd="echo 'OpenRC does not need to reload daemons'"
#
# =========================================================================== #
#
# MAKE SURE THE SERVICES FOLDER EXISTS AND IS LIKE THIS:
#
# services
# └── systemd
#     ├── actions-runner
#     │   └── actions-runner.service
#     ├── install.sh
#     └── remove.sh
#
# YOU CAN COPY THE INSTALL.SH AND REMOVE.SH SCRIPTS TO THE SERVICES FOLDER
# BUT IF NEEDED YOU CAN ALSO EDIT/CREATE A NEW SCRIPT TO INSTALL/REMOVE
# SERVICES
#
# =========================================================================== #
#
# THE REMOVE.SH SCRIPT SHOULD REMOVE ALL SERVICES INSTALLED BY THE INSTALL.SH
# SCRIPT AND AS SUCH IT IS NOT TO BE SOURCED. ONLY THE USER SHOULD RUN IT.

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
#
