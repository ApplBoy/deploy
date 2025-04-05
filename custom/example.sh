#!/usr/bin/env bash
# MIT License (c) 2025 Saulo José

# This is an example of custom script, you can run anything you want here.
# It'll be automatically run in the end of the deployment.

# Then you can do anything you want here.
printf "The example custom script is running...\n"
printf "%s\n" "$(date -u +%Y-%m-%dT%H:%M:%S%Z)"

# Just don't forget to set the executable permission on this script:
# chmod +x example.sh
