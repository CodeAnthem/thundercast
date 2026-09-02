#!/usr/bin/env bash
# Port validation tests

test_port() {
    # Valid cases
    assert_valid "port" "22"
    assert_valid "port" "80"
    assert_valid "port" "443"
    assert_valid "port" "8080"
    assert_valid "port" "1"
    assert_valid "port" "65535"
    
    # Invalid cases
    assert_invalid "port" "0"
    assert_invalid "port" "65536"
    assert_invalid "port" "-1"
    assert_invalid "port" "abc"
}
