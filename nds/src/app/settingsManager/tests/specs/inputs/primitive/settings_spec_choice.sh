#!/usr/bin/env bash
# Choice validation tests

test_choice() {
    VALIDATOR_OPTIONS=([options]="yes|no|auto")

    assert_valid "choice" "yes"
    assert_valid "choice" "no"
    assert_valid "choice" "auto"
    
    # Invalid choices
    assert_invalid "choice" "y"
    assert_invalid "choice" "n"
    assert_invalid "choice" "maybe"
    assert_invalid "choice" "invalid"

    VALIDATOR_OPTIONS=()
}
