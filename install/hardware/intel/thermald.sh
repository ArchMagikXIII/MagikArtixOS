# Enable thermald for Intel laptops (Sandy Bridge and newer)
# Thermald is useful for Intel Sandy Bridge (2nd gen Core, model 42/45) and newer CPUs.

if magikos-hw-intel; then
  # Check if Sandy Bridge or newer (model >= 42). Sandy Bridge: model 42 (mobile), 45 (desktop)
  cpu_model=$(grep -m1 "^model\s*:" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | tr -d ' ')
  cpu_model=${cpu_model:-0}
  if ((cpu_model >= 42)) && magikos-battery-present; then
    magikos-pkg-add thermald
    source "${MAGIKOS_INSTALL_HELPERS:-${MAGIKOS_INSTALL:-/usr/share/magikos/install}/helpers}/systemd.sh"
    magikos_service_enable thermald
  fi
fi
