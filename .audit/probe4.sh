#!/usr/bin/env bash
# probe4.sh — CHUNK semantikasi: bitta read() (dd bs=16 count=1) strelkaning
# BARCHA baytlarini (\033[B) birga qaytaradimi?
LOG="${1:-probe4.log}"
exec 3>"$LOG"
log(){ printf '%s\n' "$*" >&3; }
stty -echo -icanon -icrnl min 1 time 0 </dev/tty 2>>"$LOG"
log "READY"
c1="$(dd bs=16 count=1 2>/dev/null </dev/tty)"; log "chunk1=$(printf '%q' "$c1")"
c2="$(dd bs=16 count=1 2>/dev/null </dev/tty)"; log "chunk2=$(printf '%q' "$c2")"
log DONE
