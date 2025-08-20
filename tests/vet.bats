#!/usr/bin/env bats
#
# SPDX-FileCopyrightText: 2025-present Artem Lykhvar and contributors
#
# SPDX-License-Identifier: MIT
#
load 'helpers/bats-support/load.bash'
load 'helpers/bats-assert/load.bash'

assert_file_exists() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "Expected file '$file' to exist, but it does not."
    return 1
  fi
}

setup() {
    export TEST_DIR
    TEST_DIR="$(mktemp -d)"
    export HOME="$TEST_DIR"
    mkdir -p "${TEST_DIR}/mocks"
    export PATH="${TEST_DIR}/mocks:${PATH}"
    VET_SCRIPT="${BATS_TEST_DIRNAME}/../vet"
}

teardown() {
    rm -rf "$TEST_DIR"
}

create_mock() {
    local name="$1"
    local script_content="$2"
    local mock_path="${TEST_DIR}/mocks/${name}"
    printf '%s\n' "#!/bin/bash" "$script_content" > "$mock_path"
    chmod +x "$mock_path"
}

create_curl_mock() {
    local fixture_path="$1"
    local script_content=$(cat <<EOF
output_file=""
while [ "\$#" -gt 0 ]; do
    case "\$1" in
        -o|--output) output_file="\$2"; shift ;;
    esac
    shift
done
if [ -z "\$output_file" ]; then
    echo "MOCK-CURL-ERROR: No output file specified with -o or --output" >&2
    exit 1
fi
cat '${fixture_path}' > "\$output_file"
exit 0
EOF
)
    create_mock "curl" "$script_content"
}

create_downloader_mock() {
    local downloader_name="$1"
    local fixture_path="$2"
    local args_log_file="$3"

    local script_content=$(cat <<EOF
echo "\$@" > "${args_log_file}"

output_file=""
while [ "\$#" -gt 0 ]; do
    case "\$1" in
        -o|--output) output_file="\$2"; shift ;; # curl
        -O)          output_file="\$2"; shift ;; # wget -qO
    esac
    shift
done
if [ -n "\$output_file" ]; then
    cat '${fixture_path}' > "\$output_file"
fi
exit 0
EOF
)
    create_mock "$downloader_name" "$script_content"
}

@test "vet --help shows usage" {
    run "$VET_SCRIPT" --help
    assert_output --partial "USAGE:"
    assert_output --partial "--force"
}

@test "vet handles first-time run and caches the script" {
    create_curl_mock "${BATS_TEST_DIRNAME}/fixtures/simple_success.sh"
    run bash -c "echo 'y' | ${VET_SCRIPT} http://example.com/script.sh"
    assert_success
    assert_output --partial "Simple script executed successfully"
    assert_output --partial "Script cached for future comparison"
    assert_file_exists "${HOME}/.cache/vet/"*".sh"
}

@test "vet detects and diffs a changed script" {
    create_curl_mock "${BATS_TEST_DIRNAME}/fixtures/updatable_v1.sh"
    run bash -c "echo 'y' | ${VET_SCRIPT} http://example.com/updatable.sh"
    assert_success

    create_curl_mock "${BATS_TEST_DIRNAME}/fixtures/updatable_v2.sh"
    create_mock "less"    'echo "BAT DIFF WAS CALLED"; exit 0'
    run bash -c "echo -e 'y\nn' | ${VET_SCRIPT} http://example.com/updatable.sh"
    assert_failure
    assert_output --partial "Script has CHANGED"
    assert_output --partial "DIFF WAS CALLED"
}

@test "vet uses shellcheck for analysis" {
    create_curl_mock "${BATS_TEST_DIRNAME}/fixtures/shellcheck_warning.sh"
    create_mock "shellcheck" 'echo "SHELLCHECK WAS CALLED"; exit 1'
    run bash -c "echo -e 'y\nn' | ${VET_SCRIPT} http://example.com/bad_script.sh"
    assert_failure
    assert_output --partial "SHELLCHECK WAS CALLED"
    assert_output --partial "ShellCheck found potential issues"
}

@test "vet runs in --force mode without prompts" {
    create_curl_mock "${BATS_TEST_DIRNAME}/fixtures/simple_success.sh"
    run "$VET_SCRIPT" --force http://example.com/script.sh
    assert_success
    assert_output --partial "Executing in --force mode"
    refute_output --partial "Execute this script? [y/N]"
}

@test "vet correctly passes arguments to the remote script" {
    create_curl_mock "${BATS_TEST_DIRNAME}/fixtures/with_args.sh"
    run bash -c "echo 'y' | ${VET_SCRIPT} http://example.com/args.sh 'arg one' '--flag'"
    assert_success
    assert_output --partial "Arg 1: arg one"
    assert_output --partial "Arg 2: --flag"
}

@test "vet propagates the exit code of a failing script" {
    create_curl_mock "${BATS_TEST_DIRNAME}/fixtures/always_fails.sh"
    run bash -c "echo 'y' | ${VET_SCRIPT} http://example.com/fail.sh"
    assert_failure
    assert_equal "$status" 42
    assert_output --partial "Script finished with a non-zero exit code: 42"
}

@test "vet fails gracefully on an empty download" {
    create_curl_mock "${BATS_TEST_DIRNAME}/fixtures/empty.sh"
    run "$VET_SCRIPT" http://example.com/empty.sh
    assert_failure
    assert_output --partial "Downloaded file is empty"
}

@test "vet handles --token-stdin when piped" {
    local args_log="${TEST_DIR}/downloader_args.log"
    create_downloader_mock "curl" "${BATS_TEST_DIRNAME}/fixtures/simple_success.sh" "$args_log"

    run bash -c "(echo 'secret-token'; echo 'y') | ${VET_SCRIPT} --token-stdin http://example.com/script.sh"
    assert_success

    run grep -q -- "-H Authorization: Bearer secret-token" "$args_log"
    assert_success "Expected to find bearer token header in curl args"
}

@test "vet fails when --token-stdin receives no input" {
    create_curl_mock "${BATS_TEST_DIRNAME}/fixtures/simple_success.sh"

    run ${VET_SCRIPT} --token-stdin http://example.com/script.sh < /dev/null

    assert_failure
    assert_output --partial "Failed to read a non-empty token from stdin"
}

@test "vet uses VET_AUTH_TOKEN environment variable for authentication" {
    local args_log="${TEST_DIR}/downloader_args.log"
    create_downloader_mock "curl" "${BATS_TEST_DIRNAME}/fixtures/simple_success.sh" "$args_log"

    export VET_AUTH_TOKEN="env-secret-token"
    run bash -c "echo 'y' | ${VET_SCRIPT} http://example.com/script.sh"

    assert_success

    run grep -q -- "-H Authorization: Bearer env-secret-token" "$args_log"
    assert_success "Expected to find VET_AUTH_TOKEN bearer header in curl args"
}

@test "vet handles --netrc flag and shows compatibility warning" {
    local args_log="${TEST_DIR}/downloader_args.log"
    echo "machine example.com login user password pass" > "${HOME}/.netrc"
    create_downloader_mock "curl" "${BATS_TEST_DIRNAME}/fixtures/simple_success.sh" "$args_log"

    run bash -c "echo 'y' | ${VET_SCRIPT} --netrc http://example.com/script.sh"

    assert_success
    assert_output --partial "The --netrc flag is often incompatible"
    run grep -q -- "-n" "$args_log"
    assert_success "Expected to find -n flag in curl args"
}

@test "vet prioritizes --token-stdin over VET_AUTH_TOKEN" {
    local args_log="${TEST_DIR}/downloader_args.log"
    create_downloader_mock "curl" "${BATS_TEST_DIRNAME}/fixtures/simple_success.sh" "$args_log"

    export VET_AUTH_TOKEN="env-token-should-be-ignored"
    run bash -c "(echo 'stdin-token-is-king'; echo 'y') | ${VET_SCRIPT} --token-stdin http://example.com/script.sh"

    assert_success

    run grep -q -- "-H Authorization: Bearer stdin-token-is-king" "$args_log"
    assert_success "Expected stdin token to be used"

    run grep -q "env-token-should-be-ignored" "$args_log"
    assert_failure "Expected environment token to be ignored"
}

@test "vet prioritizes VET_AUTH_TOKEN over --netrc" {
    local args_log="${TEST_DIR}/downloader_args.log"
    echo "machine example.com login user password pass" > "${HOME}/.netrc"
    create_downloader_mock "curl" "${BATS_TEST_DIRNAME}/fixtures/simple_success.sh" "$args_log"

    export VET_AUTH_TOKEN="the-real-token"
    run bash -c "echo 'y' | ${VET_SCRIPT} --netrc http://example.com/script.sh"

    assert_success

    run grep -q -- "-H Authorization: Bearer the-real-token" "$args_log"
    assert_success "Expected VET_AUTH_TOKEN to be used"

    run grep -q -- "-n" "$args_log"
    assert_failure "Expected -n flag to be ignored when VET_AUTH_TOKEN is present"
}

@test "vet uses --auth-header with VET_AUTH_TOKEN for custom authentication" {
    local args_log="${TEST_DIR}/downloader_args.log"
    create_downloader_mock "curl" "${BATS_TEST_DIRNAME}/fixtures/simple_success.sh" "$args_log"

    export VET_AUTH_TOKEN="glpat-abcdef123456"

    run "$VET_SCRIPT" --force --auth-header "PRIVATE-TOKEN: {}" http://example.com/gitlab-script.sh

    assert_success

    run cat "$args_log"
    assert_output --partial "-H PRIVATE-TOKEN: glpat-abcdef123456"

    refute_output --partial "Bearer"
}

@test "vet handles piped token and confirmation in non-interactive mode" {
    local args_log="${TEST_DIR}/downloader_args.log"
    create_downloader_mock "curl" "${BATS_TEST_DIRNAME}/fixtures/simple_success.sh" "$args_log"

    run bash -c "(echo 'secret-token'; echo 'y') | ${VET_SCRIPT} --token-stdin http://example.com/script.sh"

    assert_success
    assert_output --partial "Simple script executed successfully"

    run cat "$args_log"
    assert_output --partial "-H Authorization: Bearer secret-token"
}


@test "vet switches to keyboard for prompts after piping token" {
    local args_log="${TEST_DIR}/downloader_args.log"
    create_downloader_mock "curl" "${BATS_TEST_DIRNAME}/fixtures/simple_success.sh" "$args_log"

    local keyboard_pipe="${TEST_DIR}/keyboard_pipe"
    mkfifo "$keyboard_pipe"

    ( sleep 0.5 && echo 'y' > "$keyboard_pipe" ) &

    run script -q -c "echo 'secret-token' | ${VET_SCRIPT} --token-stdin http://example.com/script.sh" /dev/null < "$keyboard_pipe"

    assert_success "Script should succeed after user confirms with 'y'"
    assert_output --partial "Simple script executed successfully"

    run cat "$args_log"
    assert_output --partial "-H Authorization: Bearer secret-token"
}
