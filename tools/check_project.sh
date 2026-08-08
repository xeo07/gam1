#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

find_godot() {
	if [[ -n "${GODOT_BIN:-}" && -x "${GODOT_BIN}" ]]; then
		printf '%s\n' "${GODOT_BIN}"
		return 0
	fi

	local candidate
	for candidate in \
		"/Users/xeo/Downloads/Godot.app/Contents/MacOS/Godot" \
		"/Applications/Godot.app/Contents/MacOS/Godot" \
		"${HOME}/Applications/Godot.app/Contents/MacOS/Godot"
	do
		if [[ -x "${candidate}" ]]; then
			printf '%s\n' "${candidate}"
			return 0
		fi
	done

	if command -v godot >/dev/null 2>&1; then
		command -v godot
		return 0
	fi

	if command -v godot4 >/dev/null 2>&1; then
		command -v godot4
		return 0
	fi

	return 1
}

if ! GODOT_EXECUTABLE="$(find_godot)"; then
	echo "ERROR: Godot 4.7.1 was not found. Set GODOT_BIN to its executable path." >&2
	exit 1
fi

GODOT_VERSION="$("${GODOT_EXECUTABLE}" --version)"
if [[ "${GODOT_VERSION}" != 4.7.1.* ]]; then
	echo "ERROR: KINGDOOM requires Godot 4.7.1, found ${GODOT_VERSION}." >&2
	exit 1
fi

run_godot_check() {
	local label="$1"
	shift
	local log_file
	log_file="$(mktemp "${TMPDIR:-/tmp}/kingdoom-godot-check.XXXXXX")"

	echo "${label}"
	set +e
	"${GODOT_EXECUTABLE}" "$@" 2>&1 | tee "${log_file}"
	local godot_status="${PIPESTATUS[0]}"
	set -e

	if [[ "${godot_status}" -ne 0 ]]; then
		echo "ERROR: Godot exited with status ${godot_status}. Log: ${log_file}" >&2
		exit "${godot_status}"
	fi
	if grep -Eq 'SCRIPT ERROR:|(^|[[:space:]])ERROR:' "${log_file}"; then
		echo "ERROR: Godot reported an error. Log: ${log_file}" >&2
		exit 1
	fi
}

echo "Using Godot ${GODOT_VERSION}"
run_godot_check \
	"Checking scripts and resources..." \
	--headless --editor --quit --path "${PROJECT_DIR}"
run_godot_check \
	"Checking game startup..." \
	--headless --path "${PROJECT_DIR}" --quit-after 120
run_godot_check \
	"Running automated tests..." \
	--headless --path "${PROJECT_DIR}" --script res://Tests/test_runner.gd

echo "KINGDOOM project check passed."
