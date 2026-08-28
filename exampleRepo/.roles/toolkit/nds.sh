#!/usr/bin/env bash
# NDS knobs for toolkit ops VMs — sourced by NDS_ACTION=toolkit before disk confirm.
nds_cfg_set ENCRYPTION "false"
nds_cfg_set DISK_STRATEGY "nds"
nds_cfg_set INSTALL_MODE "local"
