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

echo "Using Godot ${GODOT_VERSION}"
echo "Checking scripts and resources..."
"${GODOT_EXECUTABLE}" --headless --editor --quit --path "${PROJECT_DIR}"

echo "Checking game startup..."
"${GODOT_EXECUTABLE}" --headless --path "${PROJECT_DIR}" --quit-after 120

echo "Running automated tests..."
"${GODOT_EXECUTABLE}" --headless --path "${PROJECT_DIR}" --script res://Tests/test_runner.gd

echo "KINGDOOM project check passed."
