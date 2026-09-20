#!/usr/bin/env bash
# Install the root-owned files from system/ and reload what needs reloading.
# Run as root, e.g. pkexec system/install.sh
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

install -D -m 644 "$root/udev/rules.d/99-fingerprint-no-autosuspend.rules" /etc/udev/rules.d/99-fingerprint-no-autosuspend.rules
install -D -m 644 "$root/tlp.d/10-fingerprint.conf" /etc/tlp.d/10-fingerprint.conf

udevadm control --reload
udevadm trigger --action=add --subsystem-match=usb --attr-match=idVendor=27c6

printf 'installed udev rule and tlp drop-in\n'
