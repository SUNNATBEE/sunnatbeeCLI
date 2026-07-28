#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034  # rang palitrasi konstantalari — ba'zilari ataylab zaxira
#
# lib/common.sh — Aidevix CLI uchun umumiy yordamchi funksiyalar.
# Bu fayl mustaqil ishga tushirilmaydi; boshqa skriptlar `source` qiladi.
#
# Mazmuni:
#   • Rang konstantalari (terminal TTY bo'lganda)
#   • Log funksiyalari: log_info / log_warn / log_error / log_success
#   • die()  — xabar chiqarib, berilgan exit-code bilan to'xtaydi
#   • require_cmd() — kerakli buyruq mavjudligini tekshiradi

# --- Ko'p tillilik (i18n) — t() va til aniqlash ---------------------------
# Yengil gettext qatlami: o'zbekcha manba = kalit, inglizcha = lib/i18n/en.sh.
__common_dir="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
if [[ -r "$__common_dir/i18n.sh" ]]; then
  # shellcheck source=i18n.sh
  source "$__common_dir/i18n.sh"
fi
unset __common_dir
# i18n yuklanmasa ham buzilmasin — t() zaxira ta'rifi (manbani qaytaradi).
if ! declare -F t >/dev/null 2>&1; then
  # shellcheck disable=SC2059  # $f — ataylab format-satr
  t() { local f="$1"; shift; if (( $# )); then printf "$f" "$@"; else printf '%s' "$f"; fi; }
fi

# --- Rang/animatsiya yoqilishini aniqlash --------------------------------
# Quyidagi tartibda hal qilinadi:
#   1) NO_COLOR o'rnatilgan bo'lsa            → o'chiq (standart hurmat)
#   2) FORCE_COLOR / CLICOLOR_FORCE bo'lsa    → MAJBURAN yoniq
#   3) stdout yoki stderr terminal (tty) bo'lsa → yoniq
#   4) Windows zamonaviy terminal belgilari   → yoniq (Windows Terminal/ConEmu/ANSICON)
#   5) aks holda                               → o'chiq (faylga/quvurga yozilmoqda)
if [[ -n "${NO_COLOR:-}" ]]; then
  UI_TTY=0
elif [[ -n "${FORCE_COLOR:-}" || -n "${CLICOLOR_FORCE:-}" ]]; then
  UI_TTY=1
elif [[ -t 1 || -t 2 ]]; then
  UI_TTY=1
elif [[ -n "${WT_SESSION:-}" || -n "${ANSICON:-}" || "${ConEmuANSI:-}" == "ON" || -n "${TERM_PROGRAM:-}" ]]; then
  UI_TTY=1
else
  UI_TTY=0
fi

if [[ "$UI_TTY" -eq 1 ]]; then
  C_RESET=$'\033[0m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'
  C_MAGENTA=$'\033[35m'
  C_CYAN=$'\033[36m'
  C_GRAY=$'\033[90m'
  C_DIM=$'\033[2m'
  C_BOLD=$'\033[1m'
  # 256-rangli urg'ular (banner/gradient uchun)
  C_G1=$'\033[38;5;51m'   # och feruza
  C_G2=$'\033[38;5;45m'
  C_G3=$'\033[38;5;39m'   # ko'k
  C_G4=$'\033[38;5;201m'  # pushti
  C_TITLE=$'\033[38;5;87m'
  # AD logosi uchun cyan→ko'k→pushti gradient (6 qator)
  C_LG1=$'\033[38;5;51m'
  C_LG2=$'\033[38;5;45m'
  C_LG3=$'\033[38;5;39m'
  C_LG4=$'\033[38;5;33m'
  C_LG5=$'\033[38;5;99m'
  C_LG6=$'\033[38;5;201m'
else
  C_RESET='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_MAGENTA='' C_CYAN=''
  C_GRAY='' C_DIM='' C_BOLD='' C_G1='' C_G2='' C_G3='' C_G4='' C_TITLE=''
  C_LG1='' C_LG2='' C_LG3='' C_LG4='' C_LG5='' C_LG6=''
fi

# Animatsiya: rang yoniq bo'lsa va aniq o'chirilmagan bo'lsa.
if [[ "$UI_TTY" -eq 1 && -z "${AI_NO_ANIM:-}" && -z "${CI:-}" ]]; then AI_ANIM=1; else AI_ANIM=0; fi
# Unicode (braille/box) qo'llab-quvvatlanadimi? Noma'lum bo'lsa — ha deb hisoblaymiz.
case "${LC_ALL:-${LC_CTYPE:-${LANG:-UTF-8}}}" in
  C|POSIX|*.iso*|*ISO8859*|*latin*|*LATIN*) UI_UTF8=0 ;;
  *)                                        UI_UTF8=1 ;;
esac

# --- Dizayn tizimi (ranglar, ikonkalar, layout) ---------------------------
# UI_TTY/UI_UTF8 aniqlangandan KEYIN yuklanadi — ui.sh ularga tayanadi.
__common_ui="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/ui.sh"
if [[ -r "$__common_ui" ]]; then
  # shellcheck source=ui.sh
  source "$__common_ui"
  ui_icons_detect
fi
unset __common_ui

# --- Log funksiyalari (barchasi stderr'ga yozadi) -------------------------
# Belgilar ikonka pog'onasidan (nerd/unicode/ascii), ranglar semantik
# tokenlardan keladi — butun interfeysda bir xil "til".
log_info()    { printf '  %s%s%s %s\n' "$UI_INFO" "${ICO[info]:-i}" "$UI_R" "$*" >&2; }
log_warn()    { printf '  %s%s%s %s\n' "$UI_WARN" "${ICO[warn]:-!}" "$UI_R" "$*" >&2; }
log_error()   { printf '  %s%s%s %s\n' "$UI_ERR"  "${ICO[err]:-x}"  "$UI_R" "$*" >&2; }
log_success() { printf '  %s%s%s %s\n' "$UI_OK"   "${ICO[ok]:-+}"   "$UI_R" "$*" >&2; }
# log_step — ko'p bosqichli amallarda joriy qadam (so'nik, diqqat tortmaydi).
log_step()    { printf '  %s%s %s%s\n' "$UI_MUTED" "${ICO[bullet]:--}" "$*" "$UI_R" >&2; }

# die <exit_code> <message...>
#   Xato xabarini chiqaradi va skriptni berilgan exit-code bilan to'xtatadi.
die() {
  local code="$1"; shift
  log_error "$*"
  exit "$code"
}

# require_cmd <command> [installation_hint]
#   Buyruq PATH'da mavjudligini tekshiradi; yo'q bo'lsa die() qiladi.
require_cmd() {
  local cmd="$1"
  local hint="${2:-}"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    if [[ -n "$hint" ]]; then
      die 127 "$(t "'%s' topilmadi. O'rnatish uchun: %s" "$cmd" "$hint")"
    else
      die 127 "$(t "'%s' topilmadi. Iltimos, uni o'rnatib, qaytadan urinib ko'ring." "$cmd")"
    fi
  fi
}

# --- Sodda, tushunarli xabarlar (yangi va yosh foydalanuvchilar uchun) -----

# panel <SARLAVHA> [QATOR...]
#   Diqqatni tortadigan, ramkali xabar chiqaradi. Har bir QATOR — alohida
#   qator. Maqsad: xatoni hatto tajribasiz odam ham tushunsin.
# Endi bu — MOSLIK qobig'i: butun chizish ui_notice()ga o'tdi (lib/ui.sh).
# Eski qalin sariq ramka o'rniga bitta nozik chap aksent chizig'i ishlatiladi.
# Yangi kod TO'G'RIDAN-TO'G'RI ui_notice <level> chaqirsin — level xabarning
# ma'nosini beradi (ok/warn/err/info/ai), panel esa doim "warn" edi.
panel() {
  local title="$1"; shift
  ui_notice warn "$title" "$@"
}

# tool_hint <tool>
#   Berilgan dasturni qanday o'rnatishni ODDIY tilda tushuntiradi.
tool_hint() {
  case "$1" in
    npm|node|nodejs)
      t "Node.js kerak (npm u bilan birga keladi). https://nodejs.org saytiga kiring, katta yashil \"LTS\" tugmasini bosib yuklab oling, o'rnating va terminalni qayta oching." ;;
    python3|python|pip|pip3)
      t "Python 3 kerak. https://www.python.org/downloads saytidan yuklab oling. Windows'da o'rnatishda \"Add Python to PATH\" katagiga belgi qo'yishni unutmang." ;;
    curl)
      t "curl kerak. Ubuntu/Debian: \"sudo apt install curl\" · macOS: oldindan bor · Windows: Git Bash bilan birga keladi." ;;
    wget)
      t "wget kerak. Ubuntu/Debian: \"sudo apt install wget\"." ;;
    git)
      t "git kerak. https://git-scm.com/downloads saytidan yuklab olib o'rnating." ;;
    fzf)
      t "fzf kerak. macOS: \"brew install fzf\" · Ubuntu: \"sudo apt install fzf\" · Windows: \"winget install fzf\"." ;;
    bash)
      t "bash kerak. Windows'da Git for Windows o'rnating: https://git-scm.com/download/win" ;;
    brew)
      t "Homebrew kerak. https://brew.sh saytidagi buyruqni terminalga nusxalang." ;;
    *)
      t "'%s' nomli dastur kerak, lekin u topilmadi. Internetdan \"%s install\" deb qidirib o'rnating." "$1" "$1" ;;
  esac
}

# ===========================================================================
#  CHIROYLI UI: banner, gorizontal chiziq, spinner, animatsiyalar
#  Barchasi STDERR'ga yozadi — stdout'ni (qaytariladigan qiymatlarni) buzmaydi.
# ===========================================================================

# show_cursor — kursorni qaytaradi (spinner yoki Ctrl+C'dan keyin).
show_cursor() { [[ "${UI_TTY:-0}" -eq 1 ]] && printf '\033[?25h' >&2 || true; }

# open_url <url> — havolani standart brauzerda ochadi (platformaga qarab).
#   Eng yaxshi-harakat: xato bo'lsa ham jim qaytadi (havola baribir chop etiladi).
open_url() {
  local url="$1" os
  [[ -n "$url" ]] || return 0
  os="$(uname -s 2>/dev/null || echo unknown)"
  case "$os" in
    MINGW*|MSYS*|CYGWIN*)
      # Windows / Git Bash — explorer URL'ni standart brauzerda ochadi.
      # MSYS2_ARG_CONV_EXCL='*' — MSYS "https://" ni yo'lga aylantirmasin.
      if command -v explorer.exe >/dev/null 2>&1; then
        MSYS2_ARG_CONV_EXCL='*' explorer.exe "$url" >/dev/null 2>&1 &
      elif command -v powershell >/dev/null 2>&1; then
        powershell -NoProfile -Command "Start-Process '$url'" >/dev/null 2>&1 &
      fi
      ;;
    Darwin*)
      command -v open >/dev/null 2>&1 && open "$url" >/dev/null 2>&1 &
      ;;
    *)
      command -v xdg-open >/dev/null 2>&1 && xdg-open "$url" >/dev/null 2>&1 &
      ;;
  esac
  return 0
}

# hr [eni] — gorizontal ajratgich satrini QAYTARADI (chop etmaydi).
# Moslik qobig'i: chizish ui_rule()ga o'tdi (lib/ui.sh). Og'ir '━' o'rniga
# yengil '─' — bu vizual shovqinni sezilarli kamaytiradi.
hr() { ui_rule "${1:-46}"; }

# --- Brend sarlavhasi -----------------------------------------------------
# Falsafa: katta ASCII logo — TANISHUV uchun, har kunlik ish uchun emas.
# Shuning uchun to'liq logo FAQAT ilk ishga tushishda (yoki --version'da)
# ko'rsatiladi; keyin har safar bir qatorli ixcham sarlavha chiqadi.
# Buni BANNER_FULL=1 bilan majburlash, BANNER_FULL=0 bilan o'chirish mumkin.

# banner_full [sarlavha] [kichik-sarlavha] — to'liq brend bloki (ilk run).
banner_full() {
  local title="${1:-Aidevix}" subtitle="${2:-$(t 'barcha AI agentlar — bitta pultda')}"
  if [[ "${UI_TTY:-0}" -ne 1 ]]; then
    printf '\n  %s\n  %s\n\n' "$title" "$subtitle" >&2
    return 0
  fi
  printf '\n' >&2
  # Monogramma — endi gradientsiz va animatsiyasiz: bitta brend rangi.
  # Harfma-harf "yozilish" effekti olib tashlandi (ishga tushishni sekinlashtirardi
  # va professional CLI'larda uchramaydi).
  if [[ "${UI_UTF8:-1}" -eq 1 ]]; then
    local -a logo=(
'   █████╗ ██████╗ '
'  ██╔══██╗██╔══██╗'
'  ███████║██║  ██║'
'  ██╔══██║██║  ██║'
'  ██║  ██║██████╔╝'
'  ╚═╝  ╚═╝╚═════╝ '
    )
    local row
    for row in "${logo[@]}"; do
      printf '%s%s%s%s\n' "$UI_B" "$UI_BRAND" "$row" "$UI_R" >&2
    done
  else
    printf '%s   /\  ___ %s\n' "$UI_BRAND" "$UI_R" >&2
    printf '%s  /__\ |  |%s\n' "$UI_BRAND" "$UI_R" >&2
    printf '%s       |__|%s\n' "$UI_BRAND" "$UI_R" >&2
  fi
  printf '\n  %s%s%s   %s%s%s\n' "$UI_B" "$title" "$UI_R" "$UI_MUTED" "$subtitle" "$UI_R" >&2
  printf '  %s\n\n' "$(ui_rule 44)" >&2
}

# banner [sarlavha] [kichik-sarlavha]
#   Standart chaqiruv: ilk marta — to'liq blok, keyin — ixcham sarlavha.
#   "Ilk marta" belgisi BANNER_SEEN_FILE bilan aniqlanadi (chaqiruvchi beradi).
banner() {
  local title="${1:-Aidevix}" subtitle="${2:-}"
  local seen="${BANNER_SEEN_FILE:-}"
  local full=0
  if [[ -n "${BANNER_FULL:-}" ]]; then
    full="$BANNER_FULL"
  elif [[ -n "$seen" && ! -e "$seen" ]]; then
    full=1
    mkdir -p "$(dirname "$seen")" 2>/dev/null && : >"$seen" 2>/dev/null || true
  fi

  if (( full )); then
    banner_full "$title" "$subtitle"
    return 0
  fi
  # Ixcham rejim: bir qator brend + (bo'lsa) kontekst matni + nozik chiziq.
  if [[ "${UI_TTY:-0}" -ne 1 ]]; then
    [[ -n "$subtitle" ]] && printf '\n  %s — %s\n\n' "$title" "$subtitle" >&2 \
                         || printf '\n  %s\n\n' "$title" >&2
    return 0
  fi
  printf '\n' >&2
  if [[ -n "$subtitle" ]]; then
    ui_header "${UI_MUTED}${subtitle}${UI_R}"
  else
    ui_header
  fi
}

# SPIN_LOG — oxirgi spin_run chiqishi shu faylda saqlanadi (xatoni ko'rsatish uchun).
SPIN_LOG=""

# spin_run <xabar> <bash-buyrug'i-satri>
#   Buyruqni ishga tushiradi, yonida nozik spinner + o'tgan vaqt ko'rsatadi.
#   TTY/animatsiya bo'lmasa — oddiy bajaradi (chiqish ko'rinadi).
#   Chiqishni tugagach SPIN_LOG'ga saqlaydi. Buyruq exit-kodini qaytaradi.
#
#   DIZAYN: ilgari bu yerda 22 belgilik sakrovchi "komet" progress-bar bor edi.
#   U INDETERMINAT ishni DETERMINAT ko'rsatardi (yolg'on signal) va ekranni
#   shovqinga to'ldirardi. Endi: bitta spinner + xabar + o'tgan vaqt.
spin_run() {
  local msg="$1" cmd="$2"
  SPIN_LOG="$(mktemp)"

  if [[ "${AI_ANIM:-0}" -ne 1 ]]; then
    printf '  %s%s%s %s\n' "$UI_MUTED" "${ICO[bullet]:--}" "$UI_R" "$msg" >&2
    bash -c "$cmd" 2>&1 | tee "$SPIN_LOG" >&2
    return "${PIPESTATUS[0]}"
  fi

  local frames; frames="$(ui_frames)"
  local n=${#frames}

  bash -c "$cmd" >"$SPIN_LOG" 2>&1 &
  local pid=$! i=0 start=$SECONDS el
  printf '\033[?25l' >&2
  while kill -0 "$pid" 2>/dev/null; do
    el=$((SECONDS - start))
    printf '\r  %s%s%s %s  %s%ss%s\033[K' \
      "$UI_BRAND" "${frames:$((i % n)):1}" "$UI_R" \
      "$msg" "$UI_FAINT" "$el" "$UI_R" >&2
    i=$((i + 1))
    sleep 0.08
  done
  local rc=0; wait "$pid" || rc=$?
  printf '\033[?25h' >&2
  el=$((SECONDS - start))

  if [[ "$rc" -eq 0 ]]; then
    printf '\r  %s%s%s %s  %s%ss%s\033[K\n' \
      "$UI_OK" "${ICO[ok]:-+}" "$UI_R" "$msg" "$UI_FAINT" "$el" "$UI_R" >&2
  else
    printf '\r  %s%s%s %s  %s%ss%s\033[K\n' \
      "$UI_ERR" "${ICO[err]:-x}" "$UI_R" "$msg" "$UI_FAINT" "$el" "$UI_R" >&2
  fi
  return "$rc"
}

# ui_launch <nom> — agentni ishga tushirishdan oldingi holat ko'rsatkichi.
#   Ilgari bu 3D gradient "AD" logosi + sweep animatsiyasi edi (~0.6 s kutish,
#   6 qator ekran). Endi — bitta qator: agent nomi + "ishga tushirilmoqda".
#   Ishga tushirish exec bilan darhol bo'ladi; foydalanuvchini kutdirmaymiz.
ui_launch() {
  local name="${1:-}"
  printf '\n  %s%s%s  %s%s%s  %s%s%s\n\n' \
    "$UI_BRAND" "${ICO[rocket]:->}" "$UI_R" \
    "$UI_B" "$name" "$UI_R" \
    "$UI_MUTED" "$(t 'ishga tushirilmoqda')" "$UI_R" >&2
}

# --- Fonda aylanuvchi yuklash ko'rsatkichi (menyu tayyorlanayotganda) -------
# ui_spin_start <xabar> — FONDA spinner boshlaydi; og'ir ish (build_rows/menu)
# bajarilayotganda terminal "muzlab qolgandek" tuyulmasligi uchun. Animatsiya
# o'chiq bo'lsa (TTY yo'q / CI / NO_COLOR / AI_NO_ANIM) — bir martalik oddiy qator.
# ui_spin_stop bilan to'xtatiladi (qatorni tozalaydi).
UI_SPIN_PID=""
ui_spin_start() {
  local msg="${1:-}"
  if [[ "${AI_ANIM:-0}" -ne 1 ]]; then
    printf '  %s%s %s%s\n' "$UI_MUTED" "${ICO[bullet]:--}" "$msg" "$UI_R" >&2
    return 0
  fi
  local frames; frames="$(ui_frames)"
  printf '\033[?25l' >&2                         # kursorni yashir
  (
    trap 'exit 0' TERM
    trap - ERR EXIT                              # ota-trapni meros qilmaymiz
    local i=0 n=${#frames}
    while :; do
      printf '\r  %s%s%s %s%s%s\033[K' \
        "${UI_BRAND}" "${frames:$((i % n)):1}" "${UI_R}" \
        "${UI_MUTED}" "$msg" "${UI_R}" >&2
      i=$((i + 1)); sleep 0.08
    done
  ) &
  UI_SPIN_PID=$!
}
ui_spin_stop() {
  [[ -n "${UI_SPIN_PID:-}" ]] || return 0
  kill "$UI_SPIN_PID" 2>/dev/null || true
  wait "$UI_SPIN_PID" 2>/dev/null || true
  UI_SPIN_PID=""
  printf '\r\033[K\033[?25h' >&2                 # qatorni tozala + kursorni qaytar
}
