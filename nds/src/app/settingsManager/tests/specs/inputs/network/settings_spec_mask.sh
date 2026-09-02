#!/usr/bin/env bash
# Network mask validation tests

test_mask() {
    # Valid CIDR
    assert_valid "mask" "24"
    assert_valid "mask" "16"
    assert_valid "mask" "8"
    assert_valid "mask" "32"
    
    # Valid dotted decimal
    assert_valid "mask" "255.255.255.0"
    assert_valid "mask" "255.255.0.0"
    assert_valid "mask" "255.0.0.0"
    
    # Invalid cases
    assert_invalid "mask" "33"            # CIDR > 32
    assert_invalid "mask" "0"             # CIDR = 0
    assert_invalid "mask" "255.255.255.1" # Not contiguous
    assert_invalid "mask" "192.168.1.1"   # Not a valid mask
}
