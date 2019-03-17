#!/usr/bin/env bash
#
########################################
#  
#  SYPCTL Environment Script
#
########################################

# source platform/$(uname -s)/env.sh
curl -sS http://gitlab.ibi.ren/syp-apps/sypctl/raw/dev-0.0.1/platform/$(uname -s)/env.sh | bash