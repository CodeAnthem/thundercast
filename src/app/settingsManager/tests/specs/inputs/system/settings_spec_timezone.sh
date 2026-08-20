#!/usr/bin/env bash
# Timezone validation tests

test_timezone() {
    assert_valid "timezone" "UTC"
    assert_valid "timezone" "GMT"
    assert_valid "timezone" "Europe/Zurich"
    assert_valid "timezone" "America/New_York"
    assert_valid "timezone" "Asia/Tokyo"

    if command -v timedatectl &>/dev/null && timedatectl list-timezones &>/dev/null; then
        assert_invalid "timezone" "InvalidZone"
        assert_invalid "timezone" "NotACity"
        assert_invalid "timezone" "Europe/FakeCity"
    else
        console "  (skipped invalid timezone cases — timedatectl unavailable)"
    fi
}
