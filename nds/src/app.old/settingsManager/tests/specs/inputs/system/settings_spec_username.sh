#!/usr/bin/env bash
# Username validation tests

test_username() {
    # Valid cases
    assert_valid "username" "admin"
    assert_valid "username" "user123"
    assert_valid "username" "_test"
    assert_valid "username" "myuser"
    
    # Invalid cases
    assert_invalid "username" "123user"     # Starts with number
    assert_invalid "username" "User"        # Uppercase
    assert_invalid "username" "user@host"   # Special char
    assert_invalid "username" "a"           # Too short
}
