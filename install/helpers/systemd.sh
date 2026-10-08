# Init system detection and service management for Magikos installer
#
# Provides detection and service enable/disable/mask operations for systemd,
# OpenRC, and runit. This allows the installer to work on Artix Linux and
# other Arch-based distributions that use alternative init systems.
#
# Environment variables:
#   MAGIKOS_NO_SYSTEMD=1  - Force-disable systemd operations
#   MAGIKOS_NO_OPENRC=1   - Force-disable OpenRC operations
#   MAGIKOS_NO_RUNIT=1   - Force-disable runit operations

# --- Detection ---

magikos_has_systemd() {
  if [[ "${MAGIKOS_NO_SYSTEMD:-0}" == "1" ]]; then
    return 1
  fi
  if [[ -d /run/systemd/system ]]; then
    return 0
  fi
  if command -v systemctl >/dev/null 2>&1; then
    if systemctl is-system-running &>/dev/null || \
       systemctl is-system-running 2>/dev/null | grep -qE "running|degraded"; then
      return 0
    fi
  fi
  return 1
}

magikos_has_openrc() {
  if [[ "${MAGIKOS_NO_OPENRC:-0}" == "1" ]]; then
    return 1
  fi
  command -v rc-update >/dev/null 2>&1 && [[ -d /etc/init.d ]]
}

magikos_has_runit() {
  if [[ "${MAGIKOS_NO_RUNIT:-0}" == "1" ]]; then
    return 1
  fi
  command -v runsv >/dev/null 2>&1 && [[ -d /etc/sv || -d /etc/runit/sv ]]
}

# --- Service operations ---

# OpenRC and runit register services without the systemd unit suffix, so
# "snapper-cleanup.timer" or "lightdm.service" must be looked up as
# "snapper-cleanup" / "lightdm". systemd keeps the full unit name.
magikos_service_name() {
  local name="$1"
  case "$name" in
    *.service|*.timer|*.socket) name="${name%.*}" ;;
  esac
  printf '%s\n' "$name"
}

# Enable a service (start at boot)
magikos_service_enable() {
  local service="$1"

  if magikos_has_systemd; then
    systemctl enable "$service" 2>/dev/null || true
  elif magikos_has_openrc; then
    service="$(magikos_service_name "$service")"
    rc-update add "$service" default 2>/dev/null || true
  elif magikos_has_runit; then
    service="$(magikos_service_name "$service")"
    if [[ -d "/etc/sv/$service" ]]; then
      mkdir -p /etc/service
      ln -sf "/etc/sv/$service" "/etc/service/$service"
    fi
  else
    echo "No init system found; cannot enable $service"
  fi
}

# Disable a service (don't start at boot)
magikos_service_disable() {
  local service="$1"

  if magikos_has_systemd; then
    systemctl disable "$service" 2>/dev/null || true
  elif magikos_has_openrc; then
    service="$(magikos_service_name "$service")"
    rc-update del "$service" default 2>/dev/null || true
  elif magikos_has_runit; then
    service="$(magikos_service_name "$service")"
    rm -f "/etc/service/$service"
  fi
}

# Mask a service (prevent from starting)
magikos_service_mask() {
  local service="$1"

  if magikos_has_systemd; then
    systemctl mask "$service" 2>/dev/null || true
  elif magikos_has_openrc; then
    # OpenRC doesn't have a direct mask equivalent; disable is the closest
    service="$(magikos_service_name "$service")"
    rc-update del "$service" default 2>/dev/null || true
  elif magikos_has_runit; then
    service="$(magikos_service_name "$service")"
    rm -f "/etc/service/$service"
  fi
}

# Check if a service is active
magikos_service_is_active() {
  local service="$1"

  if magikos_has_systemd; then
    systemctl is-active --quiet "$service" 2>/dev/null
  elif magikos_has_openrc; then
    service="$(magikos_service_name "$service")"
    rc-service "$service" status 2>/dev/null | grep -q "started"
  elif magikos_has_runit; then
    service="$(magikos_service_name "$service")"
    [[ -d "/etc/service/$service" ]] && sv status "$service" 2>/dev/null | grep -q "run"
  fi
}

# Stop a service
magikos_service_stop() {
  local service="$1"

  if magikos_has_systemd; then
    systemctl stop "$service" 2>/dev/null || true
  elif magikos_has_openrc; then
    service="$(magikos_service_name "$service")"
    rc-service "$service" stop 2>/dev/null || true
  elif magikos_has_runit; then
    service="$(magikos_service_name "$service")"
    sv stop "$service" 2>/dev/null || true
  fi
}

# --- Convenience ---

magikos_skip_systemd() {
  local reason="${1:-systemd not available}"
  echo "Skipping systemd operation: $reason"
}

# Detect which init system is available and print it
magikos_detect_init() {
  if magikos_has_systemd; then
    echo "systemd"
  elif magikos_has_openrc; then
    echo "openrc"
  elif magikos_has_runit; then
    echo "runit"
  else
    echo "unknown"
  fi
}
