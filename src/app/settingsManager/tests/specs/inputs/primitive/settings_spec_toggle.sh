#!/usr/bin/env bash
# Toggle validation tests

test_toggle() {
    assert_valid "toggle" "true"
    assert_valid "toggle" "false"
    assert_valid "toggle" "yes"
    assert_valid "toggle" "no"
    assert_valid "toggle" "enabled"
    assert_valid "toggle" "disabled"
    assert_valid "toggle" "y"
    assert_valid "toggle" "n"
    assert_valid "toggle" "1"
    assert_valid "toggle" "0"

    assert_invalid "toggle" "maybe"
    assert_invalid "toggle" "on"
    assert_invalid "toggle" ""
}
