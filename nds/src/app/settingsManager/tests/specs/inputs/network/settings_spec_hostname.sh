#!/usr/bin/env bash
# Hostname validation tests

test_hostname() {
    # Valid cases
    assert_valid "hostname" "myserver"
    assert_valid "hostname" "web-server-01"
    assert_valid "hostname" "db1"
    assert_valid "hostname" "server123"
    
    # Invalid cases
    assert_invalid "hostname" "_invalid"
    assert_invalid "hostname" "-invalid"
    assert_invalid "hostname" "invalid-"
    assert_invalid "hostname" "in_valid"
    assert_invalid "hostname" "a"         # Too short
    assert_invalid "hostname" "UPPERCASE"
    assert_invalid "hostname" "123VM"
}
