#!/usr/bin/env bash
#
# ai-selector.sh — Aidevix CLI'ning asosiy skripti (buyruq: `aidevix`).
#
# Vazifasi: config/agents.conf faylidan AI CLI agentlarini o'qiydi, ularni
# FZF interfeysi (yoki oddiy raqamli menyu) orqali ko'rsatadi va tanlangan
# agentni ishga tushiradi. Agar CLI o'rnatilmagan bo'lsa — ruxsat so'rab,
# o'zi o'rnatadi.
#
# Foydalanish:
#   aidevix              # interaktiv menyu
#   aidevix claude       # to'g'ridan-to'g'ri agentni nomi/binari bo'yicha ishga tushirish
#   aidevix --list       # agentlar ro'yxati + holati
#   aidevix --update     # o'rnatilgan agentlarni yangilash
#   aidevix --doctor     # muhitni tekshirish
#   aidevix --add        # interaktiv yangi agent qo'shish
#   aidevix --help       # yordam
#
# Exit kodlari:
#   0   — muvaffaqiyat (yoki foydalanuvchi bekor qildi)
#   1   — umumiy/konfiguratsiya xatosi
#   2   — noto'g'ri argument
#   127 — kerakli buyruq (fzf yoki tanlangan agent) topilmadi

set -Eeuo pipefail

# --- Loyiha ildizini aniqlash (symlink orqali chaqirilsa ham) -------------
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_SOURCE" ]]; do
  dir="$(cd -P "$(dirname "$SCRIPT_SOURCE")" >/dev/null 2>&1 && pwd)"
  SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
  [[ "$SCRIPT_SOURCE" != /* ]] && SCRIPT_SOURCE="$dir/$SCRIPT_SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" >/dev/null 2>&1 && pwd)"
PROJECT_ROOT="$(cd -P "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"
# Preview kabi qism-jarayonlar uchun skriptning to'liq yo'li.
SELF="$SCRIPT_DIR/$(basename "$SCRIPT_SOURCE")"

# Versiya — VERSION faylidan o'qiladi (bo'lmasa quyidagi zaxira qiymat).
#
# CR/bo'shliqlar ATAYLAB tozalanadi. Sabab: Windows'da `core.autocrlf=true`
# bo'lganda git VERSION faylini CRLF bilan checkout qiladi, zip/tahrirlovchi ham
# CR qo'shib qo'yishi mumkin. Natijada versiya "1.9.2\r" bo'lib qoladi va
# `version_gt` da oxirgi bo'lak (`2\r`) RAQAM emas deb topilib 0 sanaladi —
# ya'ni CLI o'zini haqiqiydan ESKI deb biladi va yangilashni to'xtovsiz
# taklif qiladi. Bir ko'rinmas belgi — buzilgan tarqatish kanali.
AIDEVIX_VERSION="$(cat "$PROJECT_ROOT/VERSION" 2>/dev/null || echo "1.0.0")"
AIDEVIX_VERSION="${AIDEVIX_VERSION//[$'\r\n\t ']/}"     # forksiz, sof bash
[[ -n "$AIDEVIX_VERSION" ]] || AIDEVIX_VERSION="1.0.0"

# Repo config — ASOSIY ro'yxat (git orqali doimo yangilanadi).
# Foydalanuvchi config — faqat o'zi qo'shgan QO'SHIMCHA agentlar.
# Birlashtirilganda repo ustun turadi (yangi agentlar/tuzatishlar darrov yetadi),
# foydalanuvchi faqat repo'da YO'Q nomlarni qo'shadi. Shu tufayli main'ga push
# qilingan o'zgarishlar avtomatik yangilanishdan keyin hammaga ko'rinadi.
REPO_CONFIG="$PROJECT_ROOT/config/agents.conf"
USER_CONFIG="$HOME/.config/ai-cli/agents.conf"

# Oxirgi tanlangan agentni eslab qolish uchun holat fayli.
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/ai-cli"
STATE_FILE="$STATE_DIR/last"
# Lokal ishlatish statistikasi: har agent necha marta ishga tushirilgani.
# FAQAT shu kompyuterda saqlanadi — hech qayoqqa yuborilmaydi. Format: "<son>\t<nom>".
STATS_FILE="$STATE_DIR/usage"
# Login/auth eslatmasi qaysi agentlar uchun allaqachon ko'rsatilganini saqlaydi.
SEEN_AUTH_FILE="$STATE_DIR/seen_auth"
# "Aidevix nima/nima emas" tanishtiruvi BIR MARTA ko'rsatilganini belgilaydi.
INTRO_FILE="$STATE_DIR/seen_intro"
# Foydalanuvchi tanlagan interfeys tili ("uz"/"en") — ilk ishga tushishda so'raladi.
LANG_FILE="$STATE_DIR/lang"
# O'rnatilgan agent binarlari topilgan QO'SHIMCHA papkalar keshi (har qatorda bitta
# papka). Ba'zi o'rnatuvchilar binarni o'z papkasiga qo'yib PATH'ni faqat rc faylga
# yozadi — keyingi aidevix sessiyalari uni ko'rmay har safar qayta "o'rnatish"
# so'rardi. Shu kesh tufayli bir marta topilgan papka doim PATH'ga qo'shiladi.
BIN_DIR_CACHE="$STATE_DIR/bin_dirs"
# npm/python prefikslari keshi. Ularni aniqlash node/python jarayonini ishga
# tushiradi (Windows'da ~2.5 s va ~1 s) va bu HAR ishga tushishda takrorlanardi.
# Qiymat amalda o'zgarmaydi; kesh papkasi yo'qolsa avtomatik qayta aniqlanadi.
NPM_PREFIX_CACHE="$STATE_DIR/npm_prefix"
PY_USERBASE_CACHE="$STATE_DIR/py_userbase"

# --- Global statistika (OPT-IN — standart o'CHIQ) -------------------------
# Foydalanuvchi YOQSAGINA (aidevix --stats on) ishlaydi. Yoqilganda: agent
# ishga tushganda FAQAT "agent nomi + hodisa turi" markaziy serverga yuboriladi
# (IP/ID/shaxsiy ma'lumot YO'Q) va global reyting menyuda ko'rsatiladi.
# Server: bepul, ochiq — qarang server/. URL'ni AIDEVIX_STATS_URL bilan o'zgartirish mumkin.
AIDEVIX_STATS_URL="${AIDEVIX_STATS_URL:-https://sunnatbeecli-production.up.railway.app}"
GLOBAL_OPTIN_FILE="$STATE_DIR/global_stats"          # "on"/"off" — opt-in holati
GLOBAL_CACHE="$STATE_DIR/global_stats_cache"         # /v1/stats JSON keshi
GLOBAL_STAMP="$STATE_DIR/global_stats_check"         # keshni yangilash throttle vaqti
GLOBAL_HINT_FILE="$STATE_DIR/global_stats_hint"      # bir martalik eslatma ko'rsatilganini belgilaydi

# --- npm yangilanish eslatmasi (notify) -----------------------------------
# npm orqali o'rnatilganlarda git auto_update ishlamaydi (`.git` yo'q). Shuning
# uchun npm registry'dan eng so'nggi versiyani FONDA tekshirib, yangisi chiqsa
# "npm update -g aidevix" buyrug'ini eslatamiz (majburlamaymiz).
NPM_PKG="aidevix"                                    # npm registry'dagi paket nomi
NPM_LATEST_CACHE="$STATE_DIR/npm_latest"             # eng so'nggi versiya keshi
NPM_CHECK_STAMP="$STATE_DIR/npm_check"               # tekshirishni throttle vaqti
# Oxirgi O'LCHANGAN tarmoq javob vaqti (curl %{time_total}, sekundda) —
# status bardagi "ms" ko'rsatkichi shu fayldan o'qiladi.
LATENCY_FILE="$STATE_DIR/latency"
# Katta brend bloki BIR MARTA (ilk ishga tushishda) ko'rsatilganini belgilaydi;
# keyingi safarlar ixcham sarlavha bilan ochiladi (qarang lib/common.sh: banner).
# shellcheck disable=SC2034  # lib/common.sh: banner() uni dinamik ko'radi
BANNER_SEEN_FILE="$STATE_DIR/seen_banner"
# Foydalanuvchi tanlagan ikonka pog'onasi (nerd/unicode/ascii) — `--icons`.
ICONS_FILE="$STATE_DIR/icons"

# --- O'rnatilgan agentlarni avtomatik yangilash ---------------------------
# Har agent uchun "oxirgi yangilash urinishi" vaqti shu papkada saqlanadi.
# Throttled (AIDEVIX_UPDATE_INTERVAL) — har ishga tushganda emas, oraliqda bir
# marta `@latest`/`--upgrade`ga yangilaymiz. O'chirish: AIDEVIX_NO_AUTOUPDATE=1.
AGENT_UPDATE_DIR="$STATE_DIR/agent_update"           # per-agent yangilash throttle stamp'lari

# Kategoriya ko'rsatilmagan agentlar uchun standart qiymat.
DEFAULT_CATEGORY="AI"

# Tanlangan (curated) "top/mashhur" agentlar — binary nomi bo'yicha. Bitta haqiqat
# manbai: `--top` filtri HAM, menyu saralashi/⭐ belgisi HAM shunga tayanadi. Yangi
# mashhur CLI chiqsa — shu ro'yxatga binary nomini qo'shing (bo'sh joy bilan).
TOP_AGENTS="claude codex gemini copilot cursor-agent aider opencode qwen codebuff freebuff amp droid"

# --- Umumiy yordamchilarni yuklash ----------------------------------------
# ui.sh (common.sh ichidan yuklanadi) ikonka pog'onasi keshini shu papkada
# saqlaydi — testlar STATE_DIR'ni almashtirsa, kesh ham u bilan ko'chadi.
export AIDEVIX_STATE_DIR="$STATE_DIR"
LIB="$PROJECT_ROOT/lib/common.sh"
if [[ ! -r "$LIB" ]]; then
  printf '[x] Kutubxona topilmadi: %s\n' "$LIB" >&2
  exit 1
fi
# shellcheck source=../lib/common.sh
source "$LIB"

# --- Uzilish (Ctrl+C) holati ----------------------------------------------
# AIDEVIX_PHASE — hozir NIMA bajarilyapti. Ctrl+C bosilganda "Bekor qilindi"
# o'rniga ANIQ nima to'xtaganini aytamiz (yangilanishmi, menyumi, o'rnatishmi).
AIDEVIX_PHASE=""
INTERRUPTED=0
# TTY_SAVED_STATE — menyu RAW rejimga o'tishdan OLDIN saqlangan termios.
# Menyu `$(...)` qism-qobig'ida ishlaydi va uning EXIT-trap'i SIGINT'da
# ISHLAMAYDI (bash qism-qobiqni default INT bilan o'ldiradi), shuning uchun
# holatni OTA-jarayonda saqlaymiz — aks holda Ctrl+C dan keyin terminal
# raw rejimda (echo'siz) qolib ketadi.
TTY_SAVED_STATE=""

# save_tty_state — joriy termios'ni bir marta yodda saqlaydi.
save_tty_state() {
  [[ -z "$TTY_SAVED_STATE" ]] || return 0
  TTY_SAVED_STATE="$(stty -g 2>/dev/null </dev/tty || true)"
}
# atomic_write <fayl> <matn> — AVVAL vaqtinchalik faylga yozib, so'ng rename
# qiladi. `printf > fayl` fayldan avval truncate qiladi: Ctrl+C aynen shu
# oraliqda kelsa fayl BO'SH qolib ketardi. rename atomik — fayl doim yo eski,
# yo yangi holatda bo'ladi, hech qachon yarim.
atomic_write() {
  local f="$1" data="$2" tmp
  mkdir -p "$(dirname "$f")" 2>/dev/null || return 1
  tmp="$(mktemp "${f}.XXXXXX" 2>/dev/null)" || return 1
  if printf '%s\n' "$data" >"$tmp" 2>/dev/null && mv -f "$tmp" "$f" 2>/dev/null; then
    return 0
  fi
  rm -f "$tmp" 2>/dev/null
  return 1
}

# restore_tty_state — saqlangan termios'ni tiklaydi (bo'lmasa — no-op).
restore_tty_state() {
  [[ -n "$TTY_SAVED_STATE" ]] || return 0
  stty "$TTY_SAVED_STATE" 2>/dev/null </dev/tty || true
}

# Vaqtinchalik fayllarni tozalash + terminalni tiklash.
TMPFILES=()
cleanup() {
  ui_spin_stop 2>/dev/null || true
  restore_tty_state          # raw rejim qolib ketmasin (Ctrl+C dan keyin ham)
  show_cursor
  # Ichki menyu avto-o'rash/alt-screen'ni o'zgartirgan bo'lishi mumkin — har
  # ehtimolga tiklaymiz (alt-screen'da bo'lmasak \033[?1049l zararsiz no-op).
  [[ "${UI_TTY:-0}" -eq 1 ]] && printf '\033[?2026l\033[?7h\033[?1007l\033[?1049l' >&2 2>/dev/null || true
  local f
  for f in ${TMPFILES[@]+"${TMPFILES[@]}"}; do rm -f "$f" 2>/dev/null || true; done
}

# on_interrupt — Ctrl+C (INT) / TERM ishlov beruvchisi.
# Uchta muammoni hal qiladi:
#   1) terminalni DARHOL tiklaydi (raw rejim + alt-screen) — xabar ko'rinsin;
#   2) NIMA bekor qilinganini aniq aytadi (AIDEVIX_PHASE);
#   3) 130 bilan chiqadi (Ctrl+C uchun to'g'ri kod; ilgari 0 qaytardi).
# QAYTA KIRISHDAN himoyalangan: tozalash paytida yana Ctrl+C bosilsa, tutqich
# o'chirilgani uchun ikkinchi bosish darhol default tarzda o'ldiradi.
on_interrupt() {
  (( INTERRUPTED )) && return 0
  INTERRUPTED=1
  trap - INT TERM
  restore_tty_state
  printf '\033[?2026l\033[?1007l\033[?25h\033[?7h\033[?1049l' >&2 2>/dev/null || true
  ui_spin_stop 2>/dev/null || true
  local what
  case "$AIDEVIX_PHASE" in
    update)  what="$(t 'yangilanish')" ;;
    menu)    what="$(t 'menyu')" ;;
    install) what="$(t "agent o'rnatish")" ;;
    launch)  what="$(t 'agentni ishga tushirish')" ;;
    *)       what="$(t 'joriy amal')" ;;
  esac
  printf '\n' >&2
  log_warn "$(t "To'xtatildi (Ctrl+C) — %s bekor qilindi." "$what")"
  # Yangilanish yarim qolgan bo'lsa — holat buzilmaganini aytamiz (git/npm
  # o'z yozuvlarini o'zi atomik qiladi; biz faqat stamp yozamiz).
  [[ "$AIDEVIX_PHASE" == "update" ]] && \
    log_info "$(t "Fayllar buzilmadi — keyingi ishga tushirishda qaytadan urinadi.")"
  exit 130
}
trap on_interrupt INT TERM
# crash <buyruq> <qator> — KUTILMAGAN xato (ERR-tutqich) ishlov beruvchisi.
# Oddiy `die`dan farqi: crashlarning aksariyati ESKI versiyada bo'ladi (masalan
# v1.5.0 menyu ERR-trap bug'i), shuning uchun xatodan keyin yangilash buyrug'ini
# KATTA, ko'zga tashlanadigan panel bilan eslatamiz — user darrov chiqib oladi.
crash() {
  local cmd="${1:-?}" line="${2:-?}" upd i
  # ENG AVVAL alt-screen'dan chiqamiz. Menyu ochiq bo'lganda (\033[?1049h) xato
  # matni ALTERNATE ekranga chiziladi, so'ng ekran tiklanganda u O'CHIB ketadi —
  # "hech qanday xato ko'rsatmasdan yopildi" shikoyatining sababi aynan shu.
  # Ketma-ketlik idempotent: alt-screen ochilmagan bo'lsa ham zararsiz.
  printf '\033[?2026l\033[?1007l\033[?25h\033[?7h\033[?1049l' 2>/dev/null >/dev/tty || true
  log_error "$(t "Kutilmagan xato: %s (qator: %s)" "$cmd" "$line")"
  # AIDEVIX_DEBUG=1 — chaqiruvlar stegi (bug-report uchun). Std: ko'rsatilmaydi.
  if [[ -n "${AIDEVIX_DEBUG:-}" ]]; then
    printf '  --- aidevix stack trace ---\n' >&2
    for (( i=1; i<${#FUNCNAME[@]}; i++ )); do
      printf '    %s() @ %s:%s\n' "${FUNCNAME[i]}" "${BASH_SOURCE[i]:-?}" "${BASH_LINENO[i-1]:-?}" >&2
    done
  fi
  # Yangilash buyrug'i o'rnatish turiga qarab: git checkout bo'lsa --update, aks
  # holda npm (crash beradigan userlarning aksariyati — npm/Windows).
  upd="npm i -g ${NPM_PKG}@latest"
  if command -v is_npm_install >/dev/null 2>&1 && ! is_npm_install && [[ -d "$PROJECT_ROOT/.git" ]]; then
    upd="aidevix --update"
  fi
  ui_notice err "$(t "⚠  YANGILANG — bu xato yangi versiyada tuzatilgan bo'lishi mumkin")" \
    "" \
    "$(t 'Terminalga shu buyruqni yozing:')" \
    "" \
    "    ${C_BOLD}${C_GREEN}${upd}${C_RESET}" \
    "" \
    "$(t 'So'\''ngra aidevix ni qayta ishga tushiring.')"
  exit 1
}

trap cleanup EXIT
trap 'crash "$BASH_COMMAND" "$LINENO"' ERR

# --- Yordam matni ---------------------------------------------------------
usage() {
  if [[ "${AIDEVIX_LANG_RESOLVED:-uz}" == "en" ]]; then
    cat <<'EOF'
Aidevix CLI — manage your terminal AI CLI agents from a single menu.

NOTE: Aidevix is only a launcher — it installs and opens third-party AI CLIs.
It does NOT answer your prompts and does NOT provide any API key/token. Some
listed CLIs are paid, some are free or free-tier — the menu shows which.

USAGE:
  aidevix [OPTION | AGENT]

OPTIONS:
  (no argument)   Open the interactive menu: a two-column browser with the
                  agent list on the left, details on the right, and a status
                  bar at the bottom (a numbered menu as a last resort when
                  there is no terminal). Set AIDEVIX_USE_FZF=1 to use fzf
                  instead — note fzf cannot draw the status bar.
  AGENT           Launch an agent directly by name or binary
                  (e.g. `aidevix claude`, `aidevix gemini`)
  -l, --list      List agents and their status
  -f, --free      Open a menu of FREE agents only (no key/login, or free tier)
  -t, --top       Open a menu of the most popular (top) agents only
  -u, --update    Update all installed agents
  -d, --doctor    Check the environment (node/npm/python/fzf, PATH, agents)
  -a, --add       Add a new agent interactively
  -s, --stats [on|off]
                  Global stats (opt-in): show status, or turn on/off.
                  When on, the menu shows a popularity rank. Only the agent
                  name + event type are sent (no personal data). Default: off.
  -L, --lang [en|uz]
                  Choose the interface language (asked on first run), or set it
  -i, --icons [nerd|unicode|ascii|auto]
                  Icon style. Detected automatically (Nerd Font -> unicode ->
                  ascii); use this to force a style or re-run detection.
  -v, --version   Show the Aidevix CLI version
  -h, --help      Show this help text

CONFIGURATION:
  Agents are read from the following file (first one found wins):
    1) $AI_PULT_CONFIG (environment variable)
    2) ~/.config/ai-cli/agents.conf
    3) <repo>/config/agents.conf

  Format (6 required + 2 optional fields):
    NAME|BINARY|COMMAND|INSTALL|DESC|CATEGORY|AUTH|URL
EOF
  else
    cat <<'EOF'
Aidevix CLI — terminaldagi AI CLI agentlarini bitta menyudan boshqaring.

ESLATMA: Aidevix faqat ishga tushirgich — uchinchi-tomon AI CLI'larni o'rnatib,
ochib beradi. U savollarga JAVOB BERMAYDI va API kalit/token BERMAYDI. Ro'yxatdagi
ba'zi CLI'lar pullik, ba'zilari bepul yoki bepul tier — menyuda ko'rinadi.

FOYDALANISH:
  aidevix [TANLOV | AGENT]

TANLOVLAR:
  (argumentsiz)   Interaktiv menyuni ochadi: chapda agentlar ro'yxati, o'ngda
                  tanlangan agent tafsiloti, pastda status bar (terminal
                  bo'lmasa — raqamli menyu). fzf'ni afzal ko'rsangiz:
                  AIDEVIX_USE_FZF=1 — lekin fzf status bar chiza olmaydi.
  AGENT           Agentni nomi yoki binari bo'yicha to'g'ridan-to'g'ri ishga tushiradi
                  (masalan: `aidevix claude`, `aidevix gemini`)
  -l, --list      Agentlar ro'yxati va holatini ko'rsatadi
  -f, --free      Faqat BEPUL agentlar menyusini ochadi (kalit/loginsiz yoki bepul tier)
  -t, --top       Faqat eng mashhur (top) agentlar menyusini ochadi
  -u, --update    O'rnatilgan barcha agentlarni yangilaydi
  -d, --doctor    Muhitni tekshiradi (node/npm/python/fzf, PATH, agentlar)
  -a, --add       Interaktiv tarzda yangi agent qo'shadi
  -s, --stats [on|off]
                  Global statistika (opt-in): holatni ko'rsatadi yoki yoqadi/o'chiradi.
                  Yoqilganda menyuda mashhurlik reytingi ko'rinadi. Faqat agent
                  nomi + hodisa turi yuboriladi (shaxsiy ma'lumotsiz). Std — o'chiq.
  -L, --lang [en|uz]
                  Interfeys tilini tanlash (ilk ishga tushishda so'raladi) yoki o'rnatish
  -i, --icons [nerd|unicode|ascii|auto]
                  Ikonka uslubi. Avtomatik aniqlanadi (Nerd Font -> unicode ->
                  ascii); bu bilan majburan tanlash yoki qayta aniqlash mumkin.
  -v, --version   Aidevix CLI versiyasini ko'rsatadi
  -h, --help      Ushbu yordam matnini ko'rsatadi

KONFIGURATSIYA:
  Agentlar quyidagi fayldan o'qiladi (birinchi topilgani ishlatiladi):
    1) $AI_PULT_CONFIG (muhit o'zgaruvchisi)
    2) ~/.config/ai-cli/agents.conf
    3) <repo>/config/agents.conf

  Format (6 majburiy + 2 ixtiyoriy maydon):
    NOM|BINARY|BUYRUQ|INSTALL|IZOH|KATEGORIYA|AUTH|URL
EOF
  fi
}

# --- Ishlatiladigan konfiguratsiyani tanlash ------------------------------
# AI_PULT_CONFIG aniq berilgan bo'lsa — faqat o'sha (test/maxsus holatlar).
# Aks holda repo + foydalanuvchi qo'shimchalari birlashtiriladi (repo ustun).
resolve_config() {
  if [[ -n "${AI_PULT_CONFIG:-}" && -r "$AI_PULT_CONFIG" ]]; then
    printf '%s\n' "$AI_PULT_CONFIG"
    return 0
  fi
  build_merged_config
}

# build_merged_config — repo va foydalanuvchi configlarini birlashtirib,
# vaqtinchalik faylga yozadi va uning yo'lini qaytaradi. Repo agentlari ASOSIY;
# foydalanuvchi config faqat repo'da bo'lmagan NOMLARNI qo'shadi (o'z agentlari).
build_merged_config() {
  [[ -r "$REPO_CONFIG" || -r "$USER_CONFIG" ]] || \
    die 1 "$(t "Konfiguratsiya topilmadi. Tekshirildi: '%s', '%s'" "$REPO_CONFIG" "$USER_CONFIG")"

  local out; out="$(mktemp)"; TMPFILES+=("$out")
  local repo_names="" line nm

  if [[ -r "$REPO_CONFIG" ]]; then
    cat "$REPO_CONFIG" >>"$out"
    repo_names="$(grep -vE '^[[:space:]]*(#|$)' "$REPO_CONFIG" 2>/dev/null \
                  | cut -d'|' -f1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  fi

  if [[ -r "$USER_CONFIG" && "$USER_CONFIG" != "$REPO_CONFIG" ]]; then
    printf '\n# --- Foydalanuvchi qo\047shgan agentlar ---\n' >>"$out"
    while IFS= read -r line || [[ -n "$line" ]]; do
      case "$line" in ''|\#*) continue ;; esac
      nm="$(printf '%s' "$line" | cut -d'|' -f1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
      # Repo'da shu nom bo'lmasagina qo'shamiz (repo ustun turadi).
      grep -qxF "$nm" <<<"$repo_names" || printf '%s\n' "$line" >>"$out"
    done <"$USER_CONFIG"
  fi

  printf '%s\n' "$out"
}

# trim <matn> — boshi/oxiridagi bo'shliqlarni oladi.
# SOF BASH (ilgari `printf | sed` edi = HAR chaqiruvda IKKI fork). parse_agents
# har agent uchun 8 marta chaqiradi: 28 agentda bu ~450 fork edi. Windows/MSYS'da
# fork ~50-150 ms va cheklangan resurs — natijada menyu ochilishi sekinlashib,
# yuklama ostida "fork: Resource temporarily unavailable" xatosi chiqardi.
trim() { local s="$1"; trim_v s "$s"; printf '%s' "$s"; }

# trim_v <var> <matn> — fork'siz variant (natija o'zgaruvchiga).
# Ichki lokallar `__` bilan boshlanadi — chaqiruvchi bergan NOM bilan to'qnashib
# qolmasligi uchun (qarang lib/ui.sh dagi "NOM ORQALI QAYTARUVCHI" izohi).
trim_v() {
  local __v="$1" __s="$2"
  while [[ "$__s" == [$' \t\r\n']* ]]; do __s="${__s#?}"; done
  while [[ "$__s" == *[$' \t\r\n'] ]]; do __s="${__s%?}"; done
  printf -v "$__v" '%s' "$__s"
}

# ===========================================================================
#  MA'LUMOTNI NORMALLASHTIRISH: emoji → semantik maydonlar
# ===========================================================================
#
# config/agents.conf va tarjimalarda emoji ATAYLAB saqlanadi — ular
# foydalanuvchi configlari va i18n kalitlari bilan MOSLIKNI ta'minlaydi.
# Interfeys esa emoji ko'rsatmaydi: parse bosqichida emoji matndan olinadi
# va SEMANTIK maydonga (authclass) aylantiriladi, chizishda esa o'sha maydon
# ikonkaga aylanadi (lib/ui.sh). Shu tufayli:
#   • bitta agent bir joyda 🔑, boshqa joyda "key" deb yozilgan bo'lsa ham
#     interfeys bir xil ko'rinadi;
#   • Nerd Font/ASCII pog'onalari avtomatik ishlaydi.

# Emoji tozalash lib/ui.sh dagi ui_deemoji_v() da (bitta ta'rif — bitta emoji
# ro'yxati). Bu yerda `strip_emoji` qobig'i bor edi, lekin uni HECH KIM
# chaqirmasdi: tsikldagi kod ui_deemoji_v ni to'g'ridan-to'g'ri chaqiradi
# (`$(strip_emoji ...)` fork bo'lardi), shuning uchun olib tashlandi.

# classify_auth <auth> — login talabini SEMANTIK sinfga aylantiradi:
#   free    — kalit/login shart emas yoki bepul tier
#   browser — agent o'zi brauzer orqali login qiladi
#   key     — foydalanuvchi API kalit olishi kerak
#   paid    — obuna talab qilinadi
#   none    — talab ko'rsatilmagan
# Emoji ham, matn ham (uz/en) tushuniladi — user configlari buzilmaydi.
# Tartib MUHIM: 🆓 bepul tier boshqa belgilar bilan birga kelsa ham ustun.
# classify_auth_v <var> <auth> — fork'siz variant (${a,,} bash 4 bilan).
classify_auth_v() {
  local __v="$1" __a="$2" __l __r='none'
  if [[ -z "$__a" ]]; then printf -v "$__v" '%s' 'none'; return 0; fi
  __l="${__a,,}"
  case "$__a$__l" in
    *🆓*|*bepul*|*free*)                          __r='free' ;;
    *🌐*|*login*|*brauzer*|*browser*)             __r='browser' ;;
    *🔑*|*api*|*kalit*|*key*|*token*)             __r='key' ;;
    *💳*|*obuna*|*subscription*|*plan*|*pro/max*) __r='paid' ;;
  esac
  printf -v "$__v" '%s' "$__r"
}
classify_auth() { local r; classify_auth_v r "$1"; printf '%s' "$r"; }

# auth_icon <sinf> — auth sinfiga mos ikonka + rang (satr QAYTARADI).
auth_icon() {
  case "$1" in
    free)    printf '%s%s%s' "$UI_OK"    "${ICO[free]}"    "$UI_R" ;;
    browser) printf '%s%s%s' "$UI_INFO"  "${ICO[globe]}"   "$UI_R" ;;
    key)     printf '%s%s%s' "$UI_WARN"  "${ICO[key]}"     "$UI_R" ;;
    paid)    printf '%s%s%s' "$UI_AI"    "${ICO[card]}"    "$UI_R" ;;
    *)       printf '%s%s%s' "$UI_FAINT" "${ICO[bullet]}"  "$UI_R" ;;
  esac
}

# auth_label <sinf> — auth sinfining o'qiladigan nomi.
auth_label() {
  case "$1" in
    free)    t 'bepul' ;;
    browser) t 'brauzer login' ;;
    key)     t 'API kalit' ;;
    paid)    t 'obuna' ;;
    *)       printf '%s' '—' ;;
  esac
}

# detect_provider <binary> <install> <url> — agentning provayderini aniqlaydi.
# Status barda ko'rsatiladi. Manba tartibi: URL domeni → install paketi → binary.
# detect_provider_v <var> <binary> <install> <url> — fork'siz variant.
detect_provider_v() {
  local __v="$1" __s="${4} ${3} ${2}"
  __s="${__s,,}"
  # TARTIB MUHIM: ko'p agentlarning havolasi github.com'da turadi, shuning
  # uchun umumiy `*github*` naqshi ENG OXIRIDA tekshiriladi — aks holda
  # Qwen/Crush kabi agentlar "github" deb belgilanib qolardi.
  local __r
  case "$__s" in
    *anthropic*|*claude*)         __r='anthropic' ;;
    *openai*|*codex*)             __r='openai' ;;
    *google*|*gemini*|*aistudio*) __r='google' ;;
    *qwen*|*alibaba*|*dashscope*) __r='qwen' ;;
    *mistral*)                    __r='mistral' ;;
    *openrouter*)                 __r='openrouter' ;;
    *deepseek*)                   __r='deepseek' ;;
    *groq*)                       __r='groq' ;;
    *ollama*|*llama*)             __r='ollama' ;;
    *cursor*)                     __r='cursor' ;;
    *aider*)                      __r='aider' ;;
    *charm*|*crush*)              __r='charm' ;;
    *copilot*)                    __r='github' ;;
    *github.com*)                 __r='github' ;;
    *)                            __r='local' ;;
  esac
  printf -v "$__v" '%s' "$__r"
}
detect_provider() { local r; detect_provider_v r "$1" "$2" "$3"; printf '%s' "$r"; }

# provider_key_var <provayder> — o'sha provayderning standart API-kalit
# muhit o'zgaruvchisi nomi (status barda "kalit bor/yo'q" uchun).
provider_key_var() {
  case "$1" in
    anthropic)  printf 'ANTHROPIC_API_KEY' ;;
    openai)     printf 'OPENAI_API_KEY' ;;
    google)     printf 'GEMINI_API_KEY' ;;
    mistral)    printf 'MISTRAL_API_KEY' ;;
    openrouter) printf 'OPENROUTER_API_KEY' ;;
    deepseek)   printf 'DEEPSEEK_API_KEY' ;;
    groq)       printf 'GROQ_API_KEY' ;;
    *)          printf '' ;;
  esac
}

# provider_model_var <provayder> — agent qaysi modelni ishlatishini MUHITDAN
# o'qish uchun o'zgaruvchi nomi. Bu YAGONA halol manba: Aidevix modelni
# o'zi tanlamaydi va API'ga murojaat qilmaydi, shuning uchun foydalanuvchi
# o'rnatgan qiymat bo'lmasa — status barda "—" ko'rsatiladi.
provider_model_var() {
  case "$1" in
    anthropic)  printf 'ANTHROPIC_MODEL' ;;
    openai)     printf 'OPENAI_MODEL' ;;
    google)     printf 'GEMINI_MODEL' ;;
    ollama)     printf 'OLLAMA_MODEL' ;;
    openrouter) printf 'OPENROUTER_MODEL' ;;
    *)          printf '' ;;
  esac
}

# --- O'rnatish buyrug'i qaysi dasturga tayanishini aniqlash ----------------
# Masalan "npm install -g ..." → "npm". Bu dastur yo'q bo'lsa, oldindan
# sodda xabar berib, foydalanuvchini chalkash xatolardan asraymiz.
detect_install_tool() {
  local install="$1"
  if   [[ "$install" == *"npm "* ]];     then echo "npm"
  elif [[ "$install" == *"python3 "* ]]; then echo "python3"
  elif [[ "$install" == *"python "* ]];  then echo "python"
  elif [[ "$install" == *"pip"* ]];      then echo "python3"
  elif [[ "$install" == *"brew "* ]];    then echo "brew"
  elif [[ "$install" == *"go install"* ]]; then echo "go"
  elif [[ "$install" == *"curl "* ]];    then echo "curl"
  elif [[ "$install" == *"wget "* ]];    then echo "wget"
  else echo ""; fi
}

# resolve_install_cmd <install> — o'rnatish buyrug'ini joriy muhitga moslaydi.
# Windows'da `python3` ko'pincha Microsoft Store STUB'i (WindowsApps ichidagi
# 0-baytli alias) — u pip'ni ishga tushirmaydi, faqat Store'ni taklif qiladi.
# python3 haqiqatan ishlamasa-yu haqiqiy `python` bo'lsa, buyruqdagi python3'ni
# python'ga almashtiramiz. Boshqa buyruqlar o'zgarishsiz qaytadi.
resolve_install_cmd() {
  local install="$1"
  case "$install" in
    *python3\ *) : ;;
    *) printf '%s' "$install"; return 0 ;;
  esac
  # python3 bor va HAQIQATAN ishlaydi (stub `-c` bilan xato qaytaradi) — tegmaymiz.
  if command -v python3 >/dev/null 2>&1 && python3 -c 'import sys' >/dev/null 2>&1; then
    printf '%s' "$install"; return 0
  fi
  # python3 yo'q/stub, lekin `python` ishlaydi → almashtiramiz.
  if command -v python >/dev/null 2>&1 && python -c 'import sys' >/dev/null 2>&1; then
    printf '%s' "${install//python3 /python }"; return 0
  fi
  printf '%s' "$install"
}

# --- Oxirgi tanlovni eslab qolish -----------------------------------------
read_last() { [[ -r "$STATE_FILE" ]] && cat "$STATE_FILE" 2>/dev/null || true; }
save_last() {
  mkdir -p "$STATE_DIR" 2>/dev/null || return 0
  printf '%s\n' "$1" >"$STATE_FILE" 2>/dev/null || true
}

# --- Lokal ishlatish statistikasi (faqat shu kompyuter) -------------------
# record_usage <nom> — agentning lokal sanog'ini +1 qiladi. Eng-yaxshi-harakat:
# har qanday xato bo'lsa ham agentni ishga tushirishga xalaqit bermaydi. awk
# bilan yoziladi (bash 3.2 mos — assotsiativ massiv ishlatilmaydi).
record_usage() {
  local name="$1"
  [[ -n "$name" ]] || return 0
  mkdir -p "$STATE_DIR" 2>/dev/null || return 0
  [[ -f "$STATS_FILE" ]] || : >"$STATS_FILE" 2>/dev/null || return 0
  local tmp; tmp="$(mktemp 2>/dev/null)" || return 0
  if awk -F'\t' -v n="$name" '
        BEGIN { OFS = "\t" }
        $2 == n { print ($1 + 1), $2; found = 1; next }
        NF      { print }
        END     { if (!found) print 1, n }
      ' "$STATS_FILE" >"$tmp" 2>/dev/null; then
    mv -f "$tmp" "$STATS_FILE" 2>/dev/null || rm -f "$tmp" 2>/dev/null
  else
    rm -f "$tmp" 2>/dev/null
  fi
  return 0
}

# read_usage <nom> — agentning lokal sanog'ini chiqaradi (yo'q bo'lsa 0).
read_usage() {
  local name="$1"
  [[ -r "$STATS_FILE" ]] || { printf '0'; return 0; }
  awk -F'\t' -v n="$name" '$2 == n { print $1 + 0; f = 1; exit } END { if (!f) print 0 }' \
    "$STATS_FILE" 2>/dev/null || printf '0'
}

# ===========================================================================
#  Global statistika (OPT-IN). Maxfiylik: yoqilgandagina, faqat agent nomi +
#  hodisa turi yuboriladi. CI'da yoki curl yo'q bo'lsa — hech narsa qilinmaydi.
# ===========================================================================

# --- Global statistika (opt-in) funksiyalari (lib/stats.sh) ---------------
STATS_LIB="$PROJECT_ROOT/lib/stats.sh"
if [[ -r "$STATS_LIB" ]]; then
  # shellcheck source=../lib/stats.sh
  source "$STATS_LIB"
fi

# --- Til tanlash (i18n) ---------------------------------------------------
# load_saved_lang — saqlangan til tanlovini qo'llaydi (AIDEVIX_LANG env ustun).
load_saved_lang() {
  [[ -n "${AIDEVIX_LANG:-}" ]] && return 0
  [[ -r "$LANG_FILE" ]] || return 0
  aidevix_set_lang "$(cat "$LANG_FILE" 2>/dev/null || true)" 2>/dev/null || true
}

# choose_language — ILK interaktiv ishga tushishda tilni so'raydi (English/O'zbek),
# tanlovni saqlaydi va darrov qo'llaydi. Til hali tanlanmaganда ikki tilda so'raladi.
# AIDEVIX_LANG env, CI yoki TTY yo'q bo'lsa — so'ramaydi.
choose_language() {
  [[ -n "${AIDEVIX_LANG:-}" ]] && return 0
  [[ -n "${CI:-}" ]] && return 0
  [[ -r "$LANG_FILE" ]] && return 0
  { : >/dev/tty; } 2>/dev/null || return 0

  {
    printf '\n  %s%s%s Til tanlang  /  Choose your language%s\n' \
      "$UI_B" "$UI_BRAND" "${ICO[brand]}" "$UI_R"
    printf '  %s\n\n' "$(ui_rule 40)"
    printf '    %s%s1%s  English\n'    "$UI_B" "$UI_TEXT" "$UI_R"
    printf '    %s%s2%s  Oʻzbekcha\n\n' "$UI_B" "$UI_TEXT" "$UI_R"
  } >/dev/tty
  local ans=""
  trap - ERR
  printf '  %s%s%s %s1/2%s ' "$UI_FAINT" "${ICO[arrow]}" "$UI_R" "$UI_MUTED" "$UI_R" >/dev/tty
  IFS= read -r ans </dev/tty || ans=""
  trap 'crash "$BASH_COMMAND" "$LINENO"' ERR

  local chosen=""
  case "$ans" in
    1|en|EN|english|English)        chosen=en ;;
    2|uz|UZ|uzbek|oʻzbekcha|ozbek)  chosen=uz ;;
    *)                              chosen="${AIDEVIX_LANG_RESOLVED:-uz}" ;;  # Enter → aniqlangan
  esac
  mkdir -p "$STATE_DIR" 2>/dev/null || true
  atomic_write "$LANG_FILE" "$chosen" || true
  aidevix_set_lang "$chosen" 2>/dev/null || true
}

# lang_cmd [en|uz] — `aidevix --lang`: tilni o'rnatadi yoki qayta tanlatadi.
lang_cmd() {
  local arg="${1:-}"
  case "$arg" in
    en|uz)
      mkdir -p "$STATE_DIR" 2>/dev/null || true
      atomic_write "$LANG_FILE" "$arg" || true
      aidevix_set_lang "$arg" 2>/dev/null || true
      log_success "$(t 'Til o'\''rnatildi: %s' "$arg")"
      ;;
    ''|choose|select)
      rm -f "$LANG_FILE" 2>/dev/null || true
      choose_language
      log_success "$(t 'Til o'\''rnatildi: %s' "${AIDEVIX_LANG_RESOLVED:-uz}")"
      ;;
    *)
      die 2 "$(t "Noma'lum: 'aidevix --lang %s'. Foydalanish: aidevix --lang [en|uz]" "$arg")"
      ;;
  esac
}

# --- Ikonka pog'onasi (`aidevix --icons`) ---------------------------------
# Nerd Font mavjudligini Aidevix o'zi aniqlaydi (fontconfig / macOS shrift
# papkalari / Windows reyestri) va natijani keshlaydi. Bu buyruq — qo'lda
# boshqarish uchun: majburan tanlash yoki qayta aniqlash.
#   aidevix --icons            → joriy uslubni ko'rsatadi
#   aidevix --icons nerd|unicode|ascii → majburan o'rnatadi
#   aidevix --icons auto       → keshni tashlab, qaytadan aniqlaydi
icons_cmd() {
  local arg="${1:-}"
  case "$arg" in
    '')
      log_info "$(t 'Ikonka uslubi: %s' "${UI_ICON_TIER:-unicode}")"
      # Namuna — foydalanuvchi belgilar TO'G'RI ko'rinayotganini o'zi ko'rsin.
      printf '  %s%s %s %s %s %s %s %s%s\n' "$UI_MUTED" \
        "${ICO[dot_on]}" "${ICO[dot_off]}" "${ICO[key]}" "${ICO[globe]}" \
        "${ICO[card]}" "${ICO[free]}" "${ICO[star]}" "$UI_R" >&2
      # Bu maslahat FAQAT nerd pog'onasida ma'noga ega — unicode/ascii
      # belgilari har qanday shriftda chiziladi.
      if [[ "${UI_ICON_TIER:-}" == "nerd" ]]; then
        log_step "$(t "Belgilar kvadrat bo'lib ko'rinsa: aidevix --icons unicode")"
      fi
      ;;
    nerd|unicode|ascii)
      mkdir -p "$STATE_DIR" 2>/dev/null || true
      atomic_write "$ICONS_FILE" "$arg" || true
      ui_icons_set "$arg"
      log_success "$(t "Ikonka uslubi o'rnatildi: %s" "$arg")"
      ;;
    auto)
      rm -f "$ICONS_FILE" "$STATE_DIR/icons_cache" 2>/dev/null || true
      if ui_icons_probe_nerd; then
        ui_icons_set nerd
        log_success "$(t 'Nerd Font topildi — nerd ikonkalari yoqildi.')"
      else
        ui_icons_set unicode
        log_info "$(t "Nerd Font topilmadi — unicode ikonkalariga o'tildi.")"
      fi
      mkdir -p "$STATE_DIR" 2>/dev/null \
        && printf '%s\n' "$UI_ICON_TIER" >"$STATE_DIR/icons_cache" 2>/dev/null || true
      ;;
    *)
      die 2 "$(t "Noto'g'ri ikonka uslubi: %s (nerd|unicode|ascii|auto)" "$arg")"
      ;;
  esac
}

# maybe_show_intro — Aidevix nima EKANLIGINI (va nima EMASligini) BIR MARTA
# tushuntiradi. Ko'pchilik menyudagi CLI'larni "bepul" yoki "aidevix javob
# beradi" deb o'ylaydi — bu chalkashlikni oldindan oldini olamiz.
maybe_show_intro() {
  [[ -n "${CI:-}" ]] && return 0
  [[ -e "$INTRO_FILE" ]] && return 0
  mkdir -p "$STATE_DIR" 2>/dev/null || return 0
  : >"$INTRO_FILE" 2>/dev/null || true
  ui_notice ai "$(t 'ℹ️  Aidevix nima — va nima EMAS')" \
    "$(t 'Aidevix — faqat ishga tushirgich (launcher): AI CLI'\''larni siz uchun')" \
    "$(t 'o'\''rnatib, ochib beradi — xolos.')" \
    "" \
    "$(t '• CLI'\''larning O'\''ZI uchinchi tomon dasturlar (Anthropic, Google, OpenAI, ...).')" \
    "$(t '• Ba'\''zilari PULLIK, ba'\''zilari bepul yoki bepul tier — menyuda ko'\''rasiz:')" \
    "  $(auth_icon free) $(auth_label free)   $(auth_icon browser) $(auth_label browser)   $(auth_icon key) $(auth_label key)   $(auth_icon paid) $(auth_label paid)" \
    "$(t '• Aidevix savollarga JAVOB BERMAYDI va token/kalit BERMAYDI.')" \
    "$(t '  API kalitni o'\''zingiz tegishli xizmatdan olasiz; Aidevix uni ko'\''rmaydi.')"
}

# --- Birinchi ishga tushirishda login/auth yo'riqnomasi --------------------
# Agent AUTH maydoniga ega bo'lsa va u ilk bor ishga tushirilayotgan bo'lsa,
# foydalanuvchiga login/API kalit kerakligini SODDA tilda bir marta aytamiz.
# Kalitlarni biz saqlamaymiz — bu faqat ogohlantirish.
# should_open_login_link <auth> — login sahifasini brauzerda ochish KERAKMI?
#   Ha (0) — FAQAT agent "o'zingiz API kalit oling" (🔑) talab qilsa VA o'sha
#   kalit muhitda hali yo'q bo'lsa. Ya'ni agentni ishlatib bo'lmaydi → loginga
#   yo'naltiramiz.
#   Yo'q (1) — agar:
#     • agent brauzer orqali login (🌐), obuna (💳) yoki bepul (🆓) bo'lsa
#       (bularda agentning o'zi login qiladi yoki login shart emas), YOKI
#     • tegishli API kalit allaqachon o'rnatilgan bo'lsa (agent ishlab ketadi).
should_open_login_link() {
  local auth="$1"
  case "$auth" in
    *🌐*|*🆓*|*💳*) return 1 ;;   # agent o'zi hal qiladi / bepul
  esac
  [[ "$auth" == *🔑* ]] || return 1   # API kalit umuman talab qilinmaydi

  # Kalit allaqachon muhitda bormi? Bo'lsa — agent ishlaydi, link shart emas.
  local v vars common
  vars="$(printf '%s' "$auth" | grep -oE '[A-Z][A-Z0-9_]*(_API_KEY|_TOKEN|_KEY)' 2>/dev/null || true)"
  common="ANTHROPIC_API_KEY OPENAI_API_KEY GEMINI_API_KEY GOOGLE_API_KEY OPENROUTER_API_KEY GROQ_API_KEY DEEPSEEK_API_KEY MISTRAL_API_KEY"
  for v in $vars $common; do
    [[ -n "${!v:-}" ]] && return 1
  done
  return 0   # 🔑 kerak, lekin kalit yo'q → loginga yo'naltiramiz
}

maybe_show_auth_note() {
  local name="$1" auth="$2" url="${3:-}"
  [[ -n "$auth" || -n "$url" ]] || return 0
  if [[ -r "$SEEN_AUTH_FILE" ]] && grep -qxF "$name" "$SEEN_AUTH_FILE" 2>/dev/null; then
    return 0
  fi
  mkdir -p "$STATE_DIR" 2>/dev/null || true
  printf '%s\n' "$name" >>"$SEEN_AUTH_FILE" 2>/dev/null || true

  if [[ -n "$url" ]] && should_open_login_link "$auth"; then
    # Login/registratsiya kerak — sahifani brauzerda ochamiz.
    ui_notice warn "$(t "🔐 '%s' — login/kalit kerak" "$name")" \
      "$(t 'Bu agentni ishlatish uchun API kalit kerak:')" \
      "    $auth" \
      "" \
      "$(t '🌐 Kalit olish sahifasi brauzerda ochilmoqda:')" \
      "    $url" \
      "" \
      "$(t '👉 Kalitni oling va agent ko'\''rsatmasiga amal qiling. Aidevix kalitni')" \
      "$(t '   ko'\''rmaydi va saqlamaydi — u faqat sizning kompyuteringizda qoladi.')"
    open_url "$url"
    [[ "${AI_ANIM:-0}" -eq 1 ]] && sleep 0.8 || true
  elif [[ -n "$auth" ]]; then
    # Alohida loginga yo'naltirish SHART EMAS (kalit bor, agent o'zi login
    # qiladi, yoki bepul) — faqat qisqa eslatma beramiz, brauzer ochmaymiz.
    ui_notice info "$(t "🔐 '%s' — eslatma" "$name")" \
      "$(t 'Login talabi: %s' "$auth")" \
      "$(t '👉 Agar agent login so'\''rasa, ekrandagi ko'\''rsatmaga amal qiling.')"
    [[ "${AI_ANIM:-0}" -eq 1 ]] && sleep 0.4 || true
  fi
}

# --- PATH'ni keng tarqalgan paket-menejer bin papkalari bilan boyitish -----
# AI CLI'lar odatda `npm -g`, `pip --user`, `cargo` orqali o'rnatiladi. Yangi
# kompyuterda bu papkalar PATH'da bo'lmasligi mumkin — natijada o'rnatilgan
# CLI topilmay, har safar qaytadan "o'rnatish" so'raladi. Bu funksiya o'sha
# papkalarni JORIY sessiya PATH'iga qo'shib, muammoni bartaraf etadi.
augment_tool_path() {
  local dirs=() d prefix userbase

  # Avval PATH'ni buzuq yozuvlardan TOZALAYMIZ. Git Bash'da Windows-shakl yo'l
  # (C:\Users\...) PATH'ga tushib qolsa, ":" ajratgich "C:" ni bo'lib, yagona
  # "C" harfi va "\Users\..." kabi buzuq bo'laklar hosil qiladi (bu ko'pincha
  # eski ~/.bashrc blokidan keladi). Ular npm shim'larini chalkashtirib,
  # "Cannot find module C:\Program Files\Git\Users\..." xatosini beradi.
  # Shu yozuvlarni olib tashlaymiz — qolgan to'g'ri (/c/...) yo'llar yetarli.
  local cleaned="" entry
  local _oldifs="$IFS"
  set -f
  IFS=':'
  for entry in $PATH; do
    case "$entry" in
      ''|[A-Za-z]|\\*) continue ;;   # bo'sh, yagona drive harfi ("C"), yoki "\..."
    esac
    cleaned="${cleaned:+$cleaned:}$entry"
  done
  IFS="$_oldifs"
  set +f
  [[ -n "$cleaned" ]] && PATH="$cleaned"

  # npm/python prefikslarini KESHLAYMIZ. `npm config get prefix` node'ni
  # ishga tushiradi va Windows'da ~2.5 s turadi, `python -m site` ~1 s —
  # ular HAR ishga tushishda chaqirilgani uchun aidevix'ning o'zi sekin
  # ochilardi. Prefiks amalda deyarli o'zgarmaydi, shuning uchun keshdan
  # o'qiymiz va kesh yo'q/eskirgan (papka yo'qolgan) bo'lsagina qayta so'raymiz.
  if command -v npm >/dev/null 2>&1; then
    prefix=""
    if [[ -r "$NPM_PREFIX_CACHE" ]]; then
      read -r prefix <"$NPM_PREFIX_CACHE" 2>/dev/null || prefix=""
      # Kesh ishonchli bo'lishi uchun papka hali ham mavjudligini tekshiramiz.
      [[ -n "$prefix" && -d "$prefix" ]] || prefix=""
    fi
    if [[ -z "$prefix" ]]; then
      prefix="$(npm config get prefix 2>/dev/null || true)"
      if [[ -n "$prefix" && "$prefix" != "undefined" && -d "$prefix" ]]; then
        mkdir -p "$STATE_DIR" 2>/dev/null \
          && printf '%s\n' "$prefix" >"$NPM_PREFIX_CACHE" 2>/dev/null || true
      fi
    fi
    if [[ -n "$prefix" && "$prefix" != "undefined" ]]; then
      # Unix'da binar $prefix/bin ichida, Windows'da $prefix ichida bo'ladi.
      dirs+=("$prefix/bin" "$prefix")
    fi
  fi
  # python3 Windows'da ko'pincha Store stub'i (user-base bermaydi) — haqiqiy
  # natija chiqquncha python3, so'ng python bilan urinamiz. Natija keshlanadi
  # (yuqoridagi sabab bilan).
  userbase=""
  if [[ -r "$PY_USERBASE_CACHE" ]]; then
    read -r userbase <"$PY_USERBASE_CACHE" 2>/dev/null || userbase=""
    [[ -n "$userbase" && -d "$userbase" ]] || userbase=""
  fi
  if [[ -z "$userbase" ]]; then
    local py
    for py in python3 python; do
      command -v "$py" >/dev/null 2>&1 || continue
      userbase="$("$py" -m site --user-base 2>/dev/null || true)"
      [[ -n "$userbase" ]] && break
    done
    if [[ -n "$userbase" ]]; then
      mkdir -p "$STATE_DIR" 2>/dev/null \
        && printf '%s\n' "$userbase" >"$PY_USERBASE_CACHE" 2>/dev/null || true
    fi
  fi
  if [[ -n "${userbase:-}" ]]; then
    # Windows-shakl yo'lni avval POSIX'ga o'giramiz — pastdagi glob ishlashi uchun.
    case "$userbase" in
      [A-Za-z]:[\\/]*|*\\*)
        command -v cygpath >/dev/null 2>&1 && \
          userbase="$(cygpath -u "$userbase" 2>/dev/null || printf '%s' "$userbase")"
        ;;
    esac
    dirs+=("$userbase/bin" "$userbase/Scripts")
    # Windows'da pip --user skriptlari VERSIYALI papkaga tushadi:
    # %APPDATA%\Python\Python3XX\Scripts — usiz pip agentlari hech qachon
    # topilmay, har safar qayta o'rnatish so'ralardi.
    local pd
    for pd in "$userbase"/Python*/Scripts; do
      [[ -d "$pd" ]] && dirs+=("$pd")
    done
  fi
  dirs+=("$HOME/.local/bin" "$HOME/bin" "$HOME/.cargo/bin" "$HOME/AppData/Roaming/npm")

  # Oldingi sessiyalarda topilgan binar papkalari (locate_binary keshi).
  if [[ -r "$BIN_DIR_CACHE" ]]; then
    while IFS= read -r d; do
      [[ -n "$d" && -d "$d" ]] && dirs+=("$d")
    done <"$BIN_DIR_CACHE"
  fi

  for d in "${dirs[@]}"; do
    # Windows-shakldagi yo'l (masalan `C:\Users\...` — npm config get prefix
    # Git Bash'da shunday qaytaradi) PATH'ga to'g'ridan-to'g'ri qo'shilsa, ":"
    # ajratgich "C:" ni bo'lib yuboradi va `\Users\...` degan buzuq yozuv hosil
    # bo'ladi. Bu esa npm shim'larida yo'lni `C:\Program Files\Git\Users\...` ga
    # aylantirib, "Cannot find module" xatosini keltirib chiqaradi. Shu sababli
    # bunday yo'llarni avval POSIX shaklga (`/c/Users/...`) o'tkazamiz.
    case "$d" in
      [A-Za-z]:[\\/]*|*\\*)
        if command -v cygpath >/dev/null 2>&1; then
          d="$(cygpath -u "$d" 2>/dev/null || printf '%s' "$d")"
        fi
        ;;
    esac
    if [[ -d "$d" && ":$PATH:" != *":$d:"* ]]; then
      PATH="$d:$PATH"
    fi
  done
  export PATH
  hash -r 2>/dev/null || true
}

# --- O'rnatilgan binarni PATH tashqarisidan qidirish + eslab qolish --------
# record_bin_dir <papka> — binar papkasini doimiy keshga qo'shadi (takrorsiz).
# Keyingi sessiyalarda augment_tool_path bu papkalarni avtomatik PATH'ga qo'shadi.
record_bin_dir() {
  local d="$1"
  [[ -n "$d" && -d "$d" ]] || return 0
  mkdir -p "$STATE_DIR" 2>/dev/null || return 0
  if grep -qxF "$d" "$BIN_DIR_CACHE" 2>/dev/null; then return 0; fi
  printf '%s\n' "$d" >>"$BIN_DIR_CACHE" 2>/dev/null || true
}

# locate_binary <binary> — PATH'da ko'rinmayotgan binarni MA'LUM o'rnatish
# joylaridan qidiradi (o'rnatuvchi PATH'ni faqat rc faylga yozgan holat).
# Topsa: papkani joriy PATH'ga qo'shadi, keshlaydi va 0 qaytaradi. Shu tufayli
# "o'rnatilgan, lekin har safar qayta o'rnatish so'raydi" muammosi yo'qoladi.
locate_binary() {
  local binary="$1" d cand
  [[ -n "$binary" ]] || return 1
  local -a cands=(
    "$HOME/.local/bin" "$HOME/bin" "$HOME/.cargo/bin" "$HOME/go/bin"
    "$HOME/.$binary/bin" "$HOME/.$binary"
    /usr/local/bin /opt/homebrew/bin
  )
  # Windows pip --user skriptlari (versiyali papka).
  for d in "$HOME/AppData/Roaming/Python"/Python*/Scripts; do
    [[ -d "$d" ]] && cands+=("$d")
  done
  for d in "${cands[@]}"; do
    [[ -d "$d" ]] || continue
    for cand in "$d/$binary" "$d/$binary.exe" "$d/$binary.cmd"; do
      [[ -x "$cand" ]] || continue
      if [[ ":$PATH:" != *":$d:"* ]]; then
        PATH="$d:$PATH"; export PATH
      fi
      hash -r 2>/dev/null || true
      record_bin_dir "$d"
      return 0
    done
  done
  return 1
}

# --- Konfiguratsiyani o'qib, TAB bilan ajratilgan qatorlar chiqarish -------
# Chiqish formati: NAME\tDESC\tBINARY\tCOMMAND\tINSTALL\tCATEGORY
parse_agents() {
  local config="$1"
  local line name binary command install desc category auth url lineno=0 found=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    lineno=$((lineno + 1))
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue

    IFS='|' read -r name binary command install desc category auth url <<<"$line"
    # BUTUN shu blok ATAYLAB fork'siz (trim_v/t_v/classify_auth_v/... ).
    # Ilgari har maydon `$(trim ...)` orqali o'tardi — bu 28 agentda ~450
    # `sed` forki demakdi; MSYS'da menyu ochilishini soniyalarga cho'zib,
    # yuklama ostida "fork: Resource temporarily unavailable" berardi.
    trim_v name "${name:-}"
    trim_v binary "${binary:-}"
    trim_v command "${command:-}"
    trim_v install "${install:-}"
    trim_v desc "${desc:-}"
    trim_v category "${category:-}"
    trim_v auth "${auth:-}"
    trim_v url "${url:-}"
    [[ -z "$category" ]] && category="$DEFAULT_CATEGORY"

    if [[ -z "$name" || -z "$binary" || -z "$command" ]]; then
      log_warn "$(t "Noto'g'ri qator o'tkazib yuborildi (#%s): %s" "$lineno" "$line")"
      continue
    fi
    # Agent izohi (desc) va login izohi (auth) — tanlangan tilga tarjima qilamiz
    # (en bo'lsa). Shunda menyu/preview/--list TO'LIQ bir tilda chiqadi (uz manba
    # — kalit).
    [[ -n "$desc" ]] && t_v desc "$desc"
    [[ -n "$auth" ]] && t_v auth "$auth"

    # Emoji SEMANTIK maydonlarga aylanadi, so'ng matndan olib tashlanadi.
    # Klassifikatsiya TOZALASHDAN OLDIN bo'lishi shart — belgilar aynan
    # shu yerda ma'no tashiydi (qarang classify_auth).
    local authclass provider
    classify_auth_v authclass "$auth"
    detect_provider_v provider "$binary" "$install" "$url"
    ui_deemoji_v desc "$desc"
    ui_deemoji_v auth "$auth"
    # ui_deemoji_v satr BOSHIDAGI otstupni ataylab saqlaydi (notice panellari
    # uchun). desc/auth esa maket emas — MA'LUMOT maydoni: "🧠 Izoh" dan emoji
    # olingach qolgan bo'shliq tafsilot panelida "│  Izoh" bo'lib ikkilanardi.
    trim_v desc "$desc"
    trim_v auth "$auth"

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$name" "$desc" "$binary" "$command" "$install" "$category" \
      "$auth" "$url" "$authclass" "$provider"
    found=1
  done <"$config"

  [[ "$found" -eq 1 ]] || die 1 "$(t 'Konfiguratsiyada yaroqli agent topilmadi: %s' "$config")"
}

# --- Holat ustuni bilan to'ldirilgan qatorlar -----------------------------
# Chiqish formati (11 maydon, TAB bilan):
#   1 NAME  2 DESC  3 BINARY  4 COMMAND  5 INSTALL  6 CATEGORY
#   7 STATUS  8 AUTH  9 URL  10 AUTHCLASS  11 PROVIDER
#
# STATUS endi emoji emas, MASHINA O'QIYDIGAN token: "installed" / "missing".
# Ilgari u "✓ o'rnatilgan" edi — ya'ni belgi, rang va TARJIMA bitta satrga
# aralashgan; har tekshiruv `*✓*` naqshiga tayanardi va ustun tekislash
# bayt/ustun farqi tufayli buzilardi. Endi token — chizishda ikonkaga aylanadi.
build_rows() {
  local config="$1" name desc binary command install category auth url status
  local authclass provider
  # IFS=US (0x1f) — TAB whitespace bo'lgani uchun bo'sh maydonlarni "yutib" yuboradi
  # (masalan install bo'sh bo'lsa, keyingi maydonlar siljiydi). Shu sababli TAB'ni
  # non-whitespace ajratgich (\037)ga o'giramiz — bo'sh maydonlar saqlanadi.
  while IFS=$'\037' read -r name desc binary command install category auth url authclass provider; do
    if command -v "$binary" >/dev/null 2>&1; then
      status="installed"
    else
      status="missing"
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$name" "$desc" "$binary" "$command" "$install" "$category" \
      "$status" "$auth" "$url" "$authclass" "$provider"
  done < <(parse_agents "$config" | tr '\t' '\037')
}

# ESLATMA: bu yerda `count_installed` funksiyasi bor edi (rows'dan "28/31"
# hisoblardi), lekin uni hech kim chaqirmasdi — status bar sanoqni menyuning
# o'zida, `r_st[]` massividan bir o'tishda hisoblaydi (qarang select_with_arrows:
# AGENT_COUNT). Ikkinchi nusxani saqlab turishning ma'nosi yo'q edi.

# --- --list rejimi --------------------------------------------------------
# Agentlar lokal ishlatish sanog'i bo'yicha KAMAYISH tartibida ko'rsatiladi
# (eng ko'p ishlatilgan tepada); "MARTA" ustuni shu sanoqni ko'rsatadi.
list_agents() {
  local config; config="$(resolve_config)"
  local statsfile="$STATS_FILE"; [[ -r "$statsfile" ]] || statsfile=/dev/null
  local w; w="$(ui_width)"
  local dw=$(( w - 60 )); (( dw < 16 )) && dw=16

  # `--list` — MA'LUMOT beruvchi buyruq: chiqishi STDOUT'ga ketadi, shunda
  # `aidevix --list | grep ...` ishlaydi (log/menyu esa stderr'da qoladi).
  local UI_FD=1
  ui_header "${UI_MUTED}$(t 'agentlar')${UI_R}"
  printf '  %s%-20s %-14s %-10s %-2s%5s   %s%s\n' "$UI_MUTED" \
    "$(t AGENT)" "$(t HOLAT)" "$(t GURUH)" "" "$(t MARTA)" "$(t IZOH)" "$UI_R"

  # Takrorlanuvchi bo'laklarni BIR MARTA tayyorlaymiz. Tsikl ichida `$(...)`
  # ishlatish 28 qatorda ~140 fork demakdi — MSYS'da (~85 ms/fork) bu
  # `--list` ni 12 soniyaga cho'zardi. Endi tsiklda fork YO'Q.
  detail_init
  local B_ON B_OFF
  B_ON="$(ui_badge ok "$(t "o'rnatilgan")")"
  B_OFF="${UI_FAINT}${ICO[dot_off]} $(t "yo'q")${UI_R}"

  local name desc binary command install category status auth url authclass provider count
  local badge used cname cbadge ccat cdesc
  while IFS=$'\037' read -r name desc binary command install category status auth url authclass provider count; do
    if [[ "$status" == "installed" ]]; then badge="$B_ON"; else badge="$B_OFF"; fi
    used=""; [[ "${count:-0}" =~ ^[0-9]+$ ]] && (( count > 0 )) && used="${count}×"
    # Rangli satrlarni `%-Ns` to'g'ri tekislamaydi (ANSI baytlari ham sanaladi) —
    # to'ldirishni ui_pad_v qiladi, u ko'rinadigan uzunlikni hisoblaydi.
    ui_pad_v cname  "${UI_TEXT}${name}${UI_R}" 20
    ui_pad_v cbadge "$badge" 14
    ui_pad_v ccat   "${UI_MUTED}${category}${UI_R}" 10
    ui_trunc_v cdesc "$desc" "$dw"
    printf '  %s %s %s %s %s%5s%s   %s%s%s\n' \
      "$cname" "$cbadge" "$ccat" "${AUTH_ICO[$authclass]:-}" \
      "$UI_FAINT" "$used" "$UI_R" \
      "$UI_MUTED" "$cdesc" "$UI_R"
  done < <(
    build_rows "$config" | awk -F'\t' -v sf="$statsfile" '
      BEGIN { while ((getline line < sf) > 0) { m = split(line, a, "\t"); if (m >= 2) cnt[a[2]] = a[1] } }
      { c = cnt[$1] + 0; printf "%010d\t%06d\t%s\t%d\n", c, (++idx), $0, c }
    ' | sort -t"$(printf '\t')" -k1,1nr -k2,2n | cut -f3- | tr '\t' '\037'
  )
  printf '  %s\n' "$(ui_rule $(( w - 4 )))"
  # Legenda — auth ikonkalari nimani anglatishini bir qatorda tushuntiradi.
  ui_footer "$(auth_icon free)=$(auth_label free)" \
            "$(auth_icon browser)=$(auth_label browser)" \
            "$(auth_icon key)=$(auth_label key)" \
            "$(auth_icon paid)=$(auth_label paid)"
  printf '  %s%s%s\n\n' "$UI_FAINT" "$(t 'konfiguratsiya: %s' "$config")" "$UI_R"
}

# --- Tafsilot paneli (o'ng ustun) — YAGONA manba --------------------------
# detail_lines <...> — tanlangan agent tafsilotini global DETAIL[] massiviga
# yozadi. HAM fzf preview, HAM ichki ikki-ustunli menyu shundan chizadi —
# shuning uchun ikkala interfeys bir xil ko'rinadi. Ilgari ular ikki alohida
# maket edi (awk'da va bash'da), va vaqt o'tib bir-biridan uzoqlashgandi.
#
# Sof bash, fork YO'Q: bu funksiya klavish tsiklida har siljishda chaqiriladi.
#   detail_lines <name> <desc> <binary> <cmd> <install> <cat> <status>
#                <auth> <url> <authclass> <provider> <eni>
declare -ga DETAIL=()
# DETAIL_SEC — oxirgi BO'LIM SARLAVHASI ("o'rnatish") indeksi, yo'q bo'lsa -1.
# Panel balandligi yetmay tanasi kesilib qolsa, sarlavhani ham olib tashlash
# uchun kerak (qarang detail_clip) — yolg'iz sarlavha ma'nosiz ko'rinadi.
DETAIL_SEC=-1

# --- Statik matnlarni BIR MARTA tayyorlash --------------------------------
# `t()` va `auth_icon` chaqiruvlari `$(...)` ichida fork qiladi. detail_lines
# klavish tsiklida ishlagani uchun ular OLDINDAN hisoblanadi va shu global
# jadvallarda saqlanadi. detail_init() menyu ochilishidan oldin bir marta
# chaqiriladi (idempotent).
declare -gA AUTH_ICO=() AUTH_LBL=()   # `-g` — qarang lib/i18n.sh dagi izoh
DL_L_CMD="" DL_L_CAT="" DL_L_PROV="" DL_L_LOGIN="" DL_L_URL=""
DL_L_INSTALL="" DL_BADGE_ON="" DL_BADGE_OFF="" DL_READY=""
detail_init() {
  [[ -z "$DL_READY" ]] || return 0
  local c
  for c in free browser key paid none; do
    AUTH_ICO[$c]="$(auth_icon "$c")"
    AUTH_LBL[$c]="$(auth_label "$c")"
  done
  DL_L_CMD="$(t 'buyruq')"
  DL_L_CAT="$(t 'guruh')"
  DL_L_PROV="$(t 'provayder')"
  DL_L_LOGIN="$(t 'login')"
  DL_L_URL="$(t 'havola')"
  DL_L_INSTALL="$(t "o'rnatish")"
  DL_BADGE_ON="$(ui_badge ok "$(t "o'rnatilgan")")"
  DL_BADGE_OFF="${UI_FAINT}${ICO[dot_off]} $(t "o'rnatilmagan")${UI_R}"
  DL_READY=1
}

# detail_lines — DETAIL[] ni to'ldiradi. SOF BASH: birorta ham `$(...)` yo'q
# (qarang detail_init va lib/ui.sh dagi `_v` variantlar).
detail_lines() {
  local name="$1" desc="$2" binary="$3" cmd="$4" install="$5" cat="$6"
  local status="$7" auth="$8" url="$9" authclass="${10}" provider="${11}" w="${12:-46}"
  detail_init
  DETAIL=()
  DETAIL_SEC=-1
  local iw=$(( w - 2 )); (( iw < 12 )) && iw=12
  local badge tmp kv

  if [[ "$status" == "installed" ]]; then badge="$DL_BADGE_ON"
  else                                    badge="$DL_BADGE_OFF"; fi

  ui_trunc_v tmp "$name" $(( iw - 15 ))
  DETAIL+=("${UI_B}${UI_TEXT}${tmp}${UI_R}  ${badge}")
  DETAIL+=("")

  if [[ -n "$desc" ]]; then
    ui_trunc_v tmp "$desc" "$iw"
    DETAIL+=("${UI_MUTED}${tmp}${UI_R}")
    DETAIL+=("")
  fi

  ui_trunc_v tmp "$cmd" $(( iw - 11 ))
  ui_kv_v kv "$DL_L_CMD" "${UI_AI}${tmp}${UI_R}"; DETAIL+=("$kv")
  ui_trunc_v tmp "$cat" $(( iw - 11 ))
  ui_kv_v kv "$DL_L_CAT" "${UI_TEXT}${tmp}${UI_R}"; DETAIL+=("$kv")
  ui_trunc_v tmp "$provider" $(( iw - 11 ))
  ui_kv_v kv "$DL_L_PROV" "${UI_TEXT}${tmp}${UI_R}"; DETAIL+=("$kv")
  ui_trunc_v tmp "${AUTH_LBL[$authclass]:-—}" $(( iw - 13 ))
  ui_kv_v kv "$DL_L_LOGIN" "${AUTH_ICO[$authclass]:-} ${UI_TEXT}${tmp}${UI_R}"; DETAIL+=("$kv")
  if [[ -n "$url" ]]; then
    ui_trunc_v tmp "$url" $(( iw - 11 ))
    ui_kv_v kv "$DL_L_URL" "${UI_INFO}${tmp}${UI_R}"; DETAIL+=("$kv")
  fi

  DETAIL+=("")
  if [[ -n "$install" ]]; then
    DETAIL_SEC=${#DETAIL[@]}                # sarlavha indeksi (tanasi — keyingi)
    DETAIL+=("${UI_MUTED}${DL_L_INSTALL}${UI_R}")
    ui_trunc_v tmp "$install" "$iw"
    DETAIL+=("${UI_FAINT}${tmp}${UI_R}")
  fi
}

# detail_clip <ko'rinadigan-qatorlar-soni> — panel kesilganda OXIRIDA yolg'iz
# qolgan bo'lim sarlavhasini o'chiradi. Past terminalda "o'rnatish" sarlavhasi
# ko'rinib, buyrug'ining o'zi kesilib qolardi — foydalanuvchi bo'sh sarlavha
# ko'rardi. Sof bash, fork yo'q (klavish tsiklida chaqiriladi).
detail_clip() {
  local cap="$1"
  (( DETAIL_SEC >= 0 )) || return 0
  [[ -n "${DETAIL[DETAIL_SEC]+x}" ]] || return 0
  # Sarlavha ko'rinadi (cap > h), tanasi esa yo'q (cap <= h+1) → aynan cap == h+1.
  (( cap == DETAIL_SEC + 1 )) || return 0
  DETAIL[DETAIL_SEC]=""
}

# --- Preview (fzf tomonidan qism-jarayon sifatida chaqiriladi) -------------
# fzf preview'ni TTY'siz ishga tushiradi — ranglar to'g'ridan-to'g'ri ANSI
# bo'lib chiqadi (fzf --ansi ularni ko'rsatadi). Chiqish STDOUT'ga.
preview_agent() {
  local name="$1" datafile="$2" width="${3:-52}"
  [[ -r "$datafile" ]] || return 0
  local n d b c ins cat st a u ac pr L
  while IFS=$'\037' read -r n d b c ins cat st a u ac pr; do
    [[ "$n" == "$name" ]] || continue
    detail_lines "$n" "$d" "$b" "$c" "$ins" "$cat" "$st" "$a" "$u" "$ac" "$pr" "$width"
    printf '\n'
    for L in "${DETAIL[@]}"; do printf ' %s\n' "$L"; done
    return 0
  done < <(tr '\t' '\037' <"$datafile")
}

# --- Menyu qatorlarini qurish (eng ko'p ishlatilgan yuqorida) --------------
# Chiqish formati: KO'RINISH\tNAME  (NAME — qidirish uchun yashirin maydon).
# Qatorlar LOKAL ishlatish sanog'i bo'yicha KAMAYISH tartibida; teng bo'lsa
# config tartibi saqlanadi. Har agent yonida "· N×" (lokal) va — global
# statistika yoqilgan bo'lsa — "🔥 #rank · count" (global) belgisi ko'rinadi.
# OXIRGI ishga tushirilgan agent (STATE_FILE) hammadan tepada "↩" bilan chiqadi —
# agent yopilib qolganda uni qayta ochish bitta ENTER bo'ladi.
#   build_menu <rows> [lokal-stats-fayl] [global-tsv-fayl] [oxirgi-agent-nomi]
build_menu() {
  local rows="$1" statsfile="${2:-}" globalfile="${3:-}" lastname="${4:-}"
  [[ -n "$statsfile" && -r "$statsfile" ]] || statsfile=/dev/null
  [[ -n "$globalfile" && -r "$globalfile" ]] || globalfile=/dev/null
  local w; w="$(ui_width)"
  # Izoh ustuni terminal eniga moslashadi (nom 18 + holat/meta ~30 zaxira).
  local descw=$(( w - 52 )); (( descw < 14 )) && descw=14
  # Tor terminalda 14 lik "pol" enidan oshib ketardi. Ustma-ust (stacked)
  # maketda qator = 4 (otstup) + 1 (ikonka) + 2 + 18 (nom) + 1 + descw + meta,
  # ya'ni descw eng ko'pi bilan w-32 bo'la oladi (meta uchun 6 zaxira).
  local descmax=$(( w - 32 )); (( descw > descmax )) && descw=$descmax
  (( descw < 6 )) && descw=6
  local ell='…'; [[ "${UI_ICON_TIER:-unicode}" == "ascii" ]] && ell='..'
  awk -F'\t' -v sf="$statsfile" -v gf="$globalfile" -v tops=" $TOP_AGENTS " \
            -v last="$lastname" -v descw="$descw" -v ell="$ell" \
            -v i_on="${ICO[dot_on]}" -v i_off="${ICO[dot_off]}" \
            -v i_last="${ICO[last]}" \
            -v c_ok="${UI_OK:-}" -v c_faint="${UI_FAINT:-}" -v c_muted="${UI_MUTED:-}" \
            -v c_text="${UI_TEXT:-}" -v c_ai="${UI_AI:-}" \
            -v z="${UI_R:-}" -v b="${UI_B:-}" '
    # DIQQAT: ellipsis ascii pogonada IKKI belgi (".."), unicode da bitta.
    # Ilgari bu yerda n-1 yozilgan edi va ascii pogonada natija bir belgi
    # UZUNROQ chiqib, tor terminalda qator enidan oshib ketardi.
    function clip(s, n,   el) {
      el = length(ell)
      return (length(s) > n) ? substr(s, 1, n - el) ell : s
    }
    BEGIN {
      # Lokal statistika: nom -> son.
      while ((getline line < sf) > 0) {
        m = split(line, a, "\t")
        if (m >= 2) cnt[a[2]] = a[1]
      }
      # Global statistika (ixtiyoriy): nom -> rank, son.
      while ((getline gline < gf) > 0) {
        m = split(gline, gp, "\t")
        if (m >= 3) { grank[gp[1]] = gp[2]; gcnt[gp[1]] = gp[3] }
      }
    }
    {
      name=$1; desc=$2; binary=$3; status=$7;
      icon = (status == "installed") ? c_ok i_on z : c_faint i_off z;
      c      = cnt[name] + 0;
      istop  = (index(tops, " " binary " ") > 0) ? 1 : 0;
      islast = (last != "" && name == last) ? 1 : 0;

      # META ZONASI — eng so`nik, o`ngda. Ilgari bu yerda 5 tagacha emoji
      # bo`lardi (auth badge + yulduz + olov + rank + sanoq + "oxirgi" matni).
      # Endi: "oxirgi" VA "top" o`zaro istisno (bittasi yetarli), auth belgisi
      # esa umuman olib tashlandi — u o`ng ustunda batafsil ko`rinadi.
      # DIQQAT: bu awk dasturi bash `\x27...\x27` bloki ichida — izohlarda
      # APOSTROF ISHLATMANG, u blokni uzib yuboradi (build_menu jim buziladi).
      # "Top" yulduzchasi ataylab yoq: qatorlar allaqachon mashhurlik boyicha
      # saralangan (istop saralash kalitida qatnashadi), yani belgi osha
      # manoni takrorlab, royxatning yarmida shovqin hosil qilardi.
      meta = "";
      if (islast)        meta = meta " " c_ai i_last z;
      if (c > 0)         meta = meta sprintf(" %s%d×%s", c_faint, c, z);
      if (name in grank) meta = meta sprintf(" %s#%d%s", c_faint, grank[name], z);

      disp = sprintf("%s  %s%s%-18s%s %s%s%s%s",
                     icon, b, c_text, name, z, c_muted, clip(desc, descw), z, meta);
      # Tartiblash kalitlari:
      #   1) oxirgi ishlatilgan (eng tepada — bitta ENTER bilan qayta ochish)
      #   2) O`RNATILGAN (o`rnatilganlar HAR DOIM o`rnatilmaganlardan tepada —
      #      darhol ishlatib boladigan agentni qidirib otirmaslik uchun)
      #   3) lokal sanoq (kamayish)
      #   4) top/mashhurlik (kamayish — yangi foydalanuvchida ham mashhurlar tepada)
      #   5) config indeksi (barqaror tartib)
      inst = (status == "installed") ? 1 : 0;
      printf "%d\t%d\t%010d\t%d\t%06d\t%s\t%s\n",
             islast, inst, c, istop, (++idx), disp, name
    }
  ' <<<"$rows" \
    | sort -t"$(printf '\t')" -k1,1nr -k2,2nr -k3,3nr -k4,4nr -k5,5n | cut -f6-
}

# --- fzf orqali tanlash ---------------------------------------------------
select_with_fzf() {
  local menu="$1" datafile="$2" selection rc
  # Ranglar ichki menyu bilan BIR XIL semantik palitradan (lib/ui.sh):
  # siyoh = brend/AI, kulrang = ikkilamchi, so'nik = ramka. Ilgari bu yerda
  # feruza/pushti gradient bor edi va ichki menyudan butunlay boshqacha
  # ko'rinardi — bitta mahsulot ikki xil tuyulardi.
  local -a fzf_args=(
    --ansi
    --delimiter='\t'
    --with-nth=1
    --prompt="$(printf '%s ' "${ICO[search]}")"
    --pointer="${ICO[arrow]}"
    --marker="${ICO[ok]}"
    --height=~92%
    --layout=reverse
    --margin='1,2'
    --info=inline
    --color='fg:-1,bg:-1,hl:141,fg+:252,bg+:236,hl+:141,info:240,prompt:141,pointer:141,marker:114,header:245,border:240'
    --header="$(printf '%s Aidevix\n%s' "${ICO[brand]}" "$(ui_rule 46)")"
  )
  # Eski fzf `--border=<qiymat>` ni tanimasligi mumkin — flag umuman
  # berilmasa standart holat (ramkasiz) ishlaydi, ya'ni zaxira yo'l kerak emas.

  # Preview har siljishda `bash` qism-jarayonini ochadi. Windows (Git Bash /
  # MSYS / Cygwin)da bu ko'pincha cygwin fork (child_copy / cygheap) xatolarini
  # keltirib chiqaradi va menyuni xato xabarlari bilan to'ldiradi. Shuning uchun
  # Windows'da preview STANDART O'CHIQ. Yoqish: AIDEVIX_FZF_PREVIEW=1.
  local want_preview=1
  case "$(uname -s 2>/dev/null || echo unknown)" in
    MINGW*|MSYS*|CYGWIN*) want_preview=0 ;;
  esac
  [[ -n "${AIDEVIX_FZF_PREVIEW:-}" ]] && want_preview=1
  [[ -n "${AIDEVIX_NO_PREVIEW:-}" ]]  && want_preview=0
  if [[ "$want_preview" -eq 1 ]]; then
    # Preview eni ichki menyudagi o'ng ustun bilan bir xil nisbatda (58/42),
    # ajratgichi ham bir xil — ikkala interfeys bitta maketga bo'ysunadi.
    local pw=$(( $(ui_width) * 58 / 100 - 6 )); (( pw < 30 )) && pw=30
    fzf_args+=(
      --preview "bash \"$SELF\" __preview {2} \"$datafile\" $pw"
      --preview-window='right,58%,wrap,border-left'
    )
  fi

  selection="$(printf '%s\n' "$menu" | fzf "${fzf_args[@]}")" || {
    rc=$?
    case "$rc" in
      130|1) log_info "$(t 'Bekor qilindi.')"; exit 0 ;;   # ESC/Ctrl-C yoki moslik yo'q
      *)
        # fzf'ning O'ZI ishlamadi (eski versiya flag'ni tanimaydi, TTY muammosi...)
        # — die qilmaymiz: rc=3 bilan qaytamiz, chaqiruvchi (run_menu) ichki
        # ↑/↓ menyuga o'tadi. Aks holda eski fzf'li userlarda menyu UMUMAN ochilmasdi.
        return 3 ;;
    esac
  }
  [[ -z "$selection" ]] && { log_info "$(t 'Hech narsa tanlanmadi.')"; exit 0; }
  # Yashirin NAME maydoni — TAB'dan keyingi qism.
  printf '%s' "$selection" | sed 's/.*\t//'
}

# --- fzf bo'lmaganda oddiy raqamli menyu ----------------------------------
select_with_numbers() {
  local menu="$1"
  local -a displays=() names=()
  local disp nm
  while IFS=$'\t' read -r disp nm; do
    [[ -z "$nm" ]] && continue
    displays+=("$disp"); names+=("$nm")
  done <<<"$menu"

  [[ "${#names[@]}" -gt 0 ]] || die 1 "$(t 'Menyu uchun agent topilmadi.')"

  # ESLATMA: ilgari bu yerda "fzf topilmadi" deyilardi, lekin raqamli menyu
  # endi fzf yo'qligidan emas — TERMINAL yo'qligidan (quvur/CI) yoki ichki
  # menyu ochilmaganidan ko'rsatiladi. Xabar shunga moslandi.
  log_warn "$(t "Interaktiv menyu ishlamadi — oddiy raqamli menyu ko'rsatilmoqda.")"
  local w; w="$(ui_width)"
  ui_header "${UI_MUTED}$(t 'agent tanlang')${UI_R}"
  local i
  for i in "${!names[@]}"; do
    printf '  %s%3d%s  %b\n' "${UI_FAINT}" "$((i + 1))" "${UI_R}" "${displays[$i]}" >&2
  done
  printf '  %s\n' "$(ui_rule $(( w - 4 )))" >&2

  local choice="" prompt; prompt="  $(t 'Raqam kiriting (1-%s, ESC=bekor)' "${#names[@]}") ${ICO[arrow]} "
  trap - ERR
  if { : >/dev/tty; } 2>/dev/null; then
    printf '%s' "$prompt" >/dev/tty
    IFS= read -r choice </dev/tty || choice=""
  else
    printf '%s' "$prompt" >&2
    IFS= read -r choice || choice=""
  fi
  trap 'crash "$BASH_COMMAND" "$LINENO"' ERR

  [[ -z "$choice" ]] && { log_info "$(t 'Bekor qilindi.')"; exit 0; }
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#names[@]} )); then
    die 2 "$(t "Noto'g'ri tanlov: '%s'." "$choice")"
  fi
  printf '%s' "${names[$((choice - 1))]}"
}

# --- fzf bo'lmaganda: ↑/↓ klavishali ichki menyu (built-in TUI) -----------
# fzf yo'q bo'lganda ham QULAY tanlash beradi: ko'rsatkich (▶) bilan yuqori/pastga
# yuriladi, pastda tanlangan agentning TO'LIQ tafsiloti (buyruq, login, havola,
# o'rnatish, izoh) ko'rinadi, harf yozib QIDIRISH mumkin. ENTER — ishga tushiradi;
# ESC yoki (qidiruv bo'sh bo'lsa) q — bekor. Tanlangan agent NOMI stdout'ga
# qaytadi; butun interfeys /dev/tty'ga chiziladi. fzf preview Windows'da o'chiq
# bo'lgani uchun bu menyu HAR JOYDA to'liq ma'lumot ko'rsatadi va tashqi `bash`
# qism-jarayoni ochmaydi (cygwin fork xatosi yo'q). Chaqiruvchi (run_menu) TTY
# borligini oldindan tekshiradi; TTY yo'q bo'lsa raqamli menyuga o'tadi.
select_with_arrows() {
  local menu="$1" datafile="$2"
  local -a displays=() names=()
  local disp nm
  while IFS=$'\t' read -r disp nm; do
    [[ -z "$nm" ]] && continue
    displays+=("$disp"); names+=("$nm")
  done <<<"$menu"
  local total=${#names[@]}
  [[ "$total" -gt 0 ]] || die 1 "$(t 'Menyu uchun agent topilmadi.')"

  # Interaktiv TTY shart (chaqiruvchi tekshirgan; bu — himoya uchun ikkilamchi).
  # UI_DUMP rejimida TTY kerak emas: bitta kadr stdout'ga chiziladi (test seam).
  if [[ -z "${AIDEVIX_UI_DUMP:-}" ]]; then
    { : >/dev/tty; } 2>/dev/null || return 2  # gate run_menu'da; bu ikkilamchi himoya
  fi

  # Klavisha o'qish `dd`ga tayanadi (qarang _rd). Yo'q bo'lsa JIM o'lmaymiz:
  # rc=2 bilan qaytamiz → run_menu raqamli menyuga tushadi va sababini aytadi.
  command -v dd >/dev/null 2>&1 || return 2

  # Datafile (TSV, 9 maydon)ni BIR o'qishda massivlarga olamiz — klavish tsiklida
  # tashqi jarayon (awk) UMUMAN ochilmaydi. Windows/MSYS'da har fork ~50-150ms:
  # avvalgi per-keypress awk/subshell'lar bitta strelka bosishini soniyagacha
  # cho'zib, "menyuda scroll ishlamayapti" shikoyatiga sabab bo'lardi.
  # TAB → \037 (US) — bo'sh maydonlar "yutilmasligi" uchun (qarang build_rows).
  local -a r_name=() r_desc=() r_bin=() r_cmd=() r_inst=() r_cat=() r_st=()
  local -a r_auth=() r_url=() r_ac=() r_prov=()
  local rn rd rb rc2 ri rcat rst ra ru rac rpr
  while IFS=$'\037' read -r rn rd rb rc2 ri rcat rst ra ru rac rpr; do
    [[ -n "$rn" ]] || continue
    r_name+=("$rn"); r_desc+=("$rd"); r_bin+=("$rb"); r_cmd+=("$rc2")
    r_inst+=("$ri"); r_cat+=("$rcat"); r_st+=("$rst"); r_auth+=("$ra")
    r_url+=("$ru");  r_ac+=("$rac");   r_prov+=("$rpr")
  done < <(tr '\t' '\037' <"$datafile")

  # QIDIRUV matnlari (kichik harf) — bitta tr bilan butun faylni kichraytirib
  # o'qiymiz (bash 3.2 da ${var,,} yo'q). Tartib r_* massivlari bilan bir xil.
  local -a r_hay=()
  while IFS=$'\037' read -r rn rd rb rc2 ri rcat rst ra ru rac rpr; do
    [[ -n "$rn" ]] || continue
    r_hay+=("$rn $rd $rb $rcat $ra $rpr")
  done < <(tr '\t' '\037' <"$datafile" | tr '[:upper:]' '[:lower:]')

  # Menyu indeksi → datafile qatori indeksi (nom bo'yicha; sof bash, forksiz).
  local -a rowof=() hay=()
  local i j
  for i in "${!names[@]}"; do
    rowof[i]=-1
    for j in "${!r_name[@]}"; do
      if [[ "${r_name[j]}" == "${names[i]}" ]]; then rowof[i]=$j; break; fi
    done
    if (( rowof[i] >= 0 )); then hay[i]="${r_hay[${rowof[i]}]}"; else hay[i]=""; fi
  done

  # ===================== MAKET (LAYOUT) HISOBI ============================
  # Ikki ustunli maket: CHAPDA qidiriladigan agentlar ro'yxati, O'NGDA
  # tanlangan agentning tafsiloti. Tor terminalda (< 84 ustun) avtomatik
  # ustma-ust (stacked) maketga tushadi — ro'yxat tepada, tafsilot pastda.
  local th tw
  th="$(tput lines 2>/dev/null || echo 24)"; [[ "$th" =~ ^[0-9]+$ ]] || th=24
  tw="$(ui_width)"

  local two_col=0 lw=0 rw=0
  if (( tw >= 84 )); then
    two_col=1
    lw=$(( tw * 42 / 100 ))
    (( lw < 34 )) && lw=34
    (( lw > 54 )) && lw=54
    rw=$(( tw - lw - 7 ))          # chekkalar + ajratgich + bo'shliqlar
  else
    lw=$(( tw - 4 )); rw=$(( tw - 4 ))
  fi

  # Tana balandligi — sarlavha(1)+chiziq(1)+qidiruv(1)+bo'sh(1)+chiziq(1)
  # +status(1)+footer(1) = 7 qator zaxira, +2 xavfsizlik.
  local body=$(( th - 9 ))
  (( body < 5 )) && body=5
  (( body > 20 )) && body=20
  local page=$body
  if (( two_col == 0 )); then
    page=$(( body - 8 )); (( page < 3 )) && page=3   # qolgani tafsilotga
  fi
  (( page > total )) && page=$total
  (( page < 1 )) && page=1

  # ================= STATIK MATNLARNI BIR MARTA TAYYORLASH =================
  # Har `$(t ...)` — buyruq-almashtirish, ya'ni FORK. Klavish tsiklida ular
  # takrorlansa MSYS/Windows'da menyu sezilarli sekinlashadi (har fork
  # ~50-150 ms), shuning uchun hammasi shu yerda BIR MARTA hisoblanadi.
  detail_init
  local S_PROMPT S_NOMATCH S_SEP S_RULE S_FOOT S_STATUS=""
  local S_KEY_SET S_KEY_UNSET S_DASH AGENT_COUNT S_VER S_LAT
  S_PROMPT="$(t 'qidirish')"
  S_NOMATCH="${UI_MUTED}$(t "Moslik yo'q — Backspace bilan qidiruvni tahrirlang.")${UI_R}"
  S_SEP="${UI_FAINT}${ICO[sep]}${UI_R}"
  S_RULE="$(ui_rule $(( tw - 4 )))"
  S_KEY_SET="$(t 'kalit bor')"
  S_KEY_UNSET="$(t 'kalit yo'\''q')"
  S_DASH='—'; [[ "${UI_ICON_TIER:-unicode}" == "ascii" ]] && S_DASH='-'
  # Strelkalar ham POG'ONADAN olinadi: ascii terminalda '↑↓' o'rniga '^v'
  # chiqadi (ilgari bu yerda literal unicode turardi va ascii pog'onasida
  # buzuq belgi bo'lib ko'rinardi).
  ui_footer_str_v S_FOOT "${ICO[updown]}=$(t 'harakat')" "${ICO[enter]}=$(t 'ishga tushirish')" \
                         "a-z=$(t 'qidirish')" "esc=$(t 'chiqish')"

  # Status bar uchun statik maydonlar (tanlovga bog'liq emas).
  local _ins=0 _tot=0 _k
  for _k in "${!r_st[@]}"; do
    _tot=$(( _tot + 1 ))
    [[ "${r_st[_k]}" == "installed" ]] && _ins=$(( _ins + 1 ))
  done
  AGENT_COUNT="$(t '%s/%s o'\''rnatilgan' "$_ins" "$_tot")"
  S_VER="$(status_version_field)"
  S_LAT="$(status_latency_field)"

  # Provayder → muhit o'zgaruvchisi jadvallari. `$(provider_model_var ...)`
  # klavish tsiklida fork bo'lardi — shuning uchun oldindan jadvalga olamiz.
  local -A PROV_MV=() PROV_KV=()
  local _p
  for _k in "${!r_prov[@]}"; do
    _p="${r_prov[_k]}"
    [[ -n "$_p" && -z "${PROV_MV[$_p]+x}" ]] || continue
    PROV_MV[$_p]="$(provider_model_var "$_p")"
    PROV_KV[$_p]="$(provider_key_var "$_p")"
  done

  # ================= CHAP USTUN QATORLARINI OLDINDAN QURISH ================
  # build_menu bergan qatorlar TO'LIQ enga mo'ljallangan (izoh bilan) — izoh
  # endi O'NG ustunda ko'rinadi. Shuning uchun chap ustun uchun IXCHAM
  # qatorlarni shu yerda quramiz: holat + nom + meta. Hammasi BIR MARTA.
  local -a lrow=()
  if (( two_col )); then
    local -A ucnt=()
    local _c _n
    if [[ -r "$STATS_FILE" ]]; then
      while IFS=$'\t' read -r _c _n; do
        [[ -n "$_n" ]] && ucnt["$_n"]="$_c"
      done <"$STATS_FILE"
    fi
    local lastn; lastn="$(read_last)"
    local nw=$(( lw - 12 )); (( nw < 10 )) && nw=10
    local ii jj ic meta nm cnt2 nmp
    for ii in "${!names[@]}"; do
      jj="${rowof[ii]:--1}"
      nm="${names[ii]}"
      if (( jj >= 0 )) && [[ "${r_st[jj]}" == "installed" ]]; then
        ic="${UI_OK}${ICO[dot_on]}${UI_R}"
      else
        ic="${UI_FAINT}${ICO[dot_off]}${UI_R}"
      fi
      # Meta zonasi — FAQAT foydalanuvchiga xos ma'lumot: "oxirgi ishlatilgan"
      # va ishlatish sanog'i. "Top/mashhur" yulduzchasi ATAYLAB yo'q: ro'yxat
      # allaqachon mashhurlik bo'yicha saralangan, ya'ni yulduz o'sha ma'noni
      # TAKRORLAydi — va ro'yxatning yarmida turib shovqin hosil qilardi.
      meta=""
      if [[ -n "$lastn" && "$nm" == "$lastn" ]]; then
        meta="${UI_AI}${ICO[last]}${UI_R}"
      fi
      cnt2="${ucnt[$nm]:-0}"
      [[ "$cnt2" =~ ^[0-9]+$ ]] || cnt2=0
      (( cnt2 > 0 )) && meta="${meta} ${UI_FAINT}${cnt2}×${UI_R}"
      ui_trunc_v nmp "$nm" "$nw"
      ui_pad_v nmp "${UI_TEXT}${nmp}${UI_R}" "$nw"
      ui_pad_v meta "$meta" 7
      lrow[ii]="${ic} ${nmp} ${meta}"
    done
  fi

  local cur=0 topv=0 query=""
  local -a vis=()

  # _af — joriy filtrga mos indekslar ro'yxatini (vis) quradi.
  # Kichik harfga o'tkazish SOF BASH (${q,,}) — ilgari `printf | tr` edi,
  # ya'ni har bosilgan harfda IKKI fork.
  _af() {
    vis=(); local q ii
    q="${query,,}"
    for ii in "${!names[@]}"; do
      if [[ -z "$q" ]]; then vis+=("$ii"); continue; fi
      case "${hay[ii]}" in *"$q"*) vis+=("$ii") ;; esac
    done
    (( cur >= ${#vis[@]} )) && cur=$(( ${#vis[@]} - 1 ))
    (( cur < 0 )) && cur=0
  }

  # _ad <menyu-indeksi> — tanlangan agent tafsilotini DETAIL[] ga yozadi.
  # Umumiy detail_lines() orqali — fzf preview ham AYNAN shundan chizadi,
  # shuning uchun ikkala interfeys bir xil ko'rinadi.
  _ad() {
    local mi="${1:--1}" dj=-1
    if [[ "$mi" =~ ^[0-9]+$ ]]; then dj="${rowof[mi]:--1}"; fi
    if (( dj < 0 )); then DETAIL=(); DETAIL_SEC=-1; return 0; fi
    detail_lines "${r_name[dj]}" "${r_desc[dj]}" "${r_bin[dj]}" "${r_cmd[dj]}" \
                 "${r_inst[dj]}" "${r_cat[dj]}" "${r_st[dj]}" "${r_auth[dj]}" \
                 "${r_url[dj]}" "${r_ac[dj]}" "${r_prov[dj]}" "$rw"
  }

  # _as <menyu-indeksi> — status bar satrini S_STATUS ga yozadi.
  # FAQAT haqiqiy ma'lumot: provayder agent konfiguratsiyasidan, model va
  # kalit holati MUHITDAN o'qiladi (Aidevix modelni o'zi tanlamaydi va
  # API'ga murojaat qilmaydi — o'zi o'lchay oladigan narsa yo'q), agentlar
  # sanog'i ro'yxatdan, versiya/yangilanish va latency keshlangan o'lchovdan.
  _as() {
    local mi="${1:--1}" dj=-1 prov="" mv="" kv="" model=""
    local f_prov="" f_model="" f_key=""
    if [[ "$mi" =~ ^[0-9]+$ ]]; then dj="${rowof[mi]:--1}"; fi
    (( dj >= 0 )) && prov="${r_prov[dj]}"

    if [[ -n "$prov" ]]; then
      f_prov="${UI_AI}${ICO[ai]} ${prov}${UI_R}"
      mv="${PROV_MV[$prov]:-}"
      [[ -n "$mv" ]] && model="${!mv:-}"
      if [[ -n "$model" ]]; then f_model="${UI_TEXT}${model}${UI_R}"
      else                       f_model="${UI_FAINT}${S_DASH}${UI_R}"; fi
      kv="${PROV_KV[$prov]:-}"
      if [[ -n "$kv" ]]; then
        if [[ -n "${!kv:-}" ]]; then f_key="${UI_OK}${ICO[dot_on]} ${S_KEY_SET}${UI_R}"
        else                         f_key="${UI_FAINT}${ICO[dot_off]} ${S_KEY_UNSET}${UI_R}"; fi
      fi
    fi
    ui_statusbar_str_v S_STATUS "$f_prov" "$f_model" "$f_key" \
      "${UI_MUTED}${AGENT_COUNT}${UI_R}" "$S_VER" "$S_LAT"
  }

  # _ar — butun ramkani chizadi. Alt-screen'da har safar tepadan (\033[H).
  # SOF BASH: statik matnlar tayyor, chap ustun qatorlari oldindan qurilgan,
  # tsikl ichida birorta ham `$(...)` YO'Q.
  _ar() {
    local nvis=${#vis[@]}
    (( cur < topv )) && topv=$cur
    (( cur >= topv + page )) && topv=$(( cur - page + 1 ))
    (( topv < 0 )) && topv=0
    local -a out=()

    # --- Sarlavha + qidiruv qatori ---
    out+=("  ${UI_BRAND}${UI_B}${ICO[brand]} Aidevix${UI_R}")
    out+=("  ${S_RULE}")
    local qline
    if [[ -n "$query" ]]; then
      qline="  ${UI_BRAND}${ICO[search]}${UI_R} ${UI_TEXT}${query}${UI_R}${UI_BRAND}_${UI_R}"
    else
      qline="  ${UI_FAINT}${ICO[search]} ${S_PROMPT}${UI_R}"
    fi
    if (( nvis > 0 )); then qline="${qline}   ${UI_FAINT}$((cur+1))/${nvis}${UI_R}"
    else                    qline="${qline}   ${UI_FAINT}0/${total}${UI_R}"; fi
    out+=("$qline")
    out+=("")

    # --- Tana ---
    if (( nvis > 0 )); then _ad "${vis[cur]}"; else DETAIL=(); DETAIL_SEC=-1; fi
    # Panelga nechta tafsilot qatori sig'adi — maketga qarab farq qiladi.
    if (( two_col )); then detail_clip "$body"
    else                   detail_clip $(( body - page - 1 )); fi

    local r vi oi left right lpad
    if (( two_col )); then
      for (( r = 0; r < body; r++ )); do
        left=""
        vi=$(( topv + r ))
        if (( r < page && vi < nvis )); then
          oi=${vis[vi]}
          if (( vi == cur )); then left="${UI_BRAND}${ICO[arrow]}${UI_R} ${lrow[oi]}"
          else                     left="  ${lrow[oi]}"; fi
        elif (( r == 0 && nvis == 0 )); then
          left="  ${S_NOMATCH}"
        fi
        ui_pad_v lpad "$left" "$lw"
        right="${DETAIL[r]:-}"
        out+=("  ${lpad} ${S_SEP} ${right}")
      done
    else
      for (( r = 0; r < page; r++ )); do
        vi=$(( topv + r ))
        if (( vi < nvis )); then
          oi=${vis[vi]}
          if (( vi == cur )); then out+=("  ${UI_BRAND}${ICO[arrow]}${UI_R} ${displays[oi]}")
          else                     out+=("    ${displays[oi]}"); fi
        elif (( r == 0 && nvis == 0 )); then
          out+=("  ${S_NOMATCH}")
        else
          out+=("")
        fi
      done
      out+=("  ${S_RULE}")
      local dr
      for (( r = 0; r < body - page - 1; r++ )); do
        dr="${DETAIL[r]:-}"
        if [[ -n "$dr" ]]; then out+=("  ${dr}"); else out+=(""); fi
      done
    fi

    # --- Pastki blok: chiziq + status bar + footer ---
    out+=("  ${S_RULE}")
    if (( nvis > 0 )); then _as "${vis[cur]}"; else S_STATUS="  ${UI_FAINT}${S_DASH}${UI_R}"; fi
    out+=("$S_STATUS")
    out+=("$S_FOOT")

    # UI_DUMP rejimida ramka STDOUT'ga, kursor boshqaruvisiz chiziladi —
    # shunda maketni TTY'siz (testda) tekshirib bo'ladi.
    if [[ -n "${AIDEVIX_UI_DUMP:-}" ]]; then
      local L
      for L in "${out[@]}"; do printf '%s\n' "$L"; done
      return 0
    fi
    # BITTA yozuv (write) bilan chizamiz. Ilgari har qator ALOHIDA printf bilan
    # ketardi — ya'ni bitta kadr = 25-30 ta write(). Windows konsolida terminal
    # har bo'lakni DARHOL chizadi, natijada strelka bilan yurganda ro'yxat
    # "qatorma-qator qayta chizilayotgandek" miltillardi. Endi butun kadr
    # buferga yig'iladi va bir marta yuboriladi.
    #
    # \033[?2026h/l — SINXRON CHIQISH (DECSET 2026): terminal kadr to'liq
    # kelmaguncha ekranni yangilamaydi, ya'ni yarim chizilgan holat ko'rinmaydi.
    # Rejimni bilmaydigan terminal buni jimgina e'tiborsiz qoldiradi (zararsiz).
    # \033[J — kadr oxirida pastda qolgan eski qatorlarni tozalaydi (terminal
    # kichrayganda ular "arvoh" bo'lib qolardi).
    local L frame=$'\033[?2026h\033[H'
    for L in "${out[@]}"; do frame+=$'\r\033[K'"$L"$'\n'; done
    frame+=$'\033[J\033[?2026l'
    printf '%s' "$frame" >/dev/tty
  }

  # --- TEST SEAM: bitta kadrni chizib chiqish -------------------------------
  # AIDEVIX_UI_DUMP=1 — menyuni interaktiv ochmasdan, BIR kadrni stdout'ga
  # chizadi va qaytadi. Bats testlari maketni (ikki ustun, tekislash, status
  # bar) shu orqali tekshiradi; TTY/pty talab qilinmaydi.
  # AIDEVIX_UI_DUMP_QUERY bilan qidiruv holatini ham sinash mumkin.
  if [[ -n "${AIDEVIX_UI_DUMP:-}" ]]; then
    query="${AIDEVIX_UI_DUMP_QUERY:-}"
    _af
    _ar
    return 0
  fi

  # Interaktiv qism: `(( ... )) && ...` chegara tekshiruvlari shart YOLG'ON bo'lsa
  # 1 qaytaradi (masalan `(( cur < 0 ))` cur>=0 bo'lganda). errexit/ERR-trap yoqiq
  # bo'lsa bu funksiyani (yoki `_af`/`case` tarmog'ini) "xato" deb tugatadi. Bu
  # funksiya `$()` subshell'ida ishlaydi, shuning uchun ularni shu yerda o'chirsak
  # ota-shellga sizmaydi; menyu chegaralarini o'zimiz boshqaramiz.
  set +e
  trap - ERR

  # TTY'ni RAW-rejimga BIR MARTA o'tkazamiz: -echo (yozilgan ko'rinmasin), -icanon
  # (qatorlab emas, bayt-bayt), -icrnl (Enter \r bo'lib qolsin), min 1 time 0
  # (bloklovchi bayt o'qish). Bu — tsikldan tashqaridagi YAGONA tcsetattr:
  # MSYS konsolida setattr kutayotgan kiritishni o'chirib yuborgani uchun tsikl
  # ichida termios'ga boshqa TEGILMAYDI (qarang _rd). Har qanday chiqishda
  # (EXIT — bekor `exit 0` ham) eski holat tiklanadi.
  local _savedstty=""
  _savedstty="$(stty -g 2>/dev/null </dev/tty || true)"
  # _menu_restore — termios + ekran rejimlarini tiklaydi. Ikki tutqichda ham
  # ishlatiladi (idempotent).
  _menu_restore() {
    stty "$_savedstty" 2>/dev/null </dev/tty || true
    printf "\033[?2026l\033[?1007l\033[?25h\033[?7h\033[?1049l" 2>/dev/null >/dev/tty || true
  }
  trap '_menu_restore' EXIT
  # INT/TERM ALOHIDA kerak: bu funksiya `$(...)` qism-qobig'ida ishlaydi va
  # bash qism-qobiqda trap'larni DEFAULT'ga tiklaydi — ya'ni ota-jarayonning
  # INT tutqichi bu yerda ISHLAMAYDI, EXIT tutqichi esa SIGINT bilan
  # o'ldirilganda UMUMAN chaqirilmaydi. Natijada Ctrl+C dan keyin terminal
  # raw rejimda (echo'siz) qolib ketardi. 130 — Ctrl+C uchun to'g'ri kod;
  # run_menu uni ushlab, ota-jarayonni ham to'g'ri to'xtatadi.
  trap '_menu_restore; exit 130' INT TERM
  stty -echo -icanon -icrnl min 1 time 0 2>/dev/null </dev/tty || true

  # _rd <o'zgaruvchi> — TTY'dan BITTA bloklovchi read() bilan BO'LAKNI (chunk)
  # o'qiydi (dd bs=64 count=1; termios'ga tegmaydi).
  #
  # NEGA aynan BO'LAK? Haqiqiy Windows konsolida (conhost/Windows Terminal'dagi
  # Git Bash) o'tkazilgan tajribalar IKKITA qat'iy faktni ko'rsatdi:
  #   1) HAR QANDAY tcsetattr — `stty min/time` ham, bash `read -t/-n` ning
  #      ichki setattr'i ham — kutayotgan kiritish baytlarini O'CHIRIB yuboradi
  #      → timeout'li o'qish MUMKIN EMAS (v1.5.0–v1.7.2 dagi "har strelka =
  #      bekor" bug'ining ildizi shu edi);
  #   2) o'qilmagan "dum" baytlar o'qigan JARAYON bilan birga o'ladi (msys
  #      readahead per-process) → baytma-bayt alohida dd'lar ham MUMKIN EMAS.
  # Bitta read() esa klavish bilan birga kelgan BARCHA baytlarni birga qaytaradi
  # (probe: DOWN → $'\E[B', PgUp → $'\E[5~' — butunligicha): strelka hech qachon
  # bo'linmaydi ham, yo'qolmaydi ham. ESC'dan keyin bo'lakda bayt bo'lmasa —
  # bu chinakam YOLG'IZ ESC (bekor) — timersiz ham bir zumda aniqlanadi.
  _rd() { printf -v "$1" '%s' "$(dd bs=64 count=1 2>/dev/null </dev/tty)"; }

  # ALT-SCREEN'ga o'tamiz (\033[?1049h): menyu alohida ekranda chiziladi —
  # sichqoncha g'ildiragi terminal scrollback'ini siljitib ramkani buzmaydi.
  # \033[?1007h — "alternate scroll": g'ildirak aylanishi alt-screen'da ↑/↓
  # strelka baytlari bo'lib keladi (Windows Terminal/mintty/xterm) → g'ildirak
  # bilan scroll ISHLAYDI. Kursor yashirin, avto-o'rash o'chiq.
  printf '\033[?1049h\033[H\033[?1007h\033[?25l\033[?7l' >/dev/tty
  _af

  local key action selected="" cancelled=0
  local buf bi blen ch nx fin params more _g
  while :; do
    _ar
    # Barcha baytlar BITTA bloklovchi _rd (dd) bilan — tsiklda BITTA ham
    # tcsetattr yo'q (MSYS konsolida setattr kutayotgan baytlarni o'chirardi).
    buf=""; _rd buf
    if [[ -z "$buf" ]]; then
      cancelled=1; break                     # EOF — terminal/quvur yopildi
    fi

    # Bo'lakni BAYTMA-BAYT tahlil qilamiz. Bitta bo'lakda bir nechta klavisha
    # bo'lishi MUMKIN: g'ildirak tez aylanganda alternate-scroll ketma-ket
    # \033[A/\033[B yuboradi, tez yozganda/paste qilganda esa bir necha harf
    # birga keladi. Hammasini qayta ishlaymiz — aks holda bosilgan klavishalar
    # "yo'qoladi". Tahlil SOF BASH: bo'lak ichida qo'shimcha o'qish YO'Q.
    bi=0; blen=${#buf}
    while (( bi < blen )); do
      ch="${buf:bi:1}"; bi=$(( bi + 1 ))
      key="$ch"; action="char"

      if [[ "$ch" == $'\033' ]]; then
        if (( bi >= blen )); then
          # Bo'lak ESC bilan TUGADI. Ikki ehtimol: (a) chinakam yolg'iz ESC,
          # (b) strelka ketma-ketligi ikki read()ga BO'LINIB qolgan (sekin
          # SSH/pty da uchraydi; Windows konsolida esa birga keladi).
          # TIMEOUT ishlatib bo'lmaydi — tcsetattr MSYS'da kutayotgan baytlarni
          # o'chiradi (v1.5.0–v1.7.2 dagi "har strelka = bekor" bug'i shundan).
          # Shuning uchun BLOKLAB yana bir bo'lak o'qiymiz: strelkaning davomi
          # darhol keladi, chinakam yolg'iz ESC esa keyingi klavishagacha kutadi
          # — bu ekrandagi yo'riqnomaga mos: "q yoki 2×ESC = bekor".
          more=""; _rd more
          if [[ -z "$more" ]]; then
            action=cancel                     # EOF — davomi kelmadi
          else
            buf+="$more"; blen=${#buf}
            bi=$(( bi - 1 ))                  # ESC ni davomi bilan QAYTA tahlil qilamiz
            continue
          fi
        else
          nx="${buf:bi:1}"
          if [[ "$nx" == '[' || "$nx" == 'O' ]]; then
            bi=$(( bi + 1 ))
            # CSI/SS3: parametr baytlari (raqam, ';', '?') → yakuniy bayt (@..~).
            # Ketma-ketlik bo'lakka SIG'MAY qolsa (sekin pty da bo'linadi),
            # davomini BLOKLAB o'qiymiz — aks holda yakuniy bayt ('B' kabi)
            # keyingi bo'lakda ODDIY HARF bo'lib qidiruvga tushib ketardi.
            # `_g < 32` — buzuq ketma-ketlikda abadiy kutib qolmaslik uchun.
            params=""; fin=""; _g=0
            while (( _g < 32 )); do
              if (( bi >= blen )); then
                more=""; _rd more
                [[ -z "$more" ]] && break        # EOF — davomi kelmadi
                buf+="$more"; blen=${#buf}
              fi
              ch="${buf:bi:1}"; bi=$(( bi + 1 )); _g=$(( _g + 1 ))
              if [[ "$ch" == [@A-Za-z~] ]]; then fin="$ch"; break; fi
              params+="$ch"
            done
            case "$fin" in
              A) action=up ;;
              B) action=down ;;
              H) action=home ;;
              F) action=end ;;
              '~') case "$params" in
                     5)   action=pgup ;;
                     6)   action=pgdn ;;
                     1|7) action=home ;;
                     4|8) action=end ;;
                     *)   action=skip ;;
                   esac ;;
              # Qolgani (C/D o'ng-chap, F-klavishlar, Ctrl+strelka \033[1;5A,
              # Delete \033[3~, sichqoncha hodisalari) — menyuni YOPMAYMIZ,
              # shunchaki e'tiborsiz qoldiramiz.
              *) action=skip ;;
            esac
          elif [[ "$nx" == $'\033' ]]; then
            action=cancel                     # ESC-ESC = bekor
          else
            bi=$(( bi + 1 )); action=skip     # Alt+harf kabi — e'tiborsiz
          fi
        fi
      elif [[ "$ch" == $'\r' || "$ch" == $'\n' ]]; then action=enter
      elif [[ "$ch" == $'\177' || "$ch" == $'\b' ]]; then action=bs
      elif [[ "$ch" == $'\t' ]]; then action=down
      fi

      # `break 2` — ichki (bo'lak) tsiklidan ham, tashqi (klavisha) tsiklidan
      # ham chiqadi. `case` tsikl darajasi sifatida sanalmaydi.
      case "$action" in
        up)    (( cur > 0 )) && cur=$(( cur - 1 )) ;;
        down)  (( ${#vis[@]} > 0 && cur < ${#vis[@]} - 1 )) && cur=$(( cur + 1 )) ;;
        pgup)  cur=$(( cur - page )); (( cur < 0 )) && cur=0 ;;
        pgdn)  cur=$(( cur + page )); (( ${#vis[@]} > 0 && cur > ${#vis[@]} - 1 )) && cur=$(( ${#vis[@]} - 1 )); (( cur < 0 )) && cur=0 ;;
        home)  cur=0 ;;
        end)   cur=$(( ${#vis[@]} - 1 )); (( cur < 0 )) && cur=0 ;;
        enter) (( ${#vis[@]} > 0 )) && { selected="${names[${vis[cur]}]}"; break 2; } ;;
        bs)    [[ -n "$query" ]] && { query="${query%?}"; _af; } ;;
        skip)  : ;;                                  # notanish klavisha — e'tiborsiz
        cancel) cancelled=1; break 2 ;;
        char)
          case "$key" in
            q|Q) [[ -z "$query" ]] && { cancelled=1; break 2; }; query+="$key"; _af ;;
            *)   query+="$key"; _af ;;
          esac ;;
      esac
    done
  done

  # ALT-SCREEN'dan chiqamiz — asosiy ekran (banner va h.k.) o'z holicha qaytadi,
  # menyu izsiz yo'qoladi. TTY rejimi va kursor/o'rash tiklanadi.
  stty "$_savedstty" 2>/dev/null </dev/tty || true
  # \033[?2026l ENG OLDIN: agar terminal sinxron-chiqish rejimida qolib ketgan
  # bo'lsa (kadr chizilayotganda uzilish), qolgan tiklash ketma-ketligi umuman
  # ko'rinmaydi. Shuning uchun avval rejimni yopamiz, keyin qolganini tiklaymiz.
  printf '\033[?2026l\033[?1007l\033[?25h\033[?7h\033[?1049l' >/dev/tty

  if (( cancelled )); then
    log_info "$(t 'Bekor qilindi.')"
    exit 0
  fi
  printf '%s' "$selected"
}

# --- Interaktiv menyu -----------------------------------------------------
run_menu() {
  local filter="${1:-}"
  AIDEVIX_PHASE="menu"
  # Termios'ni menyu RAW rejimga o'tishdan OLDIN saqlab qo'yamiz — Ctrl+C
  # qism-qobiqni o'ldirsa ham ota-jarayondagi cleanup uni tiklay oladi.
  save_tty_state

  # Ilk ishga tushishda tilni so'raymiz (keyin saqlangan tildan foydalanamiz).
  choose_language

  # Brend: ILK ishga tushishda to'liq blok, keyin ixcham sarlavha (BANNER_SEEN_FILE).
  case "$filter" in
    free) banner "Aidevix" "$(t 'bepul agentlar — login/kalitsiz yoki bepul tier')" ;;
    top)  banner "Aidevix" "$(t 'eng mashhur agentlar')" ;;
    *)    banner "Aidevix" ;;
  esac

  # Aidevix nima/nima emasligini ilk safar tushuntiramiz (chalkashlikка qarshi).
  maybe_show_intro

  local config; config="$(resolve_config)"
  ui_spin_start "$(t 'Agentlar tekshirilmoqda…')"
  local rows; rows="$(build_rows "$config")"
  ui_spin_stop

  # --free / --top filtrlari (agar so'ralgan bo'lsa).
  case "$filter" in
    free)
      # 10-maydon — parse bosqichida hisoblangan AUTHCLASS. Ilgari bu yerda
      # xom emoji naqshi tekshirilardi; endi semantik maydon (emoji ham,
      # matn ham classify_auth ichida bir joyda tushuniladi).
      rows="$(awk -F'\t' '$10 == "free"' <<<"$rows")"
      [[ -n "$rows" ]] || { log_info "$(t 'Bepul agent topilmadi.')"; exit 0; }
      ;;
    top)
      rows="$(awk -F'\t' -v tops=" $TOP_AGENTS " \
              'index(tops, " " $3 " ") > 0' <<<"$rows")"
      [[ -n "$rows" ]] || { log_info "$(t 'Top agent topilmadi.')"; exit 0; }
      ;;
  esac

  # Global statistika (opt-in): keshni fonda yangilab qo'yamiz (keyingi safar
  # uchun) va joriy keshdan reytingni menyuga qo'shamiz. Bir martalik eslatma.
  maybe_global_hint
  fetch_global_stats
  local globalfile=""
  if global_stats_enabled; then
    globalfile="$(mktemp)"; TMPFILES+=("$globalfile")
    global_install_tsv >"$globalfile" 2>/dev/null || true
  fi

  ui_spin_start "$(t 'Menyu tayyorlanmoqda…')"
  # Oxirgi ishlatilgan agent menyuda eng tepada turadi (bir ENTER bilan qayta ochish).
  local lastname; lastname="$(read_last)"
  local menu; menu="$(build_menu "$rows" "$STATS_FILE" "$globalfile" "$lastname")"
  ui_spin_stop

  local name="" datafile rc=0
  datafile="$(mktemp)"; TMPFILES+=("$datafile")
  printf '%s\n' "$rows" >"$datafile"
  # --- Qaysi interfeys? -----------------------------------------------------
  # STANDART — ichki ↑/↓ menyu. Sabab: ikki ustunli maket, status bar va
  # klavish footer'i FAQAT o'shanda bor. fzf'da pastki qatorni umuman chizib
  # bo'lmaydi (`--footer` yo'q, faqat `--header`), Windows'da esa preview ham
  # standart o'chiq (cygwin fork xatolari) — natijada fzf o'rnatilgan
  # foydalanuvchi TEKIS RO'YXAT ko'rardi va butun redizaynni umuman
  # ko'rmasdi. fzf'ni afzal ko'rganlar uchun: AIDEVIX_USE_FZF=1.
  local use_fzf=0
  if [[ -n "${AIDEVIX_USE_FZF:-}" && -z "${AIDEVIX_NO_FZF:-}" ]] \
     && command -v fzf >/dev/null 2>&1; then
    use_fzf=1
  fi

  if (( use_fzf )); then
    name="$(select_with_fzf "$menu" "$datafile")" || rc=$?
    if [[ "$rc" -eq 3 ]]; then
      # fzf ishga tushmadi (eski versiya / TTY muammosi) — ichki menyuga o'tamiz.
      log_warn "$(t "fzf ishga tushmadi — ichki menyu ishlatilmoqda.")"
      rc=0
      if { : >/dev/tty; } 2>/dev/null; then
        name="$(select_with_arrows "$menu" "$datafile")" || rc=$?
        if (( rc == 2 )); then
          log_warn "$(t "Interaktiv menyu ochilmadi — raqamli menyuga o'tildi.")"
          rc=0; name="$(select_with_numbers "$menu")"
        fi
      else
        name="$(select_with_numbers "$menu")"
      fi
    elif [[ "$rc" -ne 0 ]]; then
      exit "$rc"
    fi
  elif { : >/dev/tty; } 2>/dev/null; then
    # TTY bor — ichki ↑/↓ menyu (ikki ustun + status bar + footer).
    name="$(select_with_arrows "$menu" "$datafile")" || rc=$?
    if (( rc == 2 )); then
      # Ichki menyu ochilmadi. fzf bo'lsa — o'shanga, bo'lmasa raqamli menyuga.
      rc=0
      if command -v fzf >/dev/null 2>&1; then
        log_warn "$(t "Interaktiv menyu ochilmadi — fzf ishlatilmoqda.")"
        name="$(select_with_fzf "$menu" "$datafile")" || rc=$?
        if (( rc == 3 )); then
          rc=0; name="$(select_with_numbers "$menu")"
        elif (( rc != 0 )); then
          exit "$rc"
        fi
      else
        log_warn "$(t "Interaktiv menyu ochilmadi — raqamli menyuga o'tildi.")"
        name="$(select_with_numbers "$menu")"
      fi
    elif (( rc == 130 )); then
      exit 130                                 # Ctrl+C — menyu o'zi tozalagan
    fi
  else
    # TTY yo'q (quvur/CI) — oddiy raqamli menyu (stdin'dan o'qiydi).
    name="$(select_with_numbers "$menu")"
  fi

  # Bekor qilingan/tanlanmagan bo'lsa — jim chiqamiz (ortiqcha "topilmadi" xatosi yo'q).
  # Eslatma: tanlovchilar `exit 0` ni $(...) ichida bajaradi (faqat qism-jarayonni
  # to'xtatadi), shuning uchun bo'sh nomni shu yerda bekor sifatida tutamiz.
  [[ -n "$name" ]] || exit 0
  launch_selected "$rows" "$name"
}

# --- Per-agent yangilash stamp'ini yangilash ------------------------------
# <nom>ni xavfsiz fayl nomiga aylantirib, joriy vaqtni yozadi. Shu orqali keyingi
# ishga tushishlarda throttle hisoblanadi (xato bo'lsa ham — qayta-qayta urinmaslik).
touch_agent_update_stamp() {
  local name="$1" safe now
  safe="$(printf '%s' "$name" | tr -c 'A-Za-z0-9._-' '_')"
  now="$(date +%s 2>/dev/null || echo 0)"
  mkdir -p "$AGENT_UPDATE_DIR" 2>/dev/null || return 0
  printf '%s\n' "$now" >"$AGENT_UPDATE_DIR/$safe" 2>/dev/null || true
}

# --- O'rnatilgan agentni eng so'nggi versiyaga avtomatik yangilash ---------
# ALLAQACHON o'rnatilgan agent eskirib qolishi mumkin (masalan eski Gemini CLI
# "client no longer supported" deydi). Shu sababli ishga tushirishdan oldin,
# oraliqda BIR MARTA (throttled), `@latest`/`--upgrade`ga yangilaymiz.
# Faqat qayta ishga tushirilganda haqiqatan yangilaydigan o'rnatuvchilar uchun
# (npm @latest, pip --upgrade, curl/wget skript). brew/cargo o'tkazib yuboriladi
# (qayta `install` ularni yangilamaydi). Xato — bloklamaydi: ishga tushaveramiz.
# O'chirish: AIDEVIX_NO_AUTOUPDATE=1 yoki CI=1.
maybe_autoupdate_agent() {
  local name="$1" binary="$2" install="$3"
  [[ -n "${AIDEVIX_NO_AUTOUPDATE:-}" || -n "${CI:-}" ]] && return 0
  [[ -n "$install" ]] || return 0
  command -v "$binary" >/dev/null 2>&1 || return 0   # o'rnatilmagan — ensure_installed hal qiladi
  # Qayta ishga tushirilganda haqiqatan "latest"ga olib keladiganlar. curl/wget
  # skriptlari ATAYLAB chiqarilgan: ular har safar BUTUN installer'ni qayta
  # yuklab-o'rnatardi — sekin internetda ishga tushish oldidan uzoq kutish,
  # userga esa "yana o'rnatyapti" bo'lib ko'rinardi.
  case "$install" in
    *@latest*|*--upgrade*) : ;;
    *) return 0 ;;
  esac

  local interval now last safe stamp
  interval="${AIDEVIX_UPDATE_INTERVAL:-10800}"
  now="$(date +%s 2>/dev/null || echo 0)"
  safe="$(printf '%s' "$name" | tr -c 'A-Za-z0-9._-' '_')"
  stamp="$AGENT_UPDATE_DIR/$safe"
  if [[ -r "$stamp" ]]; then
    last="$(cat "$stamp" 2>/dev/null || echo 0)"; [[ "$last" =~ ^[0-9]+$ ]] || last=0
    (( now - last < interval )) && return 0
  fi
  # Urinishni OLDIN belgilab qo'yamiz — xato bo'lsa ham keyingi ishga tushishda
  # qayta-qayta urinmaymiz (oraliq tugaguncha).
  touch_agent_update_stamp "$name"

  install="$(resolve_install_cmd "$install")"
  trap - ERR
  spin_run "$(t "🔄 '%s' eng so'nggi versiyaga yangilanmoqda" "$name")" "$install" || true
  rm -f "${SPIN_LOG:-}" 2>/dev/null || true
  trap 'crash "$BASH_COMMAND" "$LINENO"' ERR
  augment_tool_path                                  # yangi binar joyini PATH'ga
  return 0
}

# --- Tanlangan agentni ishga tushirish ------------------------------------
launch_selected() {
  local rows="$1" name="$2"
  local row binary command install auth url
  row="$(awk -F'\t' -v n="$name" '$1 == n { print; exit }' <<<"$rows")"
  [[ -n "$row" ]] || die 1 "$(t 'Tanlangan agent topilmadi: %s' "$name")"

  binary="$(printf '%s'  "$row" | cut -f3)"
  command="$(printf '%s' "$row" | cut -f4)"
  install="$(printf '%s' "$row" | cut -f5)"
  auth="$(printf '%s'    "$row" | cut -f8)"
  url="$(printf '%s'     "$row" | cut -f9)"

  save_last "$name"
  ensure_installed "$name" "$binary" "$install"
  maybe_autoupdate_agent "$name" "$binary" "$install"
  maybe_show_auth_note "$name" "$auth" "$url"
  # Statistika: faqat haqiqatan ishga tushganda (o'rnatish muvaffaqiyatli,
  # bekor qilinmagan). Lokal — har doim; global — faqat opt-in yoqilgan bo'lsa.
  record_usage "$name"
  report_usage_global "$name" "launch"
  launch_agent "$name" "$binary" "$command"
}

# --- Tezkor ishga tushirish: `aidevix <nom-yoki-binary>` ------------------
quick_launch() {
  local query="$1"
  local config; config="$(resolve_config)"
  local rows; rows="$(build_rows "$config")"

  local name
  # 1) Nom yoki binar bo'yicha aniq moslik (katta-kichik harf farqsiz).
  name="$(awk -F'\t' -v q="$query" 'BEGIN{ql=tolower(q)}
            tolower($1)==ql || tolower($3)==ql { print $1; exit }' <<<"$rows")"
  # 2) Bo'lmasa — qisman moslik.
  if [[ -z "$name" ]]; then
    name="$(awk -F'\t' -v q="$query" 'BEGIN{ql=tolower(q)}
              index(tolower($1),ql) || index(tolower($3),ql) { print $1; exit }' <<<"$rows")"
  fi
  [[ -n "$name" ]] || die 2 "$(t "Mos agent topilmadi: '%s'. Ro'yxat uchun: aidevix --list" "$query")"

  launch_selected "$rows" "$name"
}

# --- CLI mavjudligini ta'minlash (kerak bo'lsa avtomatik o'rnatish) -------
ensure_installed() {
  AIDEVIX_PHASE="install"
  local name="$1" binary="$2" install="$3"

  command -v "$binary" >/dev/null 2>&1 && return 0
  # PATH'da yo'q — lekin OLDIN o'rnatilgan bo'lishi mumkin (o'rnatuvchi PATH'ni
  # faqat rc faylga yozgan). Ma'lum joylardan qidiramiz; topilsa qayta o'rnatish
  # SO'RALMAYDI — papka PATH'ga qo'shilib keshlanadi.
  if locate_binary "$binary"; then return 0; fi

  log_warn "$(t "Agent topilmadi: '%s' (kerakli buyruq: '%s')." "$name" "$binary")"
  if [[ -z "$install" ]]; then
    die 127 "$(t "Avtomatik o'rnatish buyrug'i belgilanmagan. Iltimos, '%s'ni qo'lda o'rnating." "$name")"
  fi

  # Buyruqni muhitga moslaymiz (masalan Windows'da python3 stub → python).
  install="$(resolve_install_cmd "$install")"
  log_info "$(t "O'rnatish buyrug'i: %s" "$install")"
  
  local ans="" prompt
  # Agar agent rasmiy repo configda bo'lmasa, u 3-tomon modifikasiyasi: xavfsizlik u-n ogohlantiramiz.
  if [[ -r "$REPO_CONFIG" ]] && ! awk -F'|' -v n="$name" '$1 == n { found=1; exit } END { exit !found }' "$REPO_CONFIG"; then
    log_warn "$(t "DIQQAT: Bu Uchinchi-tomon agenti!")"
    log_warn "$(t "Ushbu agent (%s) rasmiy aidevix ro'yxatida yo'q va uning o'rnatish skripti tekshirilmagan." "$name")"
    prompt="$(t "❓ '%s' baribir o'rnatilsinmi? (Xatar o'z zimmangizda) [y/N] " "$name")"
  else
    prompt="$(t "❓ '%s' hozir o'rnatilsinmi? [y/N] " "$name")"
  fi
  # Javobni avval /dev/tty'dan o'qishga urinamiz (fzf stdin'ni band qilgan
  # bo'lishi mumkin), bo'lmasa oddiy stdin'ga qaytamiz. Device xatosi ERR
  # tutqichini ishga tushirmasligi uchun tutqichni vaqtincha o'chiramiz.
  trap - ERR
  if { : >/dev/tty; } 2>/dev/null; then
    printf '%s' "$prompt" >/dev/tty
    IFS= read -r ans </dev/tty || ans=""
  else
    printf '%s' "$prompt" >&2
    IFS= read -r ans || ans=""
  fi
  trap 'crash "$BASH_COMMAND" "$LINENO"' ERR

  if [[ ! "$ans" =~ ^[Yy]$ ]]; then
    die 127 "$(t "Bekor qilindi. '%s'ni qo'lda o'rnatish uchun: %s" "$name" "$install")"
  fi

  # O'rnatishdan OLDIN: kerakli dastur (npm/python3/curl...) bormi? Yo'q bo'lsa
  # foydalanuvchiga nima yetishmayotganini SODDA tilda aytamiz. python/python3
  # uchun BORLIGI yetmaydi — Windows Store stub'i emasligini ham tekshiramiz
  # (stub `-c` buyrug'ini bajara olmaydi).
  local tool tool_missing=0; tool="$(detect_install_tool "$install")"
  if [[ -n "$tool" ]]; then
    if ! command -v "$tool" >/dev/null 2>&1; then
      tool_missing=1
    elif [[ "$tool" == python* ]] && ! "$tool" -c 'import sys' >/dev/null 2>&1; then
      tool_missing=1
    fi
  fi
  if [[ "$tool_missing" -eq 1 ]]; then
    ui_notice err "$(t "❌ '%s' o'rnatilmadi — avval bitta dastur kerak" "$name")" \
      "$(t "'%s'ni o'rnatish uchun kompyuteringizda \"%s\" bo'lishi shart," "$name" "$tool")" \
      "$(t 'lekin u topilmadi.')" \
      "" \
      "👉 $(tool_hint "$tool")" \
      "" \
      "$(t 'Shuni o'\''rnatib, terminalni qayta oching va yana "aidevix" deb yozing.')"
    die 127 "$(t "'%s' topilmadi — '%s' o'rnatilmadi." "$tool" "$name")"
  fi

  # ERR tutqichini vaqtincha o'chirib, o'rnatish xatosini o'zimiz ushlaymiz.
  trap - ERR
  if ! spin_run "$(t "📦 '%s' o'rnatilmoqda" "$name")" "$install"; then
    local tail_lines="" log_text=""
    if [[ -r "${SPIN_LOG:-}" ]]; then
      tail_lines="$(tail -n 6 "$SPIN_LOG" 2>/dev/null || true)"
      log_text="$(cat "$SPIN_LOG" 2>/dev/null || true)"
    fi
    trap 'crash "$BASH_COMMAND" "$LINENO"' ERR

    # O'rnatuvchi "bu OS qo'llab-quvvatlanmaydi" desa — adashtiruvchi (internet/
    # sudo/curl) sabablar o'rniga halol, aniq xabar beramiz.
    if printf '%s' "$log_text" | grep -qiE 'unsupported (operating system|os|platform|architecture)|not supported|no (prebuilt|pre-built|binary)|MINGW|MSYS|windows is not'; then
      ui_notice err "$(t "🚫 '%s' bu operatsion tizimda qo'llab-quvvatlanmaydi" "$name")" \
        "$(t "'%s' o'rnatuvchisi sizning tizimingizni (Windows / Git Bash —" "$name")" \
        "$(t 'MINGW64) qo'\''llab-quvvatlamasligini aytdi. Bu — internet yoki ruxsat')" \
        "$(t "muammosi EMAS; shunchaki bu agentning Windows uchun o'rnatuvchisi yo'q.")" \
        "" \
        "$(t '👉 Variantlar:')" \
        "$(t '  • Boshqa agentni tanlang (masalan Claude Code, Gemini, Aider — ular')" \
        "$(t "    Windows'da ishlaydi).")" \
        "$(t "  • Yoki '%s'ni WSL (Windows Subsystem for Linux) ichida ishlating." "$name")" \
        "$(t '  • Agent rasmiy sahifasida Windows uchun yo'\''l bor-yo'\''qligini tekshiring.')"
      if [[ -n "$tail_lines" ]]; then
        printf '%s  %s%s\n' "$C_GRAY" "$(t 'Xato tafsiloti (oxirgi qatorlar):')" "$C_RESET" >&2
        printf '%s\n' "$tail_lines" | sed 's/^/    /' >&2
        printf '\n' >&2
      fi
      rm -f "${SPIN_LOG:-}" 2>/dev/null || true
      die 127 "$(t "'%s' bu OS'da qo'llab-quvvatlanmaydi." "$name")"
    fi

    # TLS/sertifikat "hali yaroqli emas" / "muddati o'tgan" → deyarli har doim
    # tizim SOATI noto'g'ri (orqada yoki oldinda). Internet emas — soatni tuzatish.
    if printf '%s' "$log_text" | grep -qiE 'certificate is not yet valid|cert(ificate)? .*not yet valid|not yet valid|certificate has expired|cert(ificate)? .*expired|CERT_NOT_YET_VALID|ERR_CERT_DATE_INVALID|date.*invalid'; then
      ui_notice err "$(t "🕒 '%s' o'rnatilmadi — kompyuter soati noto'g'ri ko'rinadi" "$name")" \
        "$(t "Yuklab oluvchi xavfsizlik sertifikatini rad etdi: \"sertifikat hali")" \
        "$(t 'yaroqli emas" (yoki muddati o'\''tgan). Bu — internet muammosi EMAS;')" \
        "$(t "deyarli har doim kompyuteringizning SANA/VAQTI noto'g'ri o'rnatilgan.")" \
        "" \
        "$(t '👉 Yechimi:')" \
        "$(t '  • Kompyuter sana va vaqtini to'\''g'\''ri o'\''rnating (vaqt mintaqasi ham).')" \
        "$(t '  • Windows: Sozlamalar → Vaqt va til → "Vaqtni avtomatik o'\''rnatish".')" \
        "$(t '  • macOS/Linux: vaqtni avtomatik sinxronlashni (NTP) yoqing.')" \
        "$(t '  • So'\''ng terminalni qayta oching va yana urinib ko'\''ring.')"
      if [[ -n "$tail_lines" ]]; then
        printf '%s  %s%s\n' "$C_GRAY" "$(t 'Xato tafsiloti (oxirgi qatorlar):')" "$C_RESET" >&2
        printf '%s\n' "$tail_lines" | sed 's/^/    /' >&2
        printf '\n' >&2
      fi
      rm -f "${SPIN_LOG:-}" 2>/dev/null || true
      die 1 "$(t "'%s' o'rnatilmadi — kompyuter soatini tekshiring." "$name")"
    fi

    ui_notice err "$(t "❌ '%s' o'rnatishda xatolik yuz berdi" "$name")" \
      "$(t 'Quyidagi buyruq muvaffaqiyatsiz tugadi:')" \
      "    $install" \
      "" \
      "$(t "Ko'pincha sabab quyidagilardan biri bo'ladi:")" \
      "$(t '  1) 🌐 Internet yo'\''q yoki sekin — Wi-Fi/ulanishni tekshiring.')" \
      "$(t '  2) 🔒 Ruxsat yetarli emas — buyruqni "sudo" bilan sinab ko'\''ring.')" \
      "$(t '  3) 📦 "%s" eski — uni yangilab, qaytadan urinib ko'\''ring.' "${tool:-$(t dastur)}")" \
      "" \
      "$(t '👉 Aniq sababni ko'\''rish uchun yuqoridagi buyruqni terminalga o'\''zingiz')" \
      "$(t '   nusxalab ishga tushiring — xato matni to'\''liq ko'\''rinadi.')"
    if [[ -n "$tail_lines" ]]; then
      printf '%s  %s%s\n' "$C_GRAY" "$(t 'Xato tafsiloti (oxirgi qatorlar):')" "$C_RESET" >&2
      printf '%s\n' "$tail_lines" | sed 's/^/    /' >&2
      printf '\n' >&2
    fi
    rm -f "${SPIN_LOG:-}" 2>/dev/null || true
    die 1 "$(t "O'rnatish muvaffaqiyatsiz tugadi: %s." "$name")"
  fi
  rm -f "${SPIN_LOG:-}" 2>/dev/null || true
  trap 'crash "$BASH_COMMAND" "$LINENO"' ERR

  # O'rnatish yangi bin papkasi yaratgan bo'lishi mumkin — PATH'ni qayta
  # boyitamiz va hash'ni tozalaymiz, shunda binar joriy sessiyada ko'rinadi.
  augment_tool_path

  # Hali ham ko'rinmasa — o'rnatuvchi binarni O'Z papkasiga qo'ygan bo'lishi
  # mumkin; ma'lum joylardan qidirib, topilsa PATH'ga qo'shamiz va keshlaymiz
  # (o'rnatish MUVAFFAQIYATLI bo'lgan holda "terminalni qayta oching" deb
  # to'xtash — userga qayta-o'rnatish aylanasi bo'lib tuyulardi).
  if ! command -v "$binary" >/dev/null 2>&1; then
    locate_binary "$binary" || true
  fi

  if ! command -v "$binary" >/dev/null 2>&1; then
    ui_notice warn "$(t "⚠️  '%s' o'rnatildi, lekin hali ishga tushmadi" "$name")" \
      "$(t 'Dastur o'\''rnatildi, biroq tizim "%s" buyrug'\''ini hali topa olmayapti.' "$binary")" \
      "$(t 'Bu odatda "PATH" sozlamasi yangilanmagani uchun bo'\''ladi.')" \
      "" \
      "$(t '👉 Yechimi oson: terminalni butunlay yopib, qaytadan oching,')" \
      "$(t '   so'\''ng yana "aidevix" deb yozing — endi ishlaydi.')" \
      "" \
      "$(t 'Agar shunda ham yordam bermasa: "aidevix --doctor" buyrug'\''i muammoni ko'\''rsatadi.')"
    die 127 "$(t "'%s' hali PATH'da ko'rinmayapti — terminalni qayta oching." "$binary")"
  fi
  log_success "$(t "O'rnatildi: %s" "$name")"
  # Endigina (latest) o'rnatildi — darhol qayta yangilanmasligi uchun stamp'ni yozamiz.
  touch_agent_update_stamp "$name"
  report_usage_global "$name" "install"
}

# --- Agentni ishga tushirish ----------------------------------------------
launch_agent() {
  AIDEVIX_PHASE="launch"
  local name="$1" binary="$2" command="$3"
  ui_launch "$name"
  trap - ERR
  cleanup
  # shellcheck disable=SC2086
  exec $command
}

# --- O'rnatilgan agentlarni yangilash -------------------------------------
update_agents() {
  local config; config="$(resolve_config)"
  log_info "$(t 'Konfiguratsiya: %s' "$config")"
  local rows; rows="$(build_rows "$config")"
  local name desc binary command install category status auth url
  local checked=0 ok=0 fail=0

  while IFS=$'\037' read -r name desc binary command install category status auth url; do
    command -v "$binary" >/dev/null 2>&1 || continue
    checked=$((checked + 1))
    if [[ -z "$install" ]]; then
      log_warn "$(t "%s: o'rnatish buyrug'i yo'q — o'tkazib yuborildi." "$name")"
      continue
    fi
    install="$(resolve_install_cmd "$install")"
    trap - ERR
    if spin_run "$(t '🔄 %s yangilanmoqda' "$name")" "$install"; then
      ok=$((ok + 1))
    else
      fail=$((fail + 1))
    fi
    rm -f "${SPIN_LOG:-}" 2>/dev/null || true
    trap 'crash "$BASH_COMMAND" "$LINENO"' ERR
  done < <(printf '%s\n' "$rows" | tr '\t' '\037')

  if [[ "$checked" -eq 0 ]]; then
    log_warn "$(t "O'rnatilgan agent topilmadi — yangilash uchun avval agent o'rnating.")"
  else
    log_success "$(t 'Yangilash tugadi: %s ta muvaffaqiyatli, %s ta xato (jami %s).' "$ok" "$fail" "$checked")"
  fi
}

# --- Muhit tashxisi (doctor) ----------------------------------------------
doctor() {
  # shellcheck disable=SC2034  # lib/ui.sh funksiyalari UI_FD ni dinamik o'qiydi
  local UI_FD=1                     # tashxis — ma'lumot, stdout'ga chiqadi
  local w; w="$(ui_width)"
  ui_header "${UI_MUTED}$(t 'tashxis')${UI_R}"

  # d_row <ok|warn|err|off> <yorliq> <qiymat> — tashxisning YAGONA qator
  # shakli. Ilgali har blok o'z printf'ini yozardi va belgilar/otступlar
  # bir-biriga to'g'ri kelmasdi.
  d_row() {
    local kind="$1" label="$2" value="${3:-}" ic c
    case "$kind" in
      ok)   c="$UI_OK";    ic="${ICO[dot_on]}"  ;;
      warn) c="$UI_WARN";  ic="${ICO[warn]}"    ;;
      err)  c="$UI_ERR";   ic="${ICO[dot_off]}" ;;
      *)    c="$UI_FAINT"; ic="${ICO[bullet]}"  ;;
    esac
    printf '  %s%s%s %s %s%s%s\n' "$c" "$ic" "$UI_R" \
      "$(ui_pad "${UI_TEXT}${label}${UI_R}" 12)" "$UI_MUTED" "$value" "$UI_R"
  }
  d_section() { printf '\n  %s%s%s\n' "$UI_MUTED" "$1" "$UI_R"; }

  d_section "$(t 'Vositalar:')"
  local tool
  for tool in bash fzf node npm python3 curl git; do
    if command -v "$tool" >/dev/null 2>&1; then
      d_row ok "$tool" "$(command -v "$tool")"
    else
      d_row err "$tool" "$(t 'topilmadi')"
    fi
  done

  d_section "$(t 'PATH tekshiruvi:')"
  if command -v npm >/dev/null 2>&1; then
    local prefix bindir
    prefix="$(npm config get prefix 2>/dev/null || true)"
    d_row off "npm prefix" "${prefix:-$(t '(aniqlanmadi)')}"
    for bindir in "$prefix/bin" "$prefix"; do
      [[ -d "$bindir" ]] || continue
      if [[ ":$PATH:" == *":$bindir:"* ]]; then
        d_row ok "PATH" "$bindir"
      else
        d_row warn "PATH" "$(t "YO'Q: %s  (aidevix uni o'zi qo'shadi)" "$bindir")"
      fi
    done
  else
    d_row warn "npm" "$(t "npm topilmadi — npm orqali o'rnatiladigan agentlar ishlamaydi.")"
  fi
  if [[ -d "$HOME/.local/bin" ]]; then
    if [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
      d_row ok "PATH" "$HOME/.local/bin"
    else
      d_row warn "PATH" "$(t "YO'Q: %s" "$HOME/.local/bin")"
    fi
  fi

  # --- O'rnatish va yangilanish kanali --------------------------------------
  # NEGA BU BO'LIM BOR: "kimda yangilanadi, kimda yo'q" shikoyatining eng keng
  # tarqalgan sababi — BIR NECHTA o'rnatilgan nusxa. `npm i -g aidevix@latest`
  # BITTA nusxani yangilaydi, terminal esa PATH'da OLDINDA turgan BOSHQA
  # nusxani ishga tushiradi. Foydalanuvchi "yangiladim, lekin hech narsa
  # o'zgarmadi" deb o'ylaydi — aslida u yangilangan faylni umuman ishlatmayapti.
  # Shu bo'lim aynan shuni ko'zga tashlanadigan qilib ko'rsatadi.
  d_section "$(t "O'rnatish:")"

  # _shim_root <shim> — PATH'dagi `aidevix` fayli QAYSI o'rnatishga olib
  # borishini aniqlaydi (npm shim'i yoki bash wrapper'i ichidan yo'lni oladi).
  _shim_root() {
    local shim="$1" dir p
    dir="$(dirname "$shim")"
    if grep -q 'node_modules/aidevix' "$shim" 2>/dev/null \
       && [[ -d "$dir/node_modules/aidevix" ]]; then
      printf '%s' "$dir/node_modules/aidevix"; return 0
    fi
    p="$(grep -oE '/[^"'"'"' ]*/bin/ai-selector\.sh' "$shim" 2>/dev/null | head -1)"
    [[ -n "$p" ]] && { printf '%s' "${p%/bin/ai-selector.sh}"; return 0; }
    return 1
  }

  local chan
  if [[ -d "$PROJECT_ROOT/.git" ]]; then
    chan="$(t 'git — avtomatik yangilanadi')"
  elif is_npm_install; then
    chan="$(t 'npm — yangilash TAKLIF qilinadi')"
  else
    chan="$(t "qo'lda o'rnatilgan")"
  fi
  d_row ok "$(t 'versiya')" "$AIDEVIX_VERSION"
  d_row off "$(t 'ildiz')" "$PROJECT_ROOT"
  d_row off "$(t 'kanal')" "$chan"

  # PATH bo'yicha BARCHA nusxalarni sanab chiqamiz (tartib bilan).
  local -a seen=() found=()
  local pd shim root ver first_root=""
  local oldifs="$IFS"; IFS=':'
  # shellcheck disable=SC2206
  local -a pdirs=($PATH)
  IFS="$oldifs"
  for pd in "${pdirs[@]}"; do
    [[ -n "$pd" && -d "$pd" ]] || continue
    for shim in "$pd/aidevix" "$pd/aidevix.cmd"; do
      [[ -f "$shim" ]] || continue
      root="$(_shim_root "$shim" 2>/dev/null || true)"
      [[ -n "$root" ]] || continue
      # Bir ildizni ikki marta ko'rsatmaymiz (aidevix va aidevix.cmd bir joyga).
      local dup=0 s
      for s in ${seen[@]+"${seen[@]}"}; do [[ "$s" == "$root" ]] && dup=1; done
      (( dup )) && continue
      seen+=("$root")
      ver="$(tr -d ' \t\r\n' < "$root/VERSION" 2>/dev/null || true)"
      [[ -n "$ver" ]] || ver="$(t 'noma'\''lum')"
      [[ -z "$first_root" ]] && first_root="$root"
      if [[ "$root" == "$PROJECT_ROOT" ]]; then
        d_row ok "$(t 'nusxa')" "v$ver — $root  ← $(t 'hozir ishlayotgan')"
      else
        d_row warn "$(t 'nusxa')" "v$ver — $root"
      fi
      found+=("$root")
    done
  done

  # ENG MUHIM ogohlantirish: PATH'da BIRINCHI turgan nusxa ishlayotgani EMAS.
  if (( ${#found[@]} > 1 )); then
    d_row warn "$(t 'diqqat')" \
      "$(t "%s ta alohida o'rnatish topildi — yangilash chalkashligining asosiy sababi." "${#found[@]}")"
    if [[ -n "$first_root" && "$first_root" != "$PROJECT_ROOT" ]]; then
      d_row err "$(t 'nomuvofiq')" \
        "$(t "PATH'da BIRINCHI: %s — ya'ni 'aidevix' O'SHANI ishga tushiradi, buni emas." "$first_root")"
    fi
    d_row off "$(t 'yechim')" \
      "$(t "keraksiz nusxani olib tashlang: npm rm -g aidevix  yoki  rm -rf ~/.ai-cli")"
  fi

  # Yangilanish kanalining HOLATI — nega yangilanmayotganini ko'rsatadi.
  d_section "$(t 'Yangilanish holati:')"
  if [[ -d "$PROJECT_ROOT/.git" ]] && command -v git >/dev/null 2>&1; then
    # JIM QOTIL: commit qilinmagan bitta o'zgarish auto_update'ni BUTUNLAY
    # to'xtatadi (lokal ishni clobber qilmaslik uchun) — foydalanuvchi esa
    # nega yangilanmayotganini bilmaydi.
    if [[ -n "$(git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null)" ]]; then
      d_row err "auto-update" \
        "$(t "BLOKLANGAN: commit qilinmagan o'zgarishlar bor (git status).")"
    else
      d_row ok "auto-update" "$(t 'yoqilgan')"
    fi
  elif is_npm_install; then
    local cached="" age=""
    [[ -r "$NPM_LATEST_CACHE" ]] && cached="$(tr -d ' \t\r\n' < "$NPM_LATEST_CACHE" 2>/dev/null || true)"
    if [[ -n "$cached" ]]; then
      d_row off "$(t 'npm keshi')" "$(t "eng so'nggi: %s" "$cached")"
      version_gt "$cached" "$AIDEVIX_VERSION" \
        && d_row warn "$(t 'yangilash')" "npm i -g $NPM_PKG@latest" \
        || d_row ok "$(t 'holat')" "$(t "eng so'nggi")"
    else
      # Kesh FONDA to'ldiriladi — ya'ni ilk ishga tushishda hech narsa
      # ko'rsatilmaydi, yangi versiya KEYINGI safar bilinadi.
      d_row off "$(t 'npm keshi')" "$(t "hali yo'q — yangi versiya KEYINGI ishga tushishda bilinadi")"
    fi
    age="${AIDEVIX_UPDATE_INTERVAL:-10800}"
    d_row off "$(t 'tekshiruv')" "$(t "har %s sekundda (throttle)" "$age")"
  else
    d_row off "auto-update" "$(t "yo'q — qo'lda o'rnatilgan nusxa")"
  fi
  if [[ -n "${AIDEVIX_NO_AUTOUPDATE:-}" ]]; then
    d_row warn "auto-update" "$(t "AIDEVIX_NO_AUTOUPDATE=1 bilan O'CHIRILGAN")"
  fi

  d_section "$(t 'Interfeys:')"
  d_row off "$(t 'ikonkalar')" "${UI_ICON_TIER:-unicode}"
  d_row off "$(t 'ranglar')" "$UI_DEPTH"
  d_row off "$(t 'til')" "${AIDEVIX_LANG_RESOLVED:-uz}"
  d_row off "$(t 'eni')" "$w"

  d_section "$(t 'Global statistika:')"
  if global_stats_enabled; then
    d_row ok "$(t 'holat')" "$(t 'yoqilgan — server: %s' "$AIDEVIX_STATS_URL")"
    if [[ -r "$GLOBAL_CACHE" ]]; then
      d_row ok "$(t 'kesh')" "$GLOBAL_CACHE"
    else
      d_row warn "$(t 'kesh')" "$(t "hali yo'q (keyingi menyuda yangilanadi)")"
    fi
  else
    d_row off "$(t 'holat')" "$(t "o'chiq (opt-in). Yoqish: aidevix --stats on")"
  fi

  printf '\n'
  list_agents
}

# --- Interaktiv yangi agent qo'shish --------------------------------------
prompt_tty() {
  # prompt_tty <savol> <o'zgaruvchi-nomi>
  local q="$1" __var="$2" __val=""
  trap - ERR
  if { : >/dev/tty; } 2>/dev/null; then
    printf '%s' "$q" >/dev/tty
    IFS= read -r __val </dev/tty || __val=""
  else
    printf '%s' "$q" >&2
    IFS= read -r __val || __val=""
  fi
  trap 'crash "$BASH_COMMAND" "$LINENO"' ERR
  printf -v "$__var" '%s' "$__val"
}

add_agent() {
  printf '\n%s%s%s\n\n' "${C_BOLD:-}" "$(t '➕ Yangi agent qo'\''shish')" "${C_RESET:-}"
  local name binary command install desc category auth url
  prompt_tty "$(t 'Nom (masalan: My Agent)        : ')" name
  prompt_tty "$(t "Binary (PATH'dagi buyruq nomi) : ")" binary
  prompt_tty "$(t "Ishga tushirish buyrug'i       : ")" command
  prompt_tty "$(t "O'rnatish buyrug'i (ixtiyoriy) : ")" install
  prompt_tty "$(t 'Izoh (ixtiyoriy)               : ')" desc
  prompt_tty "$(t 'Kategoriya (ixtiyoriy)         : ')" category
  prompt_tty "$(t 'Login/kalit izohi (ixtiyoriy)  : ')" auth
  prompt_tty "$(t 'Login/hujjat havolasi (ixtiyoriy): ')" url

  name="$(trim "$name")"; binary="$(trim "$binary")"; command="$(trim "$command")"
  install="$(trim "$install")"; desc="$(trim "$desc")"; category="$(trim "$category")"
  auth="$(trim "$auth")"; url="$(trim "$url")"
  [[ -z "$command" ]] && command="$binary"
  [[ -z "$category" ]] && category="$DEFAULT_CATEGORY"

  if [[ -z "$name" || -z "$binary" ]]; then
    die 2 "$(t 'Nom va Binary majburiy. Bekor qilindi.')"
  fi
  if [[ "$name$binary$command$install$desc$category$auth$url" == *"|"* ]]; then
    die 2 "$(t "Maydonlar ichida '|' belgisi bo'lmasligi kerak. Bekor qilindi.")"
  fi

  # Foydalanuvchi configi — faqat QO'SHIMCHA agentlar (repo nusxalanmaydi, shunda
  # repo yangilanganda yangi agentlar avtomatik ko'rinadi). Bo'lmasa yaratamiz.
  mkdir -p "$(dirname "$USER_CONFIG")"
  if [[ ! -e "$USER_CONFIG" ]]; then
    printf '# Aidevix CLI — foydalanuvchi qo\047shgan agentlar\n# Format: NOM|BINARY|BUYRUQ|INSTALL|IZOH|KATEGORIYA|AUTH|URL\n\n' >"$USER_CONFIG"
  fi
  printf '%s|%s|%s|%s|%s|%s|%s|%s\n' \
    "$name" "$binary" "$command" "$install" "$desc" "$category" "$auth" "$url" >>"$USER_CONFIG"
  log_success "$(t "Qo'shildi: %s  →  %s" "$name" "$USER_CONFIG")"
}

# --- Avtomatik yangilanish (git orqali) -----------------------------------
# main'ga push qilingan o'zgarishlarni foydalanuvchilarga AVTOMATIK yetkazadi:
# remote'da yangi commit bo'lsa, jim yuklab oladi, qisqa xabar beradi va yangi
# versiyani qayta ishga tushiradi. Throttled (standart 3 soat).
# O'chirish: AIDEVIX_NO_AUTOUPDATE=1 · Oraliq: AIDEVIX_UPDATE_INTERVAL (sekund).
auto_update() {
  AIDEVIX_PHASE="update"
  [[ -n "${AIDEVIX_NO_AUTOUPDATE:-}" || -n "${CI:-}" ]] && return 0
  [[ -d "$PROJECT_ROOT/.git" ]] || return 0
  command -v git >/dev/null 2>&1 || return 0

  local stamp="$STATE_DIR/last_update_check" now interval last
  interval="${AIDEVIX_UPDATE_INTERVAL:-10800}"
  now="$(date +%s 2>/dev/null || echo 0)"
  if [[ -r "$stamp" ]]; then
    last="$(cat "$stamp" 2>/dev/null || echo 0)"; [[ "$last" =~ ^[0-9]+$ ]] || last=0
    (( now - last < interval )) && return 0
  fi
  mkdir -p "$STATE_DIR" 2>/dev/null || true
  atomic_write "$stamp" "$now" || true

  # http.schannelCheckRevoke=false — Windows git'dagi sertifikat-otzыv (revocation)
  # xatosini oldini oladi (CRYPT_E_NO_REVOCATION_CHECK).
  local g=(git -c http.schannelCheckRevoke=false -C "$PROJECT_ROOT")
  local branch; branch="$("${g[@]}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
  [[ -z "$branch" || "$branch" == "HEAD" ]] && branch=main

  # Lokal commit qilinmagan o'zgarishlar bo'lsa — ularni clobbering qilmaslik
  # uchun avtomatik yangilanishni o'tkazib yuboramiz (xavfsizlik).
  [[ -n "$("${g[@]}" status --porcelain 2>/dev/null)" ]] && return 0

  # FETCH_HEAD — `git fetch origin <branch>` uni har doim yozadi (tracking ref
  # sozlamasidan qat'i nazar), shuning uchun ishonchli.
  "${g[@]}" fetch --quiet --depth 1 origin "$branch" 2>/dev/null || return 0
  local local_sha remote_sha
  local_sha="$("${g[@]}" rev-parse HEAD 2>/dev/null || true)"
  remote_sha="$("${g[@]}" rev-parse FETCH_HEAD 2>/dev/null || true)"
  [[ -n "$local_sha" && -n "$remote_sha" && "$local_sha" != "$remote_sha" ]] || return 0

  # LOKAL COMMITLARNI YO'Q QILMAYMIZ. Quyidagi `git reset --hard FETCH_HEAD`
  # FAQAT fast-forward bo'lganda xavfsiz — ya'ni HEAD masofaviy commit'ning
  # AJDODI bo'lsa. Aks holda foydalanuvchida push qilinmagan LOKAL COMMITlar
  # bor va reset ularni butunlay o'chirib yuboradi (reflog'dan tashqari izsiz).
  #
  # Yuqoridagi `git status --porcelain` tekshiruvi bundan HIMOYA QILMAYDI: u
  # faqat commit QILINMAGAN o'zgarishlarni ko'radi. Commit qilingan, ammo hali
  # push qilinmagan ish uchun ishchi daraxt TOZA ko'rinadi — va yo'q bo'ladi.
  # Bu shu repoda ishlaydiganlar uchun real xavf, chunki ~/.ai-cli bir vaqtning
  # o'zida ham o'rnatish papkasi, ham git ish papkasi.
  if ! "${g[@]}" merge-base --is-ancestor "$local_sha" "$remote_sha" 2>/dev/null; then
    log_warn "$(t "Avtomatik yangilash o'tkazib yuborildi: %s da push qilinmagan lokal commitlar bor." "$PROJECT_ROOT")"
    log_info "$(t "Ishingizni saqlang (git push), so'ng qo'lda yangilang: git pull --rebase")"
    return 0
  fi

  printf '\n  %s%s%s%s\n' \
    "${C_BOLD:-}" "${C_TITLE:-}" "$(t '🔄 Aidevix CLI — yangi versiya topildi, yangilanmoqda...')" "${C_RESET:-}" >&2
  local subj
  subj="$("${g[@]}" log --no-merges --pretty='format:    • %s' "HEAD..FETCH_HEAD" 2>/dev/null | head -4 || true)"
  if [[ -n "$subj" ]]; then
    printf '  %s%s%s\n' "${C_GRAY:-}" "$(t "Yangi o'zgarishlar:")" "${C_RESET:-}" >&2
    printf '%s\n' "$subj" >&2
  fi

  if "${g[@]}" reset --hard --quiet FETCH_HEAD 2>/dev/null; then
    printf '  %s%s%s %s\n\n' "${C_GREEN:-}" "$(t '✓ Yangilandi!')" "${C_RESET:-}" "$(t 'Yangi imkoniyatlar tayyor.')" >&2
    # Skript ham yangilangan bo'lishi mumkin — yangi versiyani qayta ishga tushiramiz.
    trap - ERR
    cleanup 2>/dev/null || true
    exec bash "$SELF" "$@"
  fi
  printf '  %s%s%s\n\n' \
    "${C_YELLOW:-}" "$(t "! Avtomatik yangilab bo'lmadi — keyinroq qayta urinadi.")" "${C_RESET:-}" >&2
  return 0
}

# is_npm_install — paket npm (global) node_modules ichidan ishlayaptimi?
# Faqat shunda "npm update" maslahati to'g'ri bo'ladi (git/brew/scoop emas).
is_npm_install() {
  case "$PROJECT_ROOT" in
    */node_modules/*|*/node_modules) return 0 ;;
    *)                               return 1 ;;
  esac
}

# version_gt <a> <b> — semver a, b dan KATTAmi? (a>b → 0/true). Tashqi dasturga
# tayanmaydi: nuqta bilan ajratib, maydonma-maydon sonli taqqoslaydi. Raqam
# bo'lmagan qism (masalan "-beta") 0 deb olinadi — yetarli darajada ehtiyotkor.
version_gt() {
  local a="$1" b="$2"
  [[ "$a" == "$b" ]] && return 1
  local IFS=.
  # Nuqta bo'yicha ataylab bo'lib olamiz (semver maydonlari).
  # shellcheck disable=SC2206
  local -a A=($a) B=($b)
  local i max=${#A[@]}
  (( ${#B[@]} > max )) && max=${#B[@]}
  for (( i=0; i<max; i++ )); do
    local x="${A[i]:-0}" y="${B[i]:-0}"
    [[ "$x" =~ ^[0-9]+$ ]] || x=0
    [[ "$y" =~ ^[0-9]+$ ]] || y=0
    (( 10#$x > 10#$y )) && return 0
    (( 10#$x < 10#$y )) && return 1
  done
  return 1
}

# fetch_npm_latest — npm registry'dan eng so'nggi versiyani FONDA keshlaydi
# (throttled, std 3 soat). Bloklamaydi: joriy ishga tushish eski keshni o'qiydi.
fetch_npm_latest() {
  [[ -n "${CI:-}" ]] && return 0
  command -v curl >/dev/null 2>&1 || return 0
  local now interval last
  interval="${AIDEVIX_UPDATE_INTERVAL:-10800}"
  now="$(date +%s 2>/dev/null || echo 0)"
  if [[ -r "$NPM_CHECK_STAMP" && -r "$NPM_LATEST_CACHE" ]]; then
    last="$(cat "$NPM_CHECK_STAMP" 2>/dev/null || echo 0)"; [[ "$last" =~ ^[0-9]+$ ]] || last=0
    (( now - last < interval )) && return 0
  fi
  mkdir -p "$STATE_DIR" 2>/dev/null || return 0
  # dist-tags endpoint'i kichik: {"latest":"X.Y.Z", ...}. sed bilan ajratamiz.
  # curl'ning O'ZI o'lchagan javob vaqti (%{time_total}) LATENCY_FILE'ga
  # yoziladi — status bardagi "ms" ko'rsatkichi AYNAN shu haqiqiy o'lchov.
  ( curl -fsS -m 5 -w '%{time_total}' \
        -o "$NPM_LATEST_CACHE.raw" \
        "https://registry.npmjs.org/-/package/$NPM_PKG/dist-tags" 2>/dev/null \
        >"$LATENCY_FILE.tmp" \
      && sed -n 's/.*"latest":"\([0-9][0-9A-Za-z.\-]*\)".*/\1/p' \
           <"$NPM_LATEST_CACHE.raw" >"$NPM_LATEST_CACHE.tmp" 2>/dev/null \
      && [[ -s "$NPM_LATEST_CACHE.tmp" ]] \
      && mv -f "$NPM_LATEST_CACHE.tmp" "$NPM_LATEST_CACHE" 2>/dev/null \
      && mv -f "$LATENCY_FILE.tmp" "$LATENCY_FILE" 2>/dev/null \
      && printf '%s\n' "$now" >"$NPM_CHECK_STAMP" 2>/dev/null
    rm -f "$NPM_LATEST_CACHE.tmp" "$NPM_LATEST_CACHE.raw" "$LATENCY_FILE.tmp" 2>/dev/null
  ) >/dev/null 2>&1 &
  return 0
}

# ===========================================================================
#  STATUS BAR MAYDONLARI
# ===========================================================================
#
# MUHIM: Aidevix — ishga tushirgich. U hech qachon LLM API'ga murojaat
# qilmaydi, shuning uchun "context usage" yoki "token usage" kabi
# ko'rsatkichlarni O'LCHAY OLMAYDI — ular bu yerda ATAYLAB yo'q (to'qib
# chiqarilgan raqam ko'rsatgandan ko'ra, ko'rsatmagan afzal). Status barda
# faqat haqiqatan o'lchanadigan/o'qiladigan narsalar bor:
#   • provayder + model    — agent konfiguratsiyasi va MUHIT o'zgaruvchisidan
#   • API kalit holati     — muhitda bormi/yo'qmi
#   • agentlar sanog'i     — o'rnatilgan/jami
#   • versiya + yangilanish — VERSION va npm registry keshi
#   • latency              — curl o'lchagan oxirgi tarmoq javob vaqti

# status_version_field — "v1.7.4 ● oxirgi" yoki "v1.7.4 ▲ 1.8.0 bor".
status_version_field() {
  local latest=""
  [[ -r "$NPM_LATEST_CACHE" ]] && latest="$(cat "$NPM_LATEST_CACHE" 2>/dev/null || true)"
  if [[ -n "$latest" ]] && version_gt "$latest" "$AIDEVIX_VERSION"; then
    printf '%sv%s %s %s%s' "$UI_WARN" "$AIDEVIX_VERSION" "${ICO[down]}" \
      "$(t 'yangilanish: %s' "$latest")" "$UI_R"
  else
    printf '%sv%s%s %s%s %s%s' "$UI_MUTED" "$AIDEVIX_VERSION" "$UI_R" \
      "$UI_OK" "${ICO[dot_on]}" "$(t "eng so'nggi")" "$UI_R"
  fi
}

# status_latency_field — oxirgi O'LCHANGAN tarmoq javob vaqti (ms).
# Hech qachon o'lchanmagan bo'lsa — maydon umuman chiqmaydi (bo'sh qaytadi).
status_latency_field() {
  [[ -r "$LATENCY_FILE" ]] || return 0
  local sec ms
  sec="$(cat "$LATENCY_FILE" 2>/dev/null || true)"
  [[ "$sec" =~ ^[0-9]+([.][0-9]+)?$ ]] || return 0
  # sekund → millisekund, tashqi dastursiz (awk/bc yo'q): kasrni kesib olamiz.
  local int="${sec%%.*}" frac="${sec#*.}"
  [[ "$frac" == "$sec" ]] && frac="000"
  frac="${frac}000"; frac="${frac:0:3}"
  ms=$(( 10#${int:-0} * 1000 + 10#$frac ))
  local c="$UI_OK"
  (( ms > 300 ))  && c="$UI_WARN"
  (( ms > 1000 )) && c="$UI_ERR"
  printf '%s%s %sms%s' "$c" "${ICO[clock]}" "$ms" "$UI_R"
}

# npm_autoupdate_apply <latest> [orig-args...] — yangi versiyaga yangilashni
# TAKLIF qiladi. Foydalanuvchi tasdiqlasa (std = ha) `npm i -g pkg@latest` qilib,
# joriy jarayonni YANGI versiya bilan qayta ishga tushiradi (exec). Shu yo'l bilan
# eski/crash beradigan versiyadagi userni avtomatik chiqarib olamiz. Rad etsa yoki
# o'rnatish muvaffaqiyatsiz bo'lsa — passiv eslatmaga qaytish uchun 1 qaytaradi.
npm_autoupdate_apply() {
  AIDEVIX_PHASE="update"
  local latest="$1"; shift
  # HALQA (loop) KAFOLATI: bu exec-zanjirida yangilash BIR MARTA taklif qilinadi.
  # Sabab — real hodisa: npm'dagi paketda `package.json` versiyasi ko'tarilgan,
  # lekin ichidagi `VERSION` fayli eski qolgan edi. Natijada `npm i -g` muvaffaqiyatli
  # tugasa ham qayta ishga tushgan skript O'ZINI yana eski deb bilib, yana yangilashni
  # taklif qilardi — foydalanuvchi cheksiz "[Y/n]" halqasiga tushib qolardi.
  # Endi marker (exec orqali o'tadi) borligida darhol 1 qaytaramiz: chaqiruvchi
  # passiv eslatmaga/tashxis paneliga tushadi va menyu normal ochiladi.
  [[ -n "${AIDEVIX_UPDATE_ATTEMPTED:-}" ]] && return 1
  local ans="" q
  q="$(t '🔄 Yangi versiya bor (%s → %s). Hozir avtomatik yangilaymizmi? [Y/n] ' "$AIDEVIX_VERSION" "$latest")"
  # TTY o'qishidan oldin ERR-tutqichni vaqtincha o'chiramiz (prompt_tty kabi).
  trap - ERR
  if { : >/dev/tty; } 2>/dev/null; then
    printf '%s' "$q" >/dev/tty
    IFS= read -r ans </dev/tty || ans=""
  else
    printf '%s' "$q" >&2
    IFS= read -r ans || ans=""
  fi
  trap 'crash "$BASH_COMMAND" "$LINENO"' ERR
  case "$ans" in
    ''|[Yy]|[Yy][Ee][Ss]|[Hh]|[Hh][Aa]) ;;     # ha / yes / bo'sh = yangilaymiz
    *) return 1 ;;                              # rad etildi — passiv eslatmaga qaytadi
  esac
  log_info "$(t 'Yangilanmoqda: npm i -g %s@latest …' "$NPM_PKG")"
  if npm i -g "$NPM_PKG@latest" </dev/null; then
    log_success "$(t 'Yangilandi (%s). Qayta ishga tushmoqda…' "$latest")"
    # `exec bash "$SELF"` — `exec "$0"` EMAS. Ikki sabab:
    #   1) npm orqali chaqirilganda $0 Windows uslubidagi yo'l bo'lishi mumkin
    #      (`C:\...\ai-selector.sh`, bin/cli.js shunday uzatadi) — uni to'g'ridan
    #      exec qilish shebang'ga tayanadi va MSYS'da ishonchsiz;
    #   2) skript endigina npm tomonidan QAYTA YOZILDI; bash skript faylini
    #      dangasa (lazy) o'qiydi, shuning uchun yangi jarayonni aniq interpretator
    #      bilan boshlagan ma'qul. auto_update ham xuddi shunday qiladi.
    trap - ERR
    cleanup 2>/dev/null || true
    # Marker: qaysi versiyadan yangilaganimizni yangi jarayonga uzatamiz. Yangi
    # jarayon o'zini YANA eski deb bilsa (paket buzuq), bu marker orqali halqaga
    # tushmasdan aniq tashxis ko'rsatadi.
    export AIDEVIX_UPDATE_ATTEMPTED="$AIDEVIX_VERSION"
    exec bash "$SELF" "$@"                      # yangilangan versiya bilan qayta start
  fi
  log_warn "$(t "Avtomatik yangilab bo'lmadi. Qo'lda: npm i -g %s@latest" "$NPM_PKG")"
  return 1
}

# maybe_npm_update_hint — npm o'rnatishda yangi versiya bo'lsa: interaktiv TTY +
# npm bor bo'lsa YANGILASHNI TAKLIF qiladi (npm_autoupdate_apply), aks holda (yoki
# rad etilsa) passiv eslatma ko'rsatadi. npm paketlari O'ZINI avtomatik
# yangilamaydi, shuning uchun bu — asosiy tarqalish vositasi: yangi versiya bo'lsa
# HAR ISHGA TUSHGANDA ko'rsatamiz, foydalanuvchi yangilaguncha.
# Majburlamaydi. O'chirish: AIDEVIX_NO_AUTOUPDATE=1 (yoki CI).
maybe_npm_update_hint() {
  [[ -n "${AIDEVIX_NO_AUTOUPDATE:-}" || -n "${CI:-}" ]] && return 0
  is_npm_install || return 0
  fetch_npm_latest                       # keyingi safar uchun fonda yangilaydi
  [[ -r "$NPM_LATEST_CACHE" ]] || return 0
  local latest; latest="$(cat "$NPM_LATEST_CACHE" 2>/dev/null || true)"
  [[ "$latest" =~ ^[0-9]+\.[0-9]+ ]] || return 0
  version_gt "$latest" "$AIDEVIX_VERSION" || return 0

  # YANGILANDI, LEKIN VERSIYA O'ZGARMADI. `npm i -g` muvaffaqiyatli tugadi, qayta
  # ishga tushdik — va biz hamon o'zimizni eski deb bilamiz. Bu foydalanuvchining
  # xatosi EMAS: registry'dagi paketda `package.json` versiyasi bilan ichidagi
  # `VERSION` fayli mos kelmaydi (yoki `npm -g` boshqa prefix'ga o'rnatgan).
  # Yana so'ramaymiz — sababni aytamiz va menyuni ochamiz.
  if [[ "${AIDEVIX_UPDATE_ATTEMPTED:-}" == "$AIDEVIX_VERSION" ]]; then
    ui_notice warn \
      "$(t "Yangilash o'rnatildi, lekin versiya hamon %s (kutilgan: %s)." "$AIDEVIX_VERSION" "$latest")" \
      "$(t "Sabab: npm'dagi paket ichidagi VERSION fayli eskirgan, yoki PATH'da BOSHQA nusxa oldinda turibdi.")" \
      "$(t "Aniqlash (barcha nusxalarni ko'rsatadi):")" \
      "    aidevix --doctor" \
      "$(t 'Tekshirish:')" \
      "    npm ls -g --depth=0 $NPM_PKG" \
      "$(t 'Eslatmani o'\''chirish: AIDEVIX_NO_AUTOUPDATE=1')"
    return 0
  fi

  # Interaktiv sessiya + npm bor → yangilashni TAKLIF qilamiz (tasdiqlasa exec).
  # Tasdiqlanib yangilansa, apply qaytmaydi (exec). Rad etilsa 1 qaytaradi →
  # pastdagi passiv eslatmaga tushadi. `[[ -t 0 ]]` SHART: quvur/CI/bats kabi
  # nointeraktiv holatda taklif qilmaymiz (aks holda promptда osilib qoladi).
  if command -v npm >/dev/null 2>&1 && [[ -t 0 ]] && { : >/dev/tty; } 2>/dev/null; then
    npm_autoupdate_apply "$latest" "$@" && return 0
  fi

  ui_notice info "$(t '🔄 Aidevix yangi versiya bor (%s → %s)' "$AIDEVIX_VERSION" "$latest")" \
    "$(t 'Yangilash uchun terminalga yozing:')" \
    "    npm i -g $NPM_PKG@latest" \
    "$(t "Eslatmani o'chirish: AIDEVIX_NO_AUTOUPDATE=1")"
}

# --- Argumentlar ----------------------------------------------------------
main() {
  # Saqlangan til — preview qism-jarayonida ham to'g'ri til ishlashi uchun ENG OLDIN.
  load_saved_lang

  # Preview qism-jarayoni — augment va boshqa og'ir ishlardan oldin.
  if [[ "${1:-}" == "__preview" ]]; then
    preview_agent "${2:-}" "${3:-}" "${4:-52}"
    exit 0
  fi

  augment_tool_path

  # Avtomatik yangilanish — tez/meta buyruqlar uchun o'tkazib yuboramiz.
  case "${1:-}" in
    -h|--help|-v|--version|-s|--stats|--lang|-L) : ;;
    *)                                           auto_update "$@"; maybe_npm_update_hint "$@" ;;
  esac

  case "${1:-}" in
    -h|--help)     usage ;;
    -v|--version)  printf 'Aidevix CLI %s\n' "$AIDEVIX_VERSION" ;;
    -l|--list)     list_agents ;;
    -u|--update)   update_agents ;;
    -d|--doctor)   doctor ;;
    -a|--add)      add_agent ;;
    -s|--stats)    stats_cmd "${2:-}" ;;
    -L|--lang)     lang_cmd "${2:-}" ;;
    -i|--icons)    icons_cmd "${2:-}" ;;
    -f|--free)     run_menu free ;;
    -t|--top)      run_menu top ;;
    "")            run_menu ;;
    -*)            log_error "$(t "Noma'lum tanlov: %s" "$1")"; echo; usage; exit 2 ;;
    *)             quick_launch "$1" ;;
  esac
}

# Skript to'g'ridan-to'g'ri ishga tushirilganda main()'ni chaqiramiz. `source`
# qilinganda (masalan bats testlarida) chaqirmaymiz — shunda alohida funksiyalarni
# (trim, parse_agents, ...) izolyatsiyada test qilish mumkin bo'ladi.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
