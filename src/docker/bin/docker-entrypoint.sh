#!/bin/sh
#
# This script need to run as PID 1 allowing it to receive signals from docker
#
# Usage: add the following lines in Dockerfile
# ENTRYPOINT ["docker-entrypoint.sh"]
#


#
# Source common functions.
#
. docker-common.sh
. openldap-common.sh

#
# Phase (0)
#
# Make a RW copy of config and data directory if they are mounted RO.
# Also check and fix file attributes within these directories.
#
#
openldap_envs_from_args $@
openldap_copy_if_ro

#
# Phase (1)
#
# Try to create databases if they are missing.
#
openldap_create_db

#
# Phase (2)
#
# Start slapd or user provided command.
#
openldap_entrypoint_cmd
