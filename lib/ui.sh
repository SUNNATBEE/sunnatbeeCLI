#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034  # palitra/ikonka konstantalari — ba'zilari ataylab zaxira
#
# lib/ui.sh — Aidevix CLI dizayn tizimi (design system).
#
# Maqsad: butun interfeys BITTA joydan boshqarilsin — ranglar, ikonkalar,
# ajratgichlar, tekislash. Ilgari har funksiya o'z emoji/ramkasini yozardi;
# natijada ekran "terminal vidjetlari to'plami"ga o'xshardi. Bu fayl uchta
# qatlamni beradi:
#
#   1) IKONKALAR  — uch pog'onali: nerd (Nerd Fonts) → unicode → ascii.
#      Nerd Font yo'q bo'lsa AVTOMATIK pastki pog'onaga tushadi (ui_icons_detect).
#   2) RANGLAR    — SEMANTIK tokenlar (natija bo'yicha, ko'z bo'yicha emas):
#        yashil = muvaffaqiyat · sariq = ogohlantirish · qizil = xato
#        ko'k   = ma'lumot     · siyoh = AI            · kulrang = ikkilamchi
#      256-rangli terminalda muloyim tonlar, 16-rangda standart ANSI.
#   3) LAYOUT     — ui_vislen/ui_pad/ui_trunc (ANSI'ni hisobga oladi),
#      ui_rule, ui_kv, ui_notice, ui_header, ui_footer, ui_statusbar.
#
# Konventsiya: hamma narsa STDERR'ga yoziladi (stdout — qaytariladigan qiymat).
# Tezlik: klavish tsiklida ishlatiladigan funksiyalar SOF BASH — fork YO'Q.

# ===========================================================================
#  1. RANG QATLAMI
# ===========================================================================

# ui_color_depth — terminal nechta rangni ko'taradi: 0 / 16 / 256.
# NO_COLOR va UI_TTY (lib/common.sh) hurmat qilinadi.
ui_color_depth() {
  if [[ "${UI_TTY:-0}" -ne 1 ]]; then printf '0'; return 0; fi
  case "${COLORTERM:-}" in
    truecolor|24bit) printf '256'; return 0 ;;
  esac
  case "${TERM:-}" in
    *256color*|*-direct*|alacritty|wezterm|kitty*|xterm-ghostty) printf '256'; return 0 ;;
    dumb)                                                        printf '0';   return 0 ;;
  esac
  # Windows Terminal / ConEmu / VS Code — 256 (va undan ko'p) ni ko'taradi.
  if [[ -n "${WT_SESSION:-}" || -n "${ConEmuANSI:-}" || -n "${TERM_PROGRAM:-}" ]]; then
    printf '256'; return 0
  fi
  printf '16'
}

UI_DEPTH="$(ui_color_depth)"

# Semantik palitra. Kod HECH QACHON to'g'ridan-to'g'ri ANSI yozmasin —
# faqat shu tokenlarni ishlatsin. Shunda rang standarti bir joyda boshqariladi.
if [[ "$UI_DEPTH" == "256" ]]; then
  UI_OK=$'\033[38;5;114m'      # yumshoq yashil — muvaffaqiyat
  UI_WARN=$'\033[38;5;179m'    # amber — ogohlantirish
  UI_ERR=$'\033[38;5;174m'     # yumshoq qizil — xato
  UI_INFO=$'\033[38;5;110m'    # ko'k — ma'lumot
  UI_AI=$'\033[38;5;140m'      # siyoh — AI
  UI_MUTED=$'\033[38;5;245m'   # kulrang — ikkilamchi matn
  UI_FAINT=$'\033[38;5;240m'   # juda so'nik — ramka/ajratgich
  UI_TEXT=$'\033[38;5;252m'    # asosiy matn
  UI_BRAND=$'\033[38;5;141m'   # brend urg'usi (AI siyohining yorqinrog'i)
elif [[ "$UI_DEPTH" == "16" ]]; then
  UI_OK=$'\033[32m'   UI_WARN=$'\033[33m'  UI_ERR=$'\033[31m'
  UI_INFO=$'\033[34m' UI_AI=$'\033[35m'    UI_MUTED=$'\033[90m'
  UI_FAINT=$'\033[90m' UI_TEXT=''          UI_BRAND=$'\033[35m'
else
  UI_OK='' UI_WARN='' UI_ERR='' UI_INFO='' UI_AI='' UI_MUTED=''
  UI_FAINT='' UI_TEXT='' UI_BRAND=''
fi

if [[ "$UI_DEPTH" == "0" ]]; then
  UI_R='' UI_B='' UI_D='' UI_REV=''
else
  UI_R=$'\033[0m'    # reset
  UI_B=$'\033[1m'    # bold
  UI_D=$'\033[2m'    # dim
  UI_REV=$'\033[7m'  # teskari (tanlangan qator uchun)
fi

# ===========================================================================
#  2. IKONKA QATLAMI (nerd → unicode → ascii)
# ===========================================================================
#
# Nerd Font kodlari FontAwesome/Devicons/Octicons diapazonlaridan olingan —
# ular BARCHA Nerd Font patch'larida bor (v2 va v3), shuning uchun bitta
# to'plam hamma joyda ishlaydi.

# UI_FD — chiqish oqimi: 2 (stderr, standart) yoki 1 (stdout).
# Log/menyu STDERR'ga ketadi (stdout — qaytariladigan qiymat uchun), lekin
# `--list` kabi MA'LUMOT beruvchi buyruqlar chiqishi quvurga tushishi kerak,
# shuning uchun ular UI_FD=1 qilib chaqiradi.
UI_FD=2

# `-g` SHART — qarang lib/i18n.sh dagi MSG_EN izohi: bu fayl funksiya ichidan
# ham source qilinadi, lokal bo'lib qolsa ICO indeksli massivga aylanadi va
# BARCHA ikonkalar bitta indeksga (0) yig'ilib ketadi.
declare -gA ICO=()   # `=()` — qarang lib/i18n.sh: e'lon qilib qiymat bermaslik
                     # `set -u` ostida "unbound variable" beradi.

# ui_icons_set <nerd|unicode|ascii> — ICO jadvalini to'ldiradi.
ui_icons_set() {
  local tier="$1"
  UI_ICON_TIER="$tier"
  case "$tier" in
    nerd)
      ICO=(
        [ok]=$''        [miss]=$''      [dot_on]=$''
        [dot_off]=$''   [info]=$''      [warn]=$''
        [err]=$''       [ai]=$''        [search]=$''
        [arrow]=$''     [enter]=$''     [key]=$''
        [globe]=$''     [card]=$''      [free]=$''
        [star]=$''      [fire]=$''      [last]=$''
        [term]=$''      [pkg]=$''       [link]=$''
        [down]=$''      [sync]=$''      [rocket]=$''
        [gear]=$''      [brand]=$''     [clock]=$''
        [npm]=$''       [py]=$''        [rust]=$''
        [gh]=$''        [google]=$''    [cloud]=$''
        [bullet]='·'          [sep]='│'             [line]='─'
        [updown]='↑↓'
      )
      ;;
    unicode)
      ICO=(
        [ok]='✓'   [miss]='✗'  [dot_on]='●'  [dot_off]='○'
        [info]='i' [warn]='!'  [err]='✗'     [ai]='◆'
        [search]='›' [arrow]='▸' [enter]='⏎' [key]='▪'
        [globe]='◇' [card]='▫'  [free]='◦'   [star]='★'
        [fire]='▲' [last]='↩'   [term]='▸'   [pkg]='▪'
        [link]='↗' [down]='↓'   [sync]='↻'   [rocket]='▸'
        [gear]='⚙' [brand]='◆'  [clock]='◷'
        [npm]='▪'  [py]='▪'     [rust]='▪'   [gh]='▪'
        [google]='▪' [cloud]='▪' [bullet]='·'
        [sep]='│'  [line]='─'  [updown]='↑↓'
      )
      ;;
    *)  # ascii — LANG=C, eski konsollar, log fayllar
      ICO=(
        [ok]='+'   [miss]='x'  [dot_on]='*'  [dot_off]='o'
        [info]='i' [warn]='!'  [err]='x'     [ai]='#'
        [search]='>' [arrow]='>' [enter]='<-' [key]='k'
        [globe]='w' [card]='$'  [free]='f'   [star]='*'
        [fire]='^' [last]='<'   [term]='>'   [pkg]='#'
        [link]='@' [down]='v'   [sync]='~'   [rocket]='>'
        [gear]='%' [brand]='#'  [clock]='t'
        [npm]='#'  [py]='#'     [rust]='#'   [gh]='#'
        [google]='#' [cloud]='#' [bullet]='-'
        [sep]='|'  [line]='-'  [updown]='^v'
      )
      UI_ICON_TIER="ascii"
      ;;
  esac
}

# ui_icons_probe_nerd — tizimda Nerd Font o'rnatilganini ANIQLAYDI (0 = bor).
# Uch platforma, uchta arzon usul. Natija keshlanadi (qarang ui_icons_detect) —
# bu tekshiruv HAR ishga tushishda emas, faqat kesh bo'sh bo'lganda bajariladi.
ui_icons_probe_nerd() {
  # 1) fontconfig (Linux, ko'p macOS o'rnatishlari) — eng ishonchli.
  if command -v fc-list >/dev/null 2>&1; then
    fc-list : family 2>/dev/null | grep -qi 'nerd font' && return 0
    return 1
  fi
  case "$(uname -s 2>/dev/null || echo unknown)" in
    Darwin*)
      # macOS: foydalanuvchi va tizim shrift papkalari. Glob bilan — `ls | grep`
      # ikki fork ochardi va g'alati nomli fayllarda yanglishardi (SC2010).
      local f
      for f in "$HOME/Library/Fonts"/*[Nn][Ee][Rr][Dd]* /Library/Fonts/*[Nn][Ee][Rr][Dd]*; do
        [[ -e "$f" ]] && return 0
      done
      return 1
      ;;
    MINGW*|MSYS*|CYGWIN*)
      # Windows: ro'yxatga olingan shriftlar reyestrda. `reg` Git Bash'da bor.
      if command -v reg >/dev/null 2>&1; then
        reg query 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' 2>/dev/null \
          | grep -qi 'nerd font' && return 0
      fi
      return 1
      ;;
  esac
  return 1
}

# ui_icons_detect — qaysi pog'onadan foydalanishni hal qiladi.
# Tartib (birinchi javob bergani):
#   1) AIDEVIX_ICONS=nerd|unicode|ascii  — aniq majburlash
#   2) saqlangan tanlov ($AIDEVIX_STATE_DIR/icons — `aidevix --icons`)
#   3) UTF-8 yo'q (LANG=C) yoki rang o'chiq → ascii
#   4) keshlangan probe natijasi
#   5) yangi probe (sekin bo'lishi mumkin — natija keshlanadi)
ui_icons_detect() {
  local state="${AIDEVIX_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/ai-cli}"
  local pref="$state/icons" cache="$state/icons_cache" tier=""

  case "${AIDEVIX_ICONS:-}" in
    nerd|unicode|ascii) ui_icons_set "$AIDEVIX_ICONS"; return 0 ;;
    auto) : ;;                                   # majburiy qayta aniqlash
    '')   [[ -r "$pref" ]] && read -r tier <"$pref" 2>/dev/null || true ;;
  esac
  case "$tier" in
    nerd|unicode|ascii) ui_icons_set "$tier"; return 0 ;;
  esac

  # UTF-8 bo'lmagan muhitda box-drawing ham buziladi — to'g'ridan-to'g'ri ascii.
  if [[ "${UI_UTF8:-1}" -ne 1 ]]; then ui_icons_set ascii; return 0; fi

  if [[ "${AIDEVIX_ICONS:-}" != "auto" && -r "$cache" ]]; then
    read -r tier <"$cache" 2>/dev/null || true
    case "$tier" in nerd|unicode) ui_icons_set "$tier"; return 0 ;; esac
  fi

  if ui_icons_probe_nerd; then tier="nerd"; else tier="unicode"; fi
  mkdir -p "$state" 2>/dev/null && printf '%s\n' "$tier" >"$cache" 2>/dev/null || true
  ui_icons_set "$tier"
}

# i <kalit> — ikonkani QAYTARADI (chop etmaydi). Noma'lum kalit — bo'sh satr.
i() { printf '%s' "${ICO[$1]:-}"; }

# ===========================================================================
#  3. O'LCHOV VA TEKISLASH (ANSI'ni hisobga oladi)
# ===========================================================================

# ui_strip <satr> — ANSI ketma-ketliklarini olib tashlab QAYTARADI.
# Sof bash pattern-almashtirish (fork yo'q, sed'dan ~100× tez).
ui_strip() {
  local s="$1" pre rest params
  while [[ "$s" == *$'\033['* ]]; do
    pre="${s%%$'\033['*}"
    rest="${s#*$'\033['}"
    params="${rest%%[a-zA-Z]*}"
    # Yakuniy harf topilmasa (buzuq ketma-ketlik) — abadiy tsikldan qochamiz.
    [[ "$params" == "$rest" ]] && { s="$pre"; break; }
    s="$pre${rest:${#params}+1}"
  done
  printf '%s' "$s"
}

# --- FORK'SIZ variantlar (-v) ---------------------------------------------
# `$(ui_pad ...)` — buyruq-almashtirish, ya'ni FORK. Menyuning klavish tsikli
# har bosishda o'nlab shunday chaqiruv qilsa, MSYS/Windows'da har fork
# ~50-150 ms turadi va menyu "qotib qoladi" (v1.5–v1.7 dagi mashhur shikoyat).
# Shuning uchun tsiklda ishlatiladigan hamma yordamchining `_v` (variable)
# varianti bor: natijani STDOUT'ga emas, `printf -v` bilan O'ZGARUVCHIGA
# yozadi — funksiya chaqiruvi fork QILMAYDI.
#
#   ui_pad_v out "$s" 20   →  $out ichida natija

# --- Emoji tozalash -------------------------------------------------------
# Loyihada ishlatilgan emoji to'plami. Ular config'da va i18n KALITLARIDA
# ataylab saqlanadi (foydalanuvchi configlari va tarjimalar bilan moslik
# uchun), lekin INTERFEYSGA chiqmaydi — chizishdan oldin shu yerda olinadi.
# Bitta bracket-ifoda = BIR o'tish (48 ta alohida almashtirish o'rniga).
UI_EMOJI='🆓🔑🌐💳🧠⚡✨🐙⭐🔥🚀💬💡📦📊🔄🔁🔐🔒🚫🛠🛡🤖🤝🎯🐉🐝👉💅💻🕒🗨🗺🙌🦘🦙🦢🧩🧰🪄🟢ℹ↩▶⚠❌❓➕'

# NOM ORQALI QAYTARUVCHI FUNKSIYALAR — `__` PREFIKSI QOIDASI
# ---------------------------------------------------------------------------
# `printf -v "$__v"` chaqiruvchi bergan NOMGA yozadi. Agar funksiya ichidagi
# `local` o'zgaruvchi nomi o'sha nom bilan MOS TUSHSA, natija chaqiruvchiga
# yetib bormaydi — funksiya o'z lokalini yozib, uni qaytishda yo'q qiladi.
# (Aynan shu sabab `trim()` yordamchisi jimgina ishlamay turgan edi: u
# `trim_v s "$s"` deb chaqirardi, `trim_v` ning o'zida esa `local s` bor edi.)
# Shuning uchun bu yerdagi HAMMA ichki lokal `__` bilan boshlanadi.

# ui_deemoji_v <var> <satr> — emoji va ular qoldirgan ortiqcha bo'shliqlarni
# olib tashlaydi. Sof bash, fork yo'q.
ui_deemoji_v() {
  local __v="$1" __src="$2"
  # Emoji yo'q bo'lsa — satrga UMUMAN tegmaymiz (otstup/tekislash saqlanadi).
  local __s="${__src//[$UI_EMOJI]/}"
  __s="${__s//$'️'/}"                 # variation selector-16
  if [[ "$__s" == "$__src" ]]; then printf -v "$__v" '%s' "$__src"; return 0; fi
  # Emoji olib tashlandi. ASL satr boshidagi otstup saqlanadi (notice ichida
  # kod/buyruq qatorlari otstup bilan ajratiladi), EMOJI QOLDIRGAN bo'shliq esa
  # olinadi — "🧠 Izoh" → "Izoh", "  🔑 Izoh" → "  Izoh".
  local __lead="${__src%%[! ]*}"
  local __rest="${__s#"${__s%%[! ]*}"}"
  while [[ "$__rest" == *"  "* ]]; do __rest="${__rest//  / }"; done
  while [[ "$__rest" == *" " ]];    do __rest="${__rest% }"; done
  [[ -z "$__rest" ]] && __lead=""     # butun satr emoji edi → bo'sh qator
  printf -v "$__v" '%s%s' "$__lead" "$__rest"
}

# ui_strip_v <var> <satr>
ui_strip_v() {
  local __v="$1" __s="$2" __pre __rest __params
  while [[ "$__s" == *$'\033['* ]]; do
    __pre="${__s%%$'\033['*}"
    __rest="${__s#*$'\033['}"
    __params="${__rest%%[a-zA-Z]*}"
    [[ "$__params" == "$__rest" ]] && { __s="$__pre"; break; }
    __s="$__pre${__rest:${#__params}+1}"
  done
  printf -v "$__v" '%s' "$__s"
}

# ui_vislen_v <var> <satr>
ui_vislen_v() {
  local __p; ui_strip_v __p "$2"
  printf -v "$1" '%s' "${#__p}"
}

# ui_pad_v <var> <satr> <eni>
ui_pad_v() {
  local __v="$1" __s="$2" __w="$3" __p __n
  ui_strip_v __p "$__s"
  __n=$(( __w - ${#__p} )); (( __n < 0 )) && __n=0
  printf -v "$__v" '%s%*s' "$__s" "$__n" ''
}

# ui_trunc_v <var> <satr> <eni> — RANGSIZ satrni qisqartiradi.
ui_trunc_v() {
  local __v="$1" __s="$2" __w="$3"
  if (( __w < 1 )); then printf -v "$__v" '%s' ''; return 0; fi
  if (( ${#__s} <= __w )); then printf -v "$__v" '%s' "$__s"; return 0; fi
  if [[ "${UI_ICON_TIER:-unicode}" == "ascii" ]]; then
    (( __w < 2 )) && __w=2
    printf -v "$__v" '%s..' "${__s:0:__w-2}"
  else
    printf -v "$__v" '%s…' "${__s:0:__w-1}"
  fi
}

# ui_vislen <satr> — ko'rinadigan uzunlik (ANSI'siz belgilar soni).
# ESLATMA: UTF-8 locale'da ${#s} BELGILARNI sanaydi (baytlarni emas), shuning
# uchun box-drawing/ikonkalar to'g'ri hisoblanadi. Ikki-ustunli belgilar (CJK,
# emoji) UI matnlarimizda ATAYLAB ishlatilmaydi — emoji parse bosqichida
# olib tashlanadi (qarang ai-selector.sh: parse_agents → ui_deemoji_v).
ui_vislen() { local p; p="$(ui_strip "$1")"; printf '%s' "${#p}"; }

# ui_pad <satr> <eni> — o'ngdan bo'sh joy bilan to'ldirib QAYTARADI.
# Rangli satrlar uchun to'g'ri ishlaydi (ANSI hisobga olinmaydi).
ui_pad() {
  local s="$1" w="$2" n p
  p="$(ui_strip "$s")"; n=$(( w - ${#p} ))
  (( n < 0 )) && n=0
  printf '%s%*s' "$s" "$n" ''
}

# ui_trunc <satr> <eni> — RANGSIZ satrni kerak bo'lsa qisqartiradi (… bilan).
ui_trunc() {
  local s="$1" w="$2"
  (( w < 1 )) && { printf ''; return 0; }
  if (( ${#s} <= w )); then printf '%s' "$s"; return 0; fi
  if [[ "${UI_ICON_TIER:-unicode}" == "ascii" ]]; then
    printf '%s..' "${s:0:$(( w - 2 < 0 ? 0 : w - 2 ))}"
  else
    printf '%s…' "${s:0:$(( w - 1 ))}"
  fi
}

# ui_width — terminal eni (ustun). tput bir marta chaqiriladi va keshlanadi.
UI_COLS=""
ui_width() {
  if [[ -z "$UI_COLS" ]]; then
    UI_COLS="${COLUMNS:-}"
    [[ "$UI_COLS" =~ ^[0-9]+$ ]] || UI_COLS="$(tput cols 2>/dev/null || echo 80)"
    [[ "$UI_COLS" =~ ^[0-9]+$ ]] || UI_COLS=80
    (( UI_COLS < 40 )) && UI_COLS=40
    (( UI_COLS > 200 )) && UI_COLS=200
  fi
  printf '%s' "$UI_COLS"
}

# ui_rule [eni] — nozik gorizontal ajratgich (satr QAYTARADI).
# Ilgari '━' (og'ir) ishlatilardi — endi '─' (yengil): shovqin kamayadi.
ui_rule() {
  local w="${1:-}" ch s='' k
  [[ -n "$w" ]] || w="$(ui_width)"
  ch="${ICO[line]:--}"
  for (( k = 0; k < w; k++ )); do s+="$ch"; done
  printf '%s%s%s' "$UI_FAINT" "$s" "$UI_R"
}

# ===========================================================================
#  4. TAKRORLANUVCHI BLOKLAR
# ===========================================================================

# ui_kv <kalit> <qiymat> [kalit-eni] — "kalit  qiymat" juftligi (satr QAYTARADI).
# Kalit — so'nik va tekislangan; qiymat — asosiy rang. Butun interfeysdagi
# tafsilot qatorlari SHU funksiyadan chiqadi (bir xil tekislash kafolati).
ui_kv() {
  local k="$1" v="$2" kw="${3:-9}"
  printf '%s%-*s%s %s' "$UI_MUTED" "$kw" "$k" "$UI_R" "$v"
}
# ui_kv_v <var> <kalit> <qiymat> [kalit-eni] — fork'siz variant (qarang yuqorida).
ui_kv_v() {
  local __v="$1" __k="$2" __val="$3" __kw="${4:-9}"
  printf -v "$__v" '%s%-*s%s %s' "$UI_MUTED" "$__kw" "$__k" "$UI_R" "$__val"
}

# ui_badge <holat> [matn] — kichik holat belgisi: ok / warn / err / info / ai.
ui_badge() {
  local kind="$1" text="${2:-}" c ic
  case "$kind" in
    ok)   c="$UI_OK";   ic="${ICO[dot_on]}"  ;;
    warn) c="$UI_WARN"; ic="${ICO[warn]}"    ;;
    err)  c="$UI_ERR";  ic="${ICO[dot_off]}" ;;
    ai)   c="$UI_AI";   ic="${ICO[ai]}"      ;;
    *)    c="$UI_INFO"; ic="${ICO[dot_on]}"  ;;
  esac
  if [[ -n "$text" ]]; then printf '%s%s %s%s' "$c" "$ic" "$text" "$UI_R"
  else                      printf '%s%s%s'    "$c" "$ic" "$UI_R"; fi
}

# ui_header [o'ng-tomon-matni] — KOMPAKT brend sarlavhasi (bir qator + chiziq).
# Katta ASCII logo faqat ILK ishga tushishda ko'rsatiladi (qarang common.sh:
# banner) — keyin har safar shu ixcham sarlavha chiqadi.
ui_header() {
  local right="${1:-}" w lw
  w="$(ui_width)"
  local left="  ${UI_BRAND}${UI_B}${ICO[brand]} Aidevix${UI_R}"
  if [[ -n "$right" ]]; then
    lw="$(ui_vislen "$left")"
    local rw; rw="$(ui_vislen "$right")"
    local gap=$(( w - lw - rw - 2 )); (( gap < 1 )) && gap=1
    printf '%s%*s%s\n' "$left" "$gap" '' "$right" >&"$UI_FD"
  else
    printf '%s\n' "$left" >&"$UI_FD"
  fi
  printf '  %s\n' "$(ui_rule $(( w - 4 )))" >&"$UI_FD"
}

# ui_notice <level> <sarlavha> [qator...] — panel() ning vorisi.
# Farqi: qalin sariq ramka o'rniga BITTA chap chiziq (vertikal aksent) +
# semantik rang. Vizual shovqin ~60% kam, ma'lumot zichligi bir xil.
ui_notice() {
  local level="$1" title="$2"; shift 2
  local c ic
  case "$level" in
    ok)   c="$UI_OK";   ic="${ICO[ok]}"   ;;
    warn) c="$UI_WARN"; ic="${ICO[warn]}" ;;
    err)  c="$UI_ERR";  ic="${ICO[err]}"  ;;
    ai)   c="$UI_AI";   ic="${ICO[ai]}"   ;;
    *)    c="$UI_INFO"; ic="${ICO[info]}" ;;
  esac
  local bar="${c}${ICO[sep]}${UI_R}"
  # Sarlavha ham, qatorlar ham emoji'dan tozalanadi. Bu YAGONA choke-point:
  # 13 ta chaqiruv joyi va butun tarjima katalogi tegilmagan holda interfeys
  # emoji'siz bo'ladi (ikonka pog'onasi esa semantik belgini o'zi beradi).
  local dt; ui_deemoji_v dt "$title"
  printf '\n  %s%s %s%s%s\n' "$c" "$ic" "$UI_B" "$dt" "$UI_R" >&"$UI_FD"
  local line dl
  for line in "$@"; do
    ui_deemoji_v dl "$line"
    if [[ -z "$dl" ]]; then printf '  %s\n' "$bar" >&"$UI_FD"
    else                    printf '  %s %s\n' "$bar" "$dl" >&"$UI_FD"; fi
  done
  printf '\n' >&"$UI_FD"
}

# ui_footer <juft...> — pastki klavish yo'riqnomasi.
# Har juft: "<klavisha>=<amal>". Klavisha yorqin, amal so'nik — Warp/LazyGit
# uslubi: ko'z avval klavishani, keyin izohni ko'radi.
ui_footer() {
  local s; ui_footer_str_v s "$@"
  printf '%s\n' "$s" >&"$UI_FD"
}

# ui_footer_str_v <var> <juft...> — footer satrini O'ZGARUVCHIGA yozadi
# (fork'siz). Menyu ramkasi uni massivga qo'shadi, chop etmaydi.
# Status bar kabi, ekranga sig'magan juftlar OXIRIDAN tashlanadi — aks holda
# tor terminalda footer o'ralib ketardi va butun ramkani bir qatorga suradi
# (ui_width 40 ustunda pol qo'yadi; 44 belgilik footer o'sha yerda oshib ketardi).
ui_footer_str_v() {
  local __v="$1"; shift
  local __w __out="  " __pair __k __val __first=1 __vis=2 __fw
  __w="$(ui_width)"
  for __pair in "$@"; do
    __k="${__pair%%=*}"; __val="${__pair#*=}"
    ui_vislen_v __fw "$__k $__val"          # ANSI hali qo'shilmagan — sof matn
    (( __first )) || __fw=$(( __fw + 3 ))   # ajratgich (uch bo'shliq)
    (( __vis + __fw > __w - 2 )) && break
    if (( __first )); then __first=0; else __out+="   "; fi
    __out+="${UI_TEXT}${UI_B}${__k}${UI_R} ${UI_MUTED}${__val}${UI_R}"
    __vis=$(( __vis + __fw ))
  done
  printf -v "$__v" '%s' "$__out"
}

# ui_statusbar_str_v <var> <maydon...> — status bar satrini O'ZGARUVCHIGA
# yozadi. Maydonlar " │ " bilan ulanadi; ekranga sig'masa OXIRIDAN qirqiladi
# (chapdagi maydonlar muhimroq). Bo'sh maydonlar tashlab ketiladi.
ui_statusbar_str_v() {
  local __v="$1"; shift
  local __w __sep __out="" __f __first=1 __vis=0 __fw
  __w="$(ui_width)"
  __sep=" ${UI_FAINT}${ICO[sep]}${UI_R} "
  for __f in "$@"; do
    [[ -n "$__f" ]] || continue
    ui_vislen_v __fw "$__f"
    (( __vis > 0 && __vis + __fw + 3 > __w - 4 )) && break
    if (( __first )); then __first=0; else __out+="$__sep"; __vis=$(( __vis + 3 )); fi
    __out+="$__f"; __vis=$(( __vis + __fw ))
  done
  printf -v "$__v" '  %s' "$__out"
}

# ui_statusbar <maydon...> — ixcham holat qatori.
# Har maydon "belgi:matn" ko'rinishida oldindan tayyorlanadi; bu funksiya
# ularni " │ " bilan ulaydi va ekranga sig'masa OXIRIDAN qirqadi.
ui_statusbar() {
  local s; ui_statusbar_str_v s "$@"
  printf '%s\n' "$s" >&"$UI_FD"
}

# ===========================================================================
#  5. HARAKAT: LOADER VA PROGRESS
# ===========================================================================
#
# Falsafa: professional CLI'da animatsiya DIQQATNI TORTMAYDI — u faqat
# "ishlayapti" signalini beradi. Shuning uchun 3D gradient logo va sakrovchi
# "komet" o'rniga bitta nozik braille spinner + so'nik matn.

UI_SPIN_FRAMES='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
UI_SPIN_ASCII='|/-\'

# --- Animatsiya yordamchilari (banner uchun) -------------------------------
#
# ui_anim_wait <sekund> — animatsiya kadrlari orasidagi qisqa kutish.
#
# NEGA `sleep` (ya'ni FORK), loyihaning "tsiklda fork ISHLATMA" qoidasiga
# qaramay? Chunki bu tsikl KLAVISH tsikli emas: banner butun o'rnatish
# davomida BIR MARTA (ilk ishga tushishda) chiziladi va bor-yo'g'i 6 kadr.
# MSYS'da bu ~0.8 s, Linux/macOS'da ~0.35 s — talab qilingan 2 s ichida.
#
# `read -t` builtin'i bilan fork'siz variant SINALDI va RAD ETILDI:
# `exec {fd}<> <(:)` MSYS'da redirect xatosi berardi, noninteraktiv bash esa
# `exec` redirecti muvaffaqiyatsiz bo'lsa BUTUN SKRIPTNI to'xtatadi — ya'ni
# `|| zaxira` ham ishlamasdi (banner birinchi qatordan keyin jim uzilardi).
#
# Kasr sonni ko'tarmaydigan minimal `sleep` (masalan ba'zi busybox) bo'lsa —
# kutishni UMUMAN o'tkazib yuboramiz (1 soniya kutib qolmaslik uchun).
UI_ANIM_SLEEP=""
ui_anim_wait() {
  if [[ -z "$UI_ANIM_SLEEP" ]]; then
    if command -v sleep >/dev/null 2>&1 && sleep 0.01 2>/dev/null; then
      UI_ANIM_SLEEP=1
    else
      UI_ANIM_SLEEP=0
    fi
  fi
  [[ "$UI_ANIM_SLEEP" == "1" ]] || return 0
  sleep "$1" 2>/dev/null || true
}

# UI_GRAD — brend gradienti: moviy (cyan) → siyoh (magenta) → ko'k (blue).
# 256-rangli palitradan tanlangan; faqat UI_DEPTH=256 bo'lganda ishlatiladi.
UI_GRAD=(51 45 39 75 111 147 183 201 165 129 93 57 33)

# ui_gradient_line <satr> <qator-indeksi> — satrni gradient bilan chizadi.
# Rang USTUN bo'yicha o'zgaradi, qator indeksi esa boshlanish nuqtasini
# suradi — shunda logo bo'ylab diagonal "oqim" hosil bo'ladi.
# Sof bash: satr avval o'zgaruvchiga yig'iladi, keyin BIR marta chop etiladi.
ui_gradient_line() {
  local __line="$1" __row="${2:-0}" __n=${#UI_GRAD[@]} __out='' __k __ch __c
  for (( __k = 0; __k < ${#__line}; __k++ )); do
    __ch="${__line:__k:1}"
    if [[ "$__ch" == ' ' ]]; then __out+=' '; continue; fi
    __c=${UI_GRAD[$(( (__k + __row * 2) % __n ))]}
    __out+=$'\033[1;38;5;'"${__c}"'m'"$__ch"
  done
  printf '%s%s\n' "$__out" "$UI_R" >&"$UI_FD"
}

# ui_frames — joriy pog'onaga mos spinner ramkalarini qaytaradi.
ui_frames() {
  if [[ "${UI_ICON_TIER:-unicode}" == "ascii" || "${UI_UTF8:-1}" -ne 1 ]]; then
    printf '%s' "$UI_SPIN_ASCII"
  else
    printf '%s' "$UI_SPIN_FRAMES"
  fi
}

# ui_bar <foiz> <eni> — aniq (determinate) progress bar satrini QAYTARADI.
# To'ldirilgan qism — brend rangi, qolgani — so'nik. Foiz 0..100.
ui_bar() {
  local pct="$1" w="${2:-24}" fill k on off done_s='' rest=''
  (( pct < 0 )) && pct=0
  (( pct > 100 )) && pct=100
  fill=$(( pct * w / 100 ))
  if [[ "${UI_ICON_TIER:-unicode}" == "ascii" ]]; then on='='; off='.'
  else                                                 on='━'; off='━'; fi
  for (( k = 0; k < fill; k++ )); do done_s+="$on"; done
  for (( k = fill; k < w; k++ )); do rest+="$off"; done
  printf '%s%s%s%s%s' "$UI_BRAND" "$done_s" "$UI_FAINT" "$rest" "$UI_R"
}
