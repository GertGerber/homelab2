#!/usr/bin/env bash
set -euo pipefail

# Python toolchain (keeps things tidy and repeatable):
python3 -m venv .venv && source .venv/bin/activate
pip install --upgrade pip
pip install "ansible>=9" ansible-lint


