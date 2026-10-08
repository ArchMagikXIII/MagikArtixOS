if lspci | grep -qi 'nvidia'; then
  source "$MAGIKOS_PATH/bin/magikos-pkg-backend"
  source "${MAGIKOS_INSTALL_HELPERS:-${MAGIKOS_INSTALL:-/usr/share/magikos/install}/helpers}/systemd.sh"

  # Check which kernel is installed and set the matching headers package, so
  # DKMS builds below have headers present.
  KERNEL_PACKAGE=$(pacman -Qqs '^linux(-cachyos(-rc)?|-zen|-lts|-hardened|-t2|-ptl|-omarchy(-bore|-muqss)?)?$' | head -1 || true)
  [[ -n $KERNEL_PACKAGE ]] && magikos-pkg-add "$KERNEL_PACKAGE-headers"

  if magikos-hw-nvidia-gsp; then
    # Turing and newer: the prebuilt module for the base kernels ships in
    # magikos-base.packages, so only the userspace pieces are added here.
    # Installing nvidia-open-dkms alongside it would conflict with that
    # NVIDIA-MODULE provider and abort the transaction.
    PACKAGES=(nvidia-utils lib32-nvidia-utils libva-nvidia-driver)

    # On hybrid systems runtime DPM lets the idle dGPU power down instead of
    # idling at ~15W. nvidia-powerd needs the BIOS NvPCF ACPI feature; on
    # laptops without it the daemon exits at boot rather than failing the
    # install, so enabling it here is safe across hardware. Desktop systems
    # with NVIDIA as the only GPU get no benefit and skip this.
    if magikos-hw-nvidia-powerd; then
      magikos_service_enable nvidia-powerd.service
    fi
  elif magikos-hw-nvidia-without-gsp; then
    PACKAGES=(nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils)
  fi

  # Bail if no supported GPU
  if [[ -z ${PACKAGES+x} ]]; then
    echo "No compatible driver for your NVIDIA GPU. See: https://wiki.archlinux.org/title/NVIDIA"
    exit 0
  fi

  magikos-pkg-add "${PACKAGES[@]}"

  # Configure modprobe for early KMS
  mkdir -p /etc/modprobe.d
  cat > /etc/modprobe.d/nvidia.conf <<'EOF'
options nvidia_drm modeset=1
EOF

  # Configure the initramfs generator to load NVIDIA modules early.
  mkdir -p /etc/mkinitcpio.conf.d
  cat > /etc/mkinitcpio.conf.d/nvidia.conf <<'EOF'
MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
EOF
fi
