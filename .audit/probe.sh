#!/usr/bin/env bash
# probe.sh — Windows konsolida ESC-ketma-ketlik o'qish diagnostikasi.
# Har bir qadam natijasini log fayliga yozadi (SendKeys bilan boshqariladi).
LOG="${1:-probe.log}"
exec 3>"$LOG"
log(){ printf '%s\n' "$*" >&3; }
log "uname=$(uname -s) bash=$BASH_VERSION TERM=${TERM:-} EPOCH=${EPOCHREALTIME:-YOQ}"
if ! { : </dev/tty; } 2>/dev/null; then log "TTY-READ-OCHILMADI"; exit 0; fi
saved="$(stty -g </dev/tty 2>/dev/null)"; log "sttyg_rc=$?"
stty -echo -icanon -icrnl min 1 time 0 </dev/tty 2>>"$LOG"; log "raw_rc=$?"
log "READY-PRESS-DOWN"
IFS= read -rsn1 k </dev/tty; log "key1=$(printf '%q' "$k")"
t0="${EPOCHREALTIME/[.,]/}"
stty min 0 time 4 </dev/tty 2>>"$LOG"; log "min0_rc=$?"
b="$(dd bs=1 count=1 2>/dev/null </dev/tty)"
t1="${EPOCHREALTIME/[.,]/}"
log "vtime_b=$(printf '%q' "$b") el=$(( t1 - t0 ))"
stty min 1 time 0 </dev/tty 2>>"$LOG"
if [ -z "$b" ]; then
  t0="${EPOCHREALTIME/[.,]/}"
  b2=""; IFS= read -rsn1 -t 1 b2 </dev/tty; rc=$?
  t1="${EPOCHREALTIME/[.,]/}"
  log "readt_b2=$(printf '%q' "$b2") rc=$rc el=$(( t1 - t0 ))"
  if [ -z "$b2" ]; then
    b3="$(dd bs=1 count=1 2>/dev/null </dev/tty)"
    log "block_b3=$(printf '%q' "$b3")"
  fi
fi
stty min 0 time 4 </dev/tty 2>/dev/null
rest="$(dd bs=16 count=1 2>/dev/null </dev/tty)"
log "rest=$(printf '%q' "$rest")"
stty "$saved" </dev/tty 2>/dev/null
log DONE
