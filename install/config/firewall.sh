# Allow nothing in, everything out.
#
# ufw is not part of every MagikOS base set -- the Debian list leaves it to the
# administrator -- so this leaf no-ops when the firewall is not installed
# instead of failing and aborting the rest of the post-install chain.
if ! command -v ufw >/dev/null 2>&1; then
  echo "ufw not installed; skipping firewall configuration"
  return 0
fi

# ufw drives iptables, and `iptables --version` fails outright when the
# booted kernel has no netfilter modules to load -- the typical state after
# a kernel swap the machine has not rebooted into yet, where the old
# kernel's modules are already gone while it is still running. Skip like
# the missing-ufw case instead of aborting the chain; a reboot and re-run
# configures the firewall on a kernel that has the modules.
if ! iptables --version >/dev/null 2>&1; then
  echo "iptables is not usable on the running kernel; skipping firewall configuration"
  echo "Reboot into an installed kernel, then re-run the installer to set up ufw"
  return 0
fi

ufw default deny incoming
ufw default allow outgoing

# Allow ports for LocalSend.
ufw allow 53317/udp
ufw allow 53317/tcp

# Installs are followed by reboot, so configure UFW to start on the installed
# system instead of mutating the live install session's firewall.
sed -i 's/^ENABLED=.*/ENABLED=yes/' /etc/ufw/ufw.conf

source "${MAGIKOS_INSTALL_HELPERS:-${MAGIKOS_INSTALL:-/usr/share/magikos/install}/helpers}/systemd.sh"

# OpenRC and runit ship the init script as a companion package; without it
# magikos_service_enable cannot register the service. systemd ships the unit
# with ufw itself.
if magikos_has_systemd; then
  true
elif magikos_has_openrc && [[ ! -f /etc/init.d/ufw ]] \
    && command -v pacman >/dev/null 2>&1 && pacman -Si ufw-openrc >/dev/null 2>&1; then
  magikos-pkg-add ufw-openrc || true
elif magikos_has_runit && [[ ! -d /etc/sv/ufw ]] \
    && command -v pacman >/dev/null 2>&1 && pacman -Si ufw-runit >/dev/null 2>&1; then
  magikos-pkg-add ufw-runit || true
fi
magikos_service_enable ufw
