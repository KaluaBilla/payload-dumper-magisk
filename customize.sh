# Magisk customize.sh to let installer choose which payload_dumper binary(s) to install

# prepare
ARCH=$(getprop ro.product.cpu.abi)
if [ -z "$ARCH" ]; then
  abort "- !! Failed to detect ARCH via getprop. Using 'unknown'."
fi

BIN_RUST="$MODPATH/bins/rust/payload_dumper-${ARCH}"
BIN_GO="$MODPATH/bins/go/payload_dumper-${ARCH}"
DEST_DIR="$MODPATH/system/bin"

mkdir -p "$DEST_DIR" || {
  ui_print "- !! Failed to mkdir $DEST_DIR"
  exit 1
}

# options
OPTIONS="rust go both"
# start index 0 -> rust
idx=0
sel="${OPTIONS%% *}" # rust

# show current selection
show_sel() {
  case "$sel" in
    rust) ui_print "- Selected: Rust binary only" ;;
    go)   ui_print "- Selected: Go binary only" ;;
    both) ui_print "- Selected: Both (payload_dumper_rust + payload_dumper_go)" ;;
    *)    ui_print "- Selected: $sel" ;;
  esac
  ui_print "- Press VOLUME UP to confirm, VOLUME DOWN to cycle. Waiting up to ${timeout}s..."
}

# this logic is taken from 
# https://github.com/Magisk-Modules-Alt-Repo/YetAnotherBootloopProtector/blob/793105cff8ccf0e3a251cca74a59e1e89a3c9213/customize.sh#L19
timeout=10
show_sel
while true; do
  event=$(timeout ${timeout} getevent -qlc 1 2>/dev/null)
  exitcode=$?
  if [ "$exitcode" -eq 124 ] || [ "$exitcode" -eq 143 ]; then
    ui_print "No keypress detected within ${timeout}s. Defaulting to 'both'."
    sel="both"
    break
  fi

  if echo "$event" | grep -q "KEY_VOLUMEUP"; then
    ui_print "Volume UP detected: confirming selection."
    break
  elif echo "$event" | grep -q "KEY_VOLUMEDOWN"; then
    # cycle selection
    idx=$(( (idx + 1) % 3 ))
    case $idx in
      0) sel="rust" ;;
      1) sel="go" ;;
      2) sel="both" ;;
    esac
    show_sel
    # continue waiting
  else
    # unexpected event ignore and continue
    :
  fi
done

# perform installation based on selection
install_one() {
  src="$1"
  dst="$2"
  if [ ! -f "$src" ]; then
    ui_print "- !! Source missing: $src"
    return 1
  fi
  cp -f "$src" "$dst" || { ui_print "!! Failed to copy $src -> $dst"; return 1; }
  chmod 0755 "$dst" || ui_print "!! chmod failed on $dst"
  chown 0:0 "$dst" 2>/dev/null || true
  ui_print "- Installed: $dst"
  return 0
}

case "$sel" in
  rust)
    install_one "$BIN_RUST" "$DEST_DIR/payload_dumper" || {
      ui_print "- !! rust install failed. Aborting."
      exit 1
    }
    ;;
  go)
    install_one "$BIN_GO" "$DEST_DIR/payload_dumper" || {
      ui_print "- !! go install failed. Aborting."
      exit 1
    }
    ;;
  both)
    ok=0
    install_one "$BIN_RUST" "$DEST_DIR/payload_dumper_rust" || ok=1
    install_one "$BIN_GO" "$DEST_DIR/payload_dumper_go"   || ok=1
    if [ "$ok" -ne 0 ]; then
      ui_print "- !! one or more installs failed."
      exit 1
    fi
    ;;
  *)
    ui_print "!! Unknown selection: $sel"
    exit 1
    ;;
esac

# final perms for bin dir
chmod 0755 "$DEST_DIR" 2>/dev/null || true
rm -rf "$MODPATH/bins"
ui_print "- Done"
