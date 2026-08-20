#!/usr/bin/env bash
# ==================================================================================================
# NDS - Country defaults
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-08-04
# Description:   Country → timezone/locale/keyboard defaults for quick setup
# ==================================================================================================

# Returns: timezone|locale|keyboard|keyboard_variant
nds_country_defaults() {
    case "${1,,}" in
        us) echo "America/New_York|en_US.UTF-8|us|" ;;
        ca) echo "America/Toronto|en_CA.UTF-8|us|" ;;
        mx) echo "America/Mexico_City|es_MX.UTF-8|latam|" ;;
        de) echo "Europe/Berlin|de_DE.UTF-8|de|nodeadkeys" ;;
        fr) echo "Europe/Paris|fr_FR.UTF-8|fr|oss" ;;
        uk|gb) echo "Europe/London|en_GB.UTF-8|uk|" ;;
        es) echo "Europe/Madrid|es_ES.UTF-8|es|" ;;
        it) echo "Europe/Rome|it_IT.UTF-8|it|" ;;
        nl) echo "Europe/Amsterdam|nl_NL.UTF-8|us|intl" ;;
        be) echo "Europe/Brussels|fr_BE.UTF-8|be|" ;;
        ch) echo "Europe/Zurich|de_CH.UTF-8|ch|de_nodeadkeys" ;;
        at) echo "Europe/Vienna|de_AT.UTF-8|de|nodeadkeys" ;;
        pt) echo "Europe/Lisbon|pt_PT.UTF-8|pt|" ;;
        se) echo "Europe/Stockholm|sv_SE.UTF-8|se|" ;;
        no) echo "Europe/Oslo|nb_NO.UTF-8|no|" ;;
        dk) echo "Europe/Copenhagen|da_DK.UTF-8|dk|" ;;
        fi) echo "Europe/Helsinki|fi_FI.UTF-8|fi|" ;;
        pl) echo "Europe/Warsaw|pl_PL.UTF-8|pl|" ;;
        cz) echo "Europe/Prague|cs_CZ.UTF-8|cz|" ;;
        ru) echo "Europe/Moscow|ru_RU.UTF-8|ru|" ;;
        ua) echo "Europe/Kiev|uk_UA.UTF-8|ua|" ;;
        jp) echo "Asia/Tokyo|ja_JP.UTF-8|jp|" ;;
        cn) echo "Asia/Shanghai|zh_CN.UTF-8|us|" ;;
        kr) echo "Asia/Seoul|ko_KR.UTF-8|kr|" ;;
        in) echo "Asia/Kolkata|en_IN.UTF-8|us|" ;;
        sg) echo "Asia/Singapore|en_SG.UTF-8|us|" ;;
        au) echo "Australia/Sydney|en_AU.UTF-8|us|" ;;
        nz) echo "Pacific/Auckland|en_NZ.UTF-8|us|" ;;
        br) echo "America/Sao_Paulo|pt_BR.UTF-8|br|abnt2" ;;
        ar) echo "America/Argentina/Buenos_Aires|es_AR.UTF-8|latam|" ;;
        cl) echo "America/Santiago|es_CL.UTF-8|latam|" ;;
        il) echo "Asia/Jerusalem|he_IL.UTF-8|il|" ;;
        tr) echo "Europe/Istanbul|tr_TR.UTF-8|tr|" ;;
        ae) echo "Asia/Dubai|en_AE.UTF-8|us|" ;;
        za) echo "Africa/Johannesburg|en_ZA.UTF-8|us|" ;;
        *) return 1 ;;
    esac
}

# Description: Apply timezone/locale/keyboard defaults for a country code.
nds_country_apply() {
    local country="$1" defaults timezone locale keyboard keyboard_variant
    defaults=$(nds_country_defaults "$country") || return 1
    IFS='|' read -r timezone locale keyboard keyboard_variant <<< "$defaults"
    nds_cfg_set REGION_TIMEZONE "$timezone"
    nds_cfg_set REGION_LOCALE_MAIN "$locale"
    nds_cfg_set REGION_KEYBOARD_LAYOUT "$keyboard"
    nds_cfg_set REGION_KEYBOARD_VARIANT "$keyboard_variant"
    return 0
}
