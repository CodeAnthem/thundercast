#!/usr/bin/env bash
# ==================================================================================================
# NDS - Recipe type checks
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# Description:   Per-type checks.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

# Returns: timezone|locale|keyboard|keyboard_variant
nds_country_defaults() {
    case "${1,,}" in
        us) printf '%s\n' "America/New_York|en_US.UTF-8|us|" ;;
        ca) printf '%s\n' "America/Toronto|en_CA.UTF-8|us|" ;;
        mx) printf '%s\n' "America/Mexico_City|es_MX.UTF-8|latam|" ;;
        de) printf '%s\n' "Europe/Berlin|de_DE.UTF-8|de|nodeadkeys" ;;
        fr) printf '%s\n' "Europe/Paris|fr_FR.UTF-8|fr|oss" ;;
        uk|gb) printf '%s\n' "Europe/London|en_GB.UTF-8|uk|" ;;
        es) printf '%s\n' "Europe/Madrid|es_ES.UTF-8|es|" ;;
        it) printf '%s\n' "Europe/Rome|it_IT.UTF-8|it|" ;;
        nl) printf '%s\n' "Europe/Amsterdam|nl_NL.UTF-8|us|intl" ;;
        be) printf '%s\n' "Europe/Brussels|fr_BE.UTF-8|be|" ;;
        ch) printf '%s\n' "Europe/Zurich|de_CH.UTF-8|ch|de_nodeadkeys" ;;
        at) printf '%s\n' "Europe/Vienna|de_AT.UTF-8|de|nodeadkeys" ;;
        pt) printf '%s\n' "Europe/Lisbon|pt_PT.UTF-8|pt|" ;;
        se) printf '%s\n' "Europe/Stockholm|sv_SE.UTF-8|se|" ;;
        no) printf '%s\n' "Europe/Oslo|nb_NO.UTF-8|no|" ;;
        dk) printf '%s\n' "Europe/Copenhagen|da_DK.UTF-8|dk|" ;;
        fi) printf '%s\n' "Europe/Helsinki|fi_FI.UTF-8|fi|" ;;
        pl) printf '%s\n' "Europe/Warsaw|pl_PL.UTF-8|pl|" ;;
        cz) printf '%s\n' "Europe/Prague|cs_CZ.UTF-8|cz|" ;;
        ru) printf '%s\n' "Europe/Moscow|ru_RU.UTF-8|ru|" ;;
        ua) printf '%s\n' "Europe/Kiev|uk_UA.UTF-8|ua|" ;;
        jp) printf '%s\n' "Asia/Tokyo|ja_JP.UTF-8|jp|" ;;
        cn) printf '%s\n' "Asia/Shanghai|zh_CN.UTF-8|us|" ;;
        kr) printf '%s\n' "Asia/Seoul|ko_KR.UTF-8|kr|" ;;
        in) printf '%s\n' "Asia/Kolkata|en_IN.UTF-8|us|" ;;
        sg) printf '%s\n' "Asia/Singapore|en_SG.UTF-8|us|" ;;
        au) printf '%s\n' "Australia/Sydney|en_AU.UTF-8|us|" ;;
        nz) printf '%s\n' "Pacific/Auckland|en_NZ.UTF-8|us|" ;;
        br) printf '%s\n' "America/Sao_Paulo|pt_BR.UTF-8|br|abnt2" ;;
        ar) printf '%s\n' "America/Argentina/Buenos_Aires|es_AR.UTF-8|latam|" ;;
        cl) printf '%s\n' "America/Santiago|es_CL.UTF-8|latam|" ;;
        il) printf '%s\n' "Asia/Jerusalem|he_IL.UTF-8|il|" ;;
        tr) printf '%s\n' "Europe/Istanbul|tr_TR.UTF-8|tr|" ;;
        ae) printf '%s\n' "Asia/Dubai|en_AE.UTF-8|us|" ;;
        za) printf '%s\n' "Africa/Johannesburg|en_ZA.UTF-8|us|" ;;
        *) return 1 ;;
    esac
}

_nds_type_int() {
    local _nds_type_value=$1 _nds_type_key=$2
    local _nds_type_min=${_NDS_SCHEMA_ATTR[$_nds_type_key|min]:-}
    local _nds_type_max=${_NDS_SCHEMA_ATTR[$_nds_type_key|max]:-}
    [[ "$_nds_type_value" =~ ^-?[0-9]+$ ]] || return 1
    if [[ -n "$_nds_type_min" && "$_nds_type_value" -lt "$_nds_type_min" ]]; then
        return 1
    fi
    if [[ -n "$_nds_type_max" && "$_nds_type_value" -gt "$_nds_type_max" ]]; then
        return 1
    fi
    return 0
}

_nds_type_port() {
    local _nds_type_value=$1 _nds_type_key=$2
    local _nds_type_min=${_NDS_SCHEMA_ATTR[$_nds_type_key|min]:-1}
    local _nds_type_max=${_NDS_SCHEMA_ATTR[$_nds_type_key|max]:-65535}
    [[ "$_nds_type_value" =~ ^[0-9]+$ ]] || return 1
    if (( _nds_type_value < _nds_type_min || _nds_type_value > _nds_type_max )); then
        return 1
    fi
    return 0
}

_nds_type_choice() {
    local _nds_type_value=$1 _nds_type_key=$2 _nds_type_choice
    local _nds_type_options=${_NDS_SCHEMA_ATTR[$_nds_type_key|choices]:-}
    local -a _nds_type_choices=()
    [[ -n "$_nds_type_options" ]] || return 1
    local IFS='|'
    read -ra _nds_type_choices <<< "$_nds_type_options"
    for _nds_type_choice in "${_nds_type_choices[@]}"; do
        [[ "$_nds_type_value" == "$_nds_type_choice" ]] && return 0
    done
    return 1
}

_nds_type_path() {
    [[ "$1" =~ ^(/|~|\.) ]]
}

_nds_type_ip() {
    local _nds_type_ip=$1
    local IFS='.'
    local -a _nds_type_octets=()
    local _nds_type_i _nds_type_octet
    read -r -a _nds_type_octets <<< "$_nds_type_ip"
    (( ${#_nds_type_octets[@]} == 4 )) || return 1
    for _nds_type_i in "${!_nds_type_octets[@]}"; do
        _nds_type_octet=${_nds_type_octets[$_nds_type_i]}
        [[ "$_nds_type_octet" =~ ^[0-9]+$ ]] || return 1
        [[ "$_nds_type_octet" == 0 || "$_nds_type_octet" != 0[0-9]* ]] || return 1
        if (( _nds_type_octet < 0 || _nds_type_octet > 255 )); then
            return 1
        fi
        if (( _nds_type_i == 0 && _nds_type_octet < 1 )); then
            return 1
        fi
        if (( _nds_type_i == 3 && (_nds_type_octet == 0 || _nds_type_octet == 255) )); then
            return 1
        fi
    done
    return 0
}

_nds_type_ipToInt() {
    local IFS='.'
    local _nds_type_a _nds_type_b _nds_type_c _nds_type_d
    read -r _nds_type_a _nds_type_b _nds_type_c _nds_type_d <<< "$1"
    printf '%s\n' "$((_nds_type_a * 256**3 + _nds_type_b * 256**2 + _nds_type_c * 256 + _nds_type_d))"
}

_nds_type_ipSameSubnet() {
    local _nds_type_ip _nds_type_gw _nds_type_mask
    _nds_type_ip=${ _nds_type_ipToInt "$1"; }
    _nds_type_gw=${ _nds_type_ipToInt "$3"; }
    _nds_type_mask=${ _nds_type_ipToInt "$2"; }
    [[ "$((_nds_type_ip & _nds_type_mask))" -eq "$((_nds_type_gw & _nds_type_mask))" ]]
}

_nds_type_hostname() {
    [[ ${#1} -ge 2 ]] || return 1
    [[ "$1" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]]
}

_nds_type_username() {
    [[ ${#1} -ge 2 ]] || return 1
    [[ "$1" =~ ^[a-z_][a-z0-9_-]{1,31}$ ]]
}

_nds_type_mask() {
    local _nds_type_mask=$1 _nds_type_octet _nds_type_val=0
    local -a _nds_type_octets=()
    if [[ "$_nds_type_mask" =~ ^[0-9]+$ ]]; then
        [[ "$_nds_type_mask" -ge 1 && "$_nds_type_mask" -le 32 ]]
        return
    fi
    local IFS='.'
    read -r -a _nds_type_octets <<< "$_nds_type_mask"
    (( ${#_nds_type_octets[@]} == 4 )) || return 1
    for _nds_type_octet in "${_nds_type_octets[@]}"; do
        [[ "$_nds_type_octet" =~ ^[0-9]+$ ]] || return 1
        if (( _nds_type_octet < 0 || _nds_type_octet > 255 )); then
            return 1
        fi
        _nds_type_val=$(( (_nds_type_val << 8) | _nds_type_octet ))
    done
    if (( _nds_type_val == 0 || _nds_type_val == 0xFFFFFFFF )); then
        return 1
    fi
    if (( (_nds_type_val | (_nds_type_val - 1)) != 0xFFFFFFFF )); then
        return 1
    fi
    return 0
}

_nds_type_url() {
    [[ "$1" =~ ^(https?|git|ssh):// ]] && return 0
    [[ "$1" =~ ^[a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+:.+ ]]
}

_nds_type_timezone() {
    local _nds_type_tz=$1 _nds_type_list
    [[ -n "$_nds_type_tz" ]] || return 1
    if command -v timedatectl >/dev/null 2>&1; then
        if _nds_type_list=$(timedatectl list-timezones 2>/dev/null) && [[ -n "$_nds_type_list" ]]; then
            grep -qxi "$_nds_type_tz" <<< "$_nds_type_list"
            return
        fi
    fi
    case "$_nds_type_tz" in
        UTC|GMT) return 0 ;;
    esac
    [[ "$_nds_type_tz" =~ ^[A-Za-z0-9_+-]+/[A-Za-z0-9_+-]+$ ]]
}

_nds_type_locale() {
    [[ "$1" =~ ^[a-z]{2}_[A-Z]{2}\.(UTF-8|utf8)$ ]]
}

_nds_type_keyboard() {
    local _nds_type_value=$1
    [[ "$_nds_type_value" =~ ^[a-z0-9-]+$ ]] || return 1
    (( ${#_nds_type_value} >= 2 && ${#_nds_type_value} <= 15 ))
}

_nds_type_country() {
    [[ "$1" =~ ^[A-Za-z]{2}$ ]] || return 1
    nds_country_defaults "${1,,}" >/dev/null
}

_nds_type_ok() {
    local _nds_type_type=$1 _nds_type_value=$2 _nds_type_key=$3
    case "$_nds_type_type" in
        string) return 0 ;;
        bool) [[ "$_nds_type_value" == true || "$_nds_type_value" == false ]] ;;
        int) _nds_type_int "$_nds_type_value" "$_nds_type_key" ;;
        port) _nds_type_port "$_nds_type_value" "$_nds_type_key" ;;
        choice) _nds_type_choice "$_nds_type_value" "$_nds_type_key" ;;
        path) _nds_type_path "$_nds_type_value" ;;
        file) _nds_type_path "$_nds_type_value" && [[ -f "$_nds_type_value" ]] ;;
        dir) _nds_type_path "$_nds_type_value" && [[ -d "$_nds_type_value" ]] ;;
        disk) [[ "$_nds_type_value" =~ ^/dev/[a-zA-Z0-9/_-]+$ ]] ;;
        ip) _nds_type_ip "$_nds_type_value" ;;
        hostname) _nds_type_hostname "$_nds_type_value" ;;
        username) _nds_type_username "$_nds_type_value" ;;
        url) _nds_type_url "$_nds_type_value" ;;
        timezone) _nds_type_timezone "$_nds_type_value" ;;
        locale) _nds_type_locale "$_nds_type_value" ;;
        keyboard) _nds_type_keyboard "$_nds_type_value" ;;
        country) _nds_type_country "$_nds_type_value" ;;
        mask) _nds_type_mask "$_nds_type_value" ;;
        secret) _nds_type_path "$_nds_type_value" && [[ -f "$_nds_type_value" && -r "$_nds_type_value" ]] ;;
        *) return 1 ;;
    esac
}
