magikos_log_to_stdout() {
  [[ ${MAGIKOS_LOG_TO_STDOUT:-} == "1" || -z ${MAGIKOS_INSTALL_LOG_FILE:-} ]]
}

magikos_log_line() {
  if magikos_log_to_stdout; then
    echo "$1"
  else
    echo "$1" >>"$MAGIKOS_INSTALL_LOG_FILE"
  fi
}

start_install_log() {
  if ! magikos_log_to_stdout; then
    mkdir -p "$(dirname "$MAGIKOS_INSTALL_LOG_FILE")"
    touch "$MAGIKOS_INSTALL_LOG_FILE"
    chmod 666 "$MAGIKOS_INSTALL_LOG_FILE" 2>/dev/null || true
  fi

  export MAGIKOS_START_TIME="${MAGIKOS_START_TIME:-$(date '+%Y-%m-%d %H:%M:%S')}"
  export MAGIKOS_START_EPOCH="${MAGIKOS_START_EPOCH:-$(date +%s)}"

  magikos_log_line "=== Magikos Setup Started: $MAGIKOS_START_TIME ==="

  # Detect and log the init system
  if [[ -f "${MAGIKOS_INSTALL_HELPERS:-${MAGIKOS_INSTALL:-/usr/share/magikos/install}/helpers}/systemd.sh" ]]; then
    source "${MAGIKOS_INSTALL_HELPERS:-${MAGIKOS_INSTALL:-/usr/share/magikos/install}/helpers}/systemd.sh"
    local init_system
    init_system=$(magikos_detect_init)
    magikos_log_line "Detected init system: $init_system"
  fi
}

stop_install_log() {
  local end_time end_epoch duration mins secs
  end_time=$(date '+%Y-%m-%d %H:%M:%S')
  end_epoch=$(date +%s)

  magikos_log_line "=== Magikos Setup Completed: $end_time ==="

  if [[ -n ${MAGIKOS_START_EPOCH:-} ]]; then
    duration=$((end_epoch - MAGIKOS_START_EPOCH))
    mins=$((duration / 60))
    secs=$((duration % 60))
    magikos_log_line "Magikos setup: ${mins}m ${secs}s"
  fi
}

run_logged() {
  local script="$1"
  local exit_code errexit_was_set=0

  magikos_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Starting: $script"

  case $- in
    *e*)
      errexit_was_set=1
      set +e
      ;;
  esac

  local runner=(bash -eE)
  if [[ ${MAGIKOS_INSTALL_DEBUG:-} == "1" ]]; then
    runner=(bash -x -eE)
  fi

  if magikos_log_to_stdout; then
    PS4='+ ${BASH_SOURCE[0]##*/}:${LINENO}:${FUNCNAME[0]:-main}: ' \
      "${runner[@]}" -c 'source "$1"' bash "$script" </dev/null 2>&1
  else
    PS4='+ ${BASH_SOURCE[0]##*/}:${LINENO}:${FUNCNAME[0]:-main}: ' \
      "${runner[@]}" -c 'source "$1"' bash "$script" </dev/null >>"$MAGIKOS_INSTALL_LOG_FILE" 2>&1
  fi

exit_code=$?
  (( errexit_was_set )) && set -e

  if (( exit_code == 0 )); then
    magikos_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: $script"
  else
    magikos_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: $script (exit code: $exit_code)"
  fi

  # Opt-in best-effort mode, used by the hardware tier. Those leaves are each
  # independently gated on a magikos-hw-* probe and install one vendor package,
  # so a name the active package manager cannot resolve -- a firmware blob that
  # only the Arch repo carries, most often -- would otherwise abort the chain
  # and silently skip every tweak queued behind it. The config, login and
  # post-install phases keep the strict default, where a failure really does
  # mean the rest should not proceed.
  if (( exit_code != 0 )) && [[ ${MAGIKOS_INSTALL_BEST_EFFORT:-0} == "1" ]]; then
    MAGIKOS_INSTALL_SKIPPED_LEAVES+=("$script")
    return 0
  fi

  return $exit_code
}
