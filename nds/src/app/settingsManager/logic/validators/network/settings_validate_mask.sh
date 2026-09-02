#!/usr/bin/env bash
# ==================================================================================================
# NDS - Validators: netmask / CIDR
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-07-06
# ==================================================================================================

validate_mask() {
    local mask="$1"
    if [[ "$mask" =~ ^[0-9]+$ ]]; then
        [[ "$mask" -ge 1 && "$mask" -le 32 ]] && return 0
        return 1
    fi
    local IFS=. val=0 octet
    local -a octets
    read -r -a octets <<< "$mask"
    (( ${#octets[@]} == 4 )) || return 1
    for octet in "${octets[@]}"; do
        [[ $octet =~ ^[0-9]+$ ]] || return 1
        (( octet >= 0 && octet <= 255 )) || return 1
        (( val = (val << 8) | octet ))
    done
    (( val != 0 && val != 0xFFFFFFFF )) || return 1
    (( (val | (val - 1)) == 0xFFFFFFFF )) || return 1
    return 0
}

validate_mask_cidr_to_netmask() {
    local cidr="$1" octets=() i bits_in_octet octet_value bit
    for ((i=0; i<4; i++)); do
        if (( cidr >= 8 )); then bits_in_octet=8
        elif (( cidr > 0 )); then bits_in_octet=$cidr
        else bits_in_octet=0; fi
        octet_value=0
        for ((bit=0; bit<bits_in_octet; bit++)); do
            (( octet_value += 1 << (7 - bit) ))
        done
        octets+=("$octet_value")
        (( cidr -= 8 ))
        (( cidr < 0 )) && cidr=0
    done
    echo "${octets[0]}.${octets[1]}.${octets[2]}.${octets[3]}"
}

validate_mask_to_prefix() {
    local mask="$1" val=0 octet count=0
    if [[ "$mask" =~ ^[0-9]+$ ]]; then
        echo "$mask"
        return 0
    fi
    local IFS=.
    local -a octets
    read -r -a octets <<< "$mask"
    for octet in "${octets[@]}"; do
        (( val = (val << 8) | octet ))
    done
    while (( val )); do
        (( count += val & 1 ))
        (( val >>= 1 ))
    done
    echo "$count"
}
