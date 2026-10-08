#!/bin/bash

# Enable AND start the user systemd units we ship. Runs at first-run rather
# than at finalize-user time because the user manager isn't live during the
# ISO chroot — by first-run, the Hyprland/uwsm session is up and
# `systemctl --user enable --now` both writes the correct .wants symlinks
# (based on each unit's [Install]/WantedBy) and starts the services so the
# first session has bluetooth pairing, sleep lock, etc. live immediately
# instead of waiting for the next login. ConditionPath* in the unit files
# keep the enabled units inert on hardware they don't apply to.
#
# On non-systemd systems (Artix, etc.), user units are skipped entirely.

set -euo pipefail

source "${MAGIKOS_INSTALL_HELPERS:-${MAGIKOS_INSTALL:-/usr/share/magikos/install}/helpers}/systemd.sh"

if ! magikos_has_systemd; then
  magikos_skip_systemd "enable-user-units.sh: not a systemd system"
  exit 0
fi

systemctl --user daemon-reload
systemctl --user enable --now \
  bt-agent.service \
  magikos-recover-internal-monitor.service \
  magikos-sleep-lock.service \
  magikos-migrate-notify.service \
  magikos-fcitx5.service \
  magikos-crash-watch.service
