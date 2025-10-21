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
idx=0
sel="rust"

# show current selection
show_sel() {
  case "$sel" in
    rust) ui_print "- Rust" ;;
    go)   ui_print "- Go" ;;
    both) ui_print "- Both" ;;
  esac
}

timeout=60
ui_print " "
ui_print "- Press VOLUME UP to select, VOLUME DOWN to switch"
ui_print " "
show_sel

while true; do
  event=$(timeout ${timeout} getevent -lc 1 2>/dev/null)
  exitcode=$?
  
  if [ "$exitcode" -eq 124 ] || [ "$exitcode" -eq 143 ]; then
    ui_print " "
    ui_print "- No keypress detected. Defaulting to 'both'."
    sel="both"
    break
  fi

  # Only process KEY_DOWN events (value 1), ignore KEY_UP events (value 0)
  if echo "$event" | grep -q "KEY_VOLUMEUP.*DOWN"; then
    ui_print " "
    ui_print "- Confirmed!"
    break
  elif echo "$event" | grep -q "KEY_VOLUMEDOWN.*DOWN"; then
    # cycle selection
    idx=$(( (idx + 1) % 3 ))
    case $idx in
      0) sel="rust" ;;
      1) sel="go" ;;
      2) sel="both" ;;
    esac
    show_sel
  fi
done

ui_print " "

# perform installation based on selection
install_one() {
  src="$1"
  dst="$2"
  if [ ! -f "$src" ]; then
    ui_print "- !! Source missing: $src"
    return 1
  fi
  cp -f "$src" "$dst" || { ui_print "- !! Failed to copy $src -> $dst"; return 1; }
  chmod 0755 "$dst" || ui_print "- !! chmod failed on $dst"
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
    ui_print "- !! Unknown selection: $sel"
    exit 1
    ;;
esac

# final perms for bin dir
chmod 0755 "$DEST_DIR" 2>/dev/null || true
rm -rf "$MODPATH/bins"
ui_print " "
