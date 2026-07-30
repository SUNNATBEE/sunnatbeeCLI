#!/usr/bin/env bash
# shellcheck shell=bash
#
# lib/stats.sh — Aidevix CLI uchun Global statistika (opt-in) moduli.
#

# global_stats_enabled — global statistika yoqilganmi? (0 = ha, 1 = yo'q)
# Tartib: AIDEVIX_GLOBAL_STATS env (1/0) ustun; aks holda opt-in fayli; std o'chiq.
global_stats_enabled() {
  case "${AIDEVIX_GLOBAL_STATS:-}" in
    1|on|true|yes) return 0 ;;
    0|off|false|no) return 1 ;;
  esac
  [[ -r "$GLOBAL_OPTIN_FILE" ]] && [[ "$(cat "$GLOBAL_OPTIN_FILE" 2>/dev/null)" == "on" ]]
}

# set_global_stats <on|off> — opt-in holatini saqlaydi.
set_global_stats() {
  mkdir -p "$STATE_DIR" 2>/dev/null || return 1
  atomic_write "$GLOBAL_OPTIN_FILE" "$1" || return 1
}

# stats_cmd [on|off] — `aidevix --stats` buyrug'i: holatni ko'rsatadi yoki o'zgartiradi.
stats_cmd() {
  local arg="${1:-}"
  case "$arg" in
    on)
      set_global_stats on
      ui_notice ok "$(t '📊 Global statistika YOQILDI')" \
        "$(t 'Rahmat! Endi agent ishga tushganda FAQAT quyidagi yuboriladi:')" \
        "$(t '    • agent nomi (masalan "Claude Code")')" \
        "$(t '    • hodisa turi (install yoki launch)')" \
        "" \
        "$(t "❌ IP, foydalanuvchi nomi, kalit yoki boshqa shaxsiy ma'lumot YO'Q.")" \
        "$(t "Bu hammaga \"qaysi CLI eng mashhur\"ligini ko'rsatishga yordam beradi.")" \
        "" \
        "$(t 'O'\''chirish: aidevix --stats off')"
      ;;
    off)
      set_global_stats off
      log_success "$(t 'Global statistika o'\''chirildi. Endi hech narsa yuborilmaydi.')"
      ;;
    ''|status)
      local state; state="$(t "o'chiq (opt-in)")"
      global_stats_enabled && state="$(t 'yoqilgan')"
      ui_notice info "$(t '📊 Global statistika — holat: %s' "$state")" \
        "$(t 'Server:   %s' "$AIDEVIX_STATS_URL")" \
        "$(t "Yuboriladi (yoqilganda): agent nomi + hodisa turi (shaxsiy ma'lumotsiz)")" \
        "" \
        "$(t 'Yoqish:   aidevix --stats on')" \
        "$(t 'O'\''chirish: aidevix --stats off')"
      ;;
    *)
      die 2 "$(t "Noma'lum: 'aidevix --stats %s'. Foydalanish: aidevix --stats [on|off]" "$arg")"
      ;;
  esac
}

# report_usage_global <nom> <install|launch> — hodisani serverga FONDA yuboradi.
# Eng-yaxshi-harakat: jim, qisqa timeout, hech qachon bloklamaydi/xato bermaydi.
report_usage_global() {
  local name="$1" type="${2:-launch}"
  global_stats_enabled || return 0
  [[ -n "${CI:-}" ]] && return 0
  command -v curl >/dev/null 2>&1 || return 0
  [[ -n "$name" ]] || return 0
  # Agent nomidagi " va \ ni JSON uchun ekranlaymiz (config nomlari odatda toza).
  local esc; esc="$(printf '%s' "$name" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"
  # ( ... & ) — fonda detach: exec'dan keyin ham mustaqil tugaydi.
  ( curl -fsS -m 3 -X POST "$AIDEVIX_STATS_URL/v1/events" \
      -H 'content-type: application/json' \
      --data "{\"agent\":\"$esc\",\"type\":\"$type\"}" >/dev/null 2>&1 & ) 2>/dev/null
  return 0
}

# fetch_global_stats — /v1/stats keshini FONDA yangilaydi (throttled).
# Menyu keshni o'qiydi (darrov); bu funksiya keyingi safar uchun yangilaydi.
fetch_global_stats() {
  global_stats_enabled || return 0
  [[ -n "${CI:-}" ]] && return 0
  command -v curl >/dev/null 2>&1 || return 0
  local now interval last
  interval="${AIDEVIX_STATS_TTL:-10800}"
  now="$(date +%s 2>/dev/null || echo 0)"
  if [[ -r "$GLOBAL_STAMP" && -r "$GLOBAL_CACHE" ]]; then
    last="$(cat "$GLOBAL_STAMP" 2>/dev/null || echo 0)"; [[ "$last" =~ ^[0-9]+$ ]] || last=0
    (( now - last < interval )) && return 0
  fi
  mkdir -p "$STATE_DIR" 2>/dev/null || return 0
  ( curl -fsS -m 5 "$AIDEVIX_STATS_URL/v1/stats" -o "$GLOBAL_CACHE.tmp" 2>/dev/null \
      && mv -f "$GLOBAL_CACHE.tmp" "$GLOBAL_CACHE" 2>/dev/null \
      && printf '%s\n' "$now" >"$GLOBAL_STAMP" 2>/dev/null \
      || rm -f "$GLOBAL_CACHE.tmp" 2>/dev/null ) >/dev/null 2>&1 &
  return 0
}

# global_install_tsv — kesh JSON'idagi "install" reytingini "nom<TAB>rank<TAB>son"
# qatorlariga aylantiradi (rank = ro'yxatdagi tartib, server kamayish bo'yicha beradi).
global_install_tsv() {
  [[ -r "$GLOBAL_CACHE" ]] || return 0
  awk '
    {
      i = index($0, "\"install\":[")
      if (i == 0) next
      rest = substr($0, i + 11)          # "install":[ dan keyingi qism
      j = index(rest, "]")
      if (j == 0) next
      arr = substr(rest, 1, j - 1)
      n = 0
      while (match(arr, /"agent":"[^"]*","count":[0-9]+/)) {
        obj = substr(arr, RSTART, RLENGTH)
        arr = substr(arr, RSTART + RLENGTH)
        a = obj; sub(/^"agent":"/, "", a); sub(/","count":[0-9]+$/, "", a)
        c = obj; sub(/^.*"count":/, "", c)
        n++
        printf "%s\t%d\t%d\n", a, n, c
      }
    }
  ' "$GLOBAL_CACHE" 2>/dev/null || true
}

# maybe_global_hint — global statistika hali sozlanmagan bo'lsa, BIR MARTA
# yengil eslatma ko'rsatadi (majburlamaydi — opt-in). Faqat interaktiv holatda.
maybe_global_hint() {
  [[ -n "${AIDEVIX_GLOBAL_STATS:-}" ]] && return 0   # env orqali boshqarilmoqda
  global_stats_enabled && return 0                   # allaqachon yoqilgan
  [[ -e "$GLOBAL_OPTIN_FILE" ]] && return 0          # foydalanuvchi tanlagan (on/off)
  [[ -e "$GLOBAL_HINT_FILE" ]] && return 0           # eslatma ko'rsatilgan
  [[ -n "${CI:-}" ]] && return 0
  mkdir -p "$STATE_DIR" 2>/dev/null || return 0
  : >"$GLOBAL_HINT_FILE" 2>/dev/null || true
  ui_notice info "$(t '💡 Maslahat — global statistika (ixtiyoriy)')" \
    "$(t 'Qaysi AI CLI dunyoda eng mashhurligini menyuda ko'\''rmoqchimisiz?')" \
    "    aidevix --stats on" \
    "$(t "Yoqsangiz FAQAT agent nomi + hodisa turi yuboriladi (shaxsiy ma'lumotsiz).")" \
    "$(t 'Standart — o'\''CHIQ. Hozir hech narsa o'\''zgarmaydi; bu shunchaki eslatma.')"
}
