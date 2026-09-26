#!/usr/bin/env bash
# ==================================================================================================
# NDS - Schema group network
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_check_network() {
    local -n _nds_net_aa=$1
    local _nds_net_n=0
    [[ ${_nds_net_aa[NETWORK_METHOD]:-} == static ]] || return 0
    if [[ -z ${_nds_net_aa[NETWORK_IP]:-} || -z ${_nds_net_aa[NETWORK_GATEWAY]:-} ]]; then
        error "NETWORK_IP: static network needs IP and gateway"
        return 1
    fi
    if [[ ${_nds_net_aa[NETWORK_IP]} == "${_nds_net_aa[NETWORK_GATEWAY]}" ]]; then
        error "NETWORK_GATEWAY: gateway cannot be the same as the IP address"
        _nds_net_n=$((_nds_net_n + 1))
    fi
    if [[ -n ${_nds_net_aa[NETWORK_MASK]:-} ]]; then
        if ! _nds_type_ipSameSubnet "${_nds_net_aa[NETWORK_IP]}" "${_nds_net_aa[NETWORK_MASK]}" "${_nds_net_aa[NETWORK_GATEWAY]}"; then
            error "NETWORK_GATEWAY: gateway must be in the same subnet"
            _nds_net_n=$((_nds_net_n + 1))
        fi
    fi
    return "$_nds_net_n"
}

nds_schema_group network "Network" --check nds_check_network
nds_schema_field network NETWORK_HOSTNAME hostname --required --label 'Hostname'
nds_schema_field network NETWORK_METHOD choice --default dhcp \
    --choices 'dhcp|static' --labels 'dhcp=DHCP|static=Static IP' --label 'Network method'
nds_schema_field network NETWORK_DNS_PRIMARY ip --default '1.1.1.1' --label 'Primary DNS'
nds_schema_field network NETWORK_DNS_SECONDARY ip --default '1.0.0.1' --label 'Secondary DNS'
nds_schema_field network NETWORK_IP ip --required --when 'NETWORK_METHOD=static' --label 'IP address'
nds_schema_field network NETWORK_MASK mask --default '255.255.255.0' --when 'NETWORK_METHOD=static' \
    --label 'Network mask'
nds_schema_field network NETWORK_GATEWAY ip --required --when 'NETWORK_METHOD=static' --label 'Gateway'
