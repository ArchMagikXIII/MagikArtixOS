# Fix NVMe suspend issues on MacBook models
# This prevents NVMe drives from failing to wake from sleep properly
MACBOOK_MODEL=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)

if [[ $MACBOOK_MODEL =~ MacBook(8,1|9,1|10,1)|MacBookPro13,[123]|MacBookPro14,[123] ]]; then
  echo "Detected MacBook model: $MACBOOK_MODEL"

  NVME_DEVICE="/sys/bus/pci/devices/0000:01:00.0/d3cold_allowed"

  if [[ -f $NVME_DEVICE ]]; then
    echo "Applying NVMe suspend fix..."

    source "${MAGIKOS_INSTALL_HELPERS:-${MAGIKOS_INSTALL:-/usr/share/magikos/install}/helpers}/systemd.sh"
    if magikos_has_systemd; then
      sudo mkdir -p /etc/systemd/system
      sudo tee /etc/systemd/system/magikos-nvme-suspend-fix.service >/dev/null <<'EOF'
[Unit]
Description=Magikos NVMe Suspend Fix for MacBook

[Service]
ExecStart=/bin/bash -c 'echo 0 > /sys/bus/pci/devices/0000\:01\:00.0/d3cold_allowed'

[Install]
WantedBy=multi-user.target
EOF
      sudo systemctl enable magikos-nvme-suspend-fix.service
    elif magikos_has_openrc; then
      sudo mkdir -p /etc/init.d
      sudo tee /etc/init.d/magikos-nvme-suspend-fix >/dev/null <<'EOF'
#!/sbin/openrc-run

description="Magikos NVMe Suspend Fix for MacBook"

depend() {
  after bootmisc
}

start() {
  echo "Applying NVMe suspend fix..."
  echo 0 > /sys/bus/pci/devices/0000:01:00.0/d3cold_allowed
}
EOF
      sudo chmod +x /etc/init.d/magikos-nvme-suspend-fix
      sudo rc-update add magikos-nvme-suspend-fix default
    elif magikos_has_runit; then
      sudo mkdir -p /etc/sv/magikos-nvme-suspend-fix
      sudo tee /etc/sv/magikos-nvme-suspend-fix/run >/dev/null <<'EOF'
#!/bin/sh
echo 0 > /sys/bus/pci/devices/0000:01:00.0/d3cold_allowed
exec sleep infinity
EOF
      sudo chmod +x /etc/sv/magikos-nvme-suspend-fix/run
      sudo ln -sf /etc/sv/magikos-nvme-suspend-fix /etc/service/magikos-nvme-suspend-fix
    else
      echo "No init system found; cannot install NVMe suspend fix"
    fi
  else
    echo "Warning: NVMe device not found at expected PCI address (0000:01:00.0)"
    echo "This fix may not be needed for this MacBook model"
  fi
fi
