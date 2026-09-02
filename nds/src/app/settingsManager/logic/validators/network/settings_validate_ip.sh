#!/usr/bin/env bash
# ==================================================================================================
# NDS - Validators: IPv4
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-07-06
# ==================================================================================================

validate_ip() {
    local ip="$1"
    local IFS=.
    local -a octets
    read -r -a octets <<< "$ip"
    (( ${#octets[@]} == 4 )) || return 1
    local i octet
    for i in "${!octets[@]}"; do
        octet="${octets[i]}"
        [[ $octet =~ ^[0-9]+$ ]] || return 1
        [[ $octet == "0" || $octet != 0[0-9]* ]] || return 1
        (( octet >= 0 && octet <= 255 )) || return 1
        (( i == 0 )) && (( octet < 1 )) && return 1
        (( i == 3 )) && (( octet == 0 || octet == 255 )) && return 1
    done
    return 0
}

validate_ip_to_int() {
    local ip="$1" a b c d
    IFS='.' read -r a b c d <<< "$ip"
    echo "$((a * 256**3 + b * 256**2 + c * 256 + d))"
}

validate_ip_same_subnet() {
    local ip="$1" mask="$2" gateway="$3"
    local ip_int gateway_int mask_int ip_network gateway_network
    ip_int=$(validate_ip_to_int "$ip")
    gateway_int=$(validate_ip_to_int "$gateway")
    mask_int=$(validate_ip_to_int "$mask")
    ip_network=$((ip_int & mask_int))
    gateway_network=$((gateway_int & mask_int))
    [[ "$ip_network" -eq "$gateway_network" ]]
}
