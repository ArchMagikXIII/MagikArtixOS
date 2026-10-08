source "${MAGIKOS_INSTALL_HELPERS:-${MAGIKOS_INSTALL:-/usr/share/magikos/install}/helpers}/systemd.sh"

# NetworkManager enablement is centralized in enable-services.sh.
magikos_service_disable iwd

# Fresh Magikos uses NetworkManager. Archinstall's legacy "copy ISO network"
# mode enabled systemd-networkd and dropped DHCP .network files that compete
# with NetworkManager, so retire that state whenever hardware setup runs.
for unit in \
  systemd-networkd \
  systemd-networkd.socket \
  systemd-networkd-varlink.socket \
  systemd-networkd-varlink-metrics.socket \
  systemd-networkd-resolve-hook.socket; do
  magikos_service_disable "$unit"
done

# Prevent systemd-networkd-wait-online timeout on boot.
magikos_service_disable systemd-networkd-wait-online
magikos_service_mask systemd-networkd-wait-online

stock_networkd_file() {
  local file="$1"

  [[ -f $file ]] || return 1
  case "$(basename "$file")" in
    20-ethernet.network|20-wlan.network|20-wwan.network) ;;
    *) return 1 ;;
  esac

  grep -Eq '^[[:space:]]*DHCP=yes[[:space:]]*$' "$file" || return 1
  grep -Eq '^[[:space:]]*Name=(en\*|eth\*|wl\*|ww\*)[[:space:]]*$' "$file" || return 1
}

backup_dir="/etc/systemd/network/magikos-networkd-retired-$(date +%Y%m%d%H%M%S)"
for file in /etc/systemd/network/20-ethernet.network /etc/systemd/network/20-wlan.network /etc/systemd/network/20-wwan.network; do
  if stock_networkd_file "$file"; then
    install -d -m 0755 "$backup_dir"
    mv "$file" "$backup_dir/"
  fi
done

if magikos_service_is_active NetworkManager; then
  magikos_service_stop systemd-networkd
fi
