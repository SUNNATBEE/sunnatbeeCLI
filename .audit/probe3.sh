#!/usr/bin/env bash
# probe3.sh — YANGI algoritm semantikasi: raw bir marta, keyin faqat bloklovchi
# dd'lar. DOWN bosilganda b1=ESC, b2='[', b3='B' kelishini tekshiradi.
LOG="${1:-probe3.log}"
exec 3>"$LOG"
log(){ printf '%s\n' "$*" >&3; }
stty -echo -icanon -icrnl min 1 time 0 </dev/tty 2>>"$LOG"
log "READY"
t0="${EPOCHREALTIME/[.,]/}"
b1="$(dd bs=1 count=1 2>/dev/null </dev/tty)"; log "b1=$(printf '%q' "$b1")"
b2="$(dd bs=1 count=1 2>/dev/null </dev/tty)"
t1="${EPOCHREALTIME/[.,]/}"
log "b2=$(printf '%q' "$b2") el=$(( t1 - t0 ))"
b3="$(dd bs=1 count=1 2>/dev/null </dev/tty)"; log "b3=$(printf '%q' "$b3")"
# Bonus: keyingi klavishni KATTA bs bilan bitta read'da olish (chunk semantikasi).
c="$(dd bs=16 count=1 2>/dev/null </dev/tty)"; log "chunk=$(printf '%q' "$c")"
log DONE
