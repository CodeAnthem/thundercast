#!/usr/bin/env bash
# IP validation tests

test_ip() {
    # Valid cases
    assert_valid "ip" "192.168.1.1"
    assert_valid "ip" "10.0.0.1"
    assert_valid "ip" "172.16.0.1"
    assert_valid "ip" "1.1.1.1"
    
    # Invalid cases
    assert_invalid "ip" "_invalid"
    assert_invalid "ip" "256.1.1.1"
    assert_invalid "ip" "192.168.1"
    assert_invalid "ip" "192.168.1.0"      # Last octet 0
    assert_invalid "ip" "192.168.1.255"    # Last octet 255
    assert_invalid "ip" "0.0.0.1"          # First octet 0
    assert_invalid "ip" "192.168.01.1"     # Leading zero
}
