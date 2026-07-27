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
AIDEVIX_VERSION="$(cat "$PROJECT_ROOT/VERSION" 2>/dev/null || echo "1.0.0")"

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
TOP_AGENTS="claude codex gemini copilot cursor-agent aider opencode qwen codebuff freebuff"

# --- Umumiy yordamchilarni yuklash ----------------------------------------
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
  [[ "${UI_TTY:-0}" -eq 1 ]] && printf '\033[?7h\033[?1007l\033[?1049l' >&2 2>/dev/null || true
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
  printf '\033[?1007l\033[?25h\033[?7h\033[?1049l' >&2 2>/dev/null || true
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
  printf '\033[?1007l\033[?25h\033[?7h\033[?1049l' 2>/dev/null >/dev/tty || true
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
  panel "$(t "⚠  YANGILANG — bu xato yangi versiyada tuzatilgan bo'lishi mumkin")" \
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
listed CLIs are paid, some are free/free-tier (see 🆓/🔑/💳 badges).

USAGE:
  aidevix [OPTION | AGENT]

OPTIONS:
  (no argument)   Open the interactive menu (fzf if available, otherwise a
                  built-in ↑/↓ arrow menu with live details; numbered as a
                  last resort when there is no terminal)
  AGENT           Launch an agent directly by name or binary
                  (e.g. `aidevix claude`, `aidevix gemini`)
  -l, --list      List agents and their status
  -f, --free      Open a menu of FREE agents only (🆓 / free tier)
  -t, --top       Open a menu of the most popular (top) agents only
  -u, --update    Update all installed agents
  -d, --doctor    Check the environment (node/npm/python/fzf, PATH, agents)
  -a, --add       Add a new agent interactively
  -s, --stats [on|off]
                  Global stats (opt-in): show status, or turn on/off.
                  When on, the menu shows "🔥 #rank". Only the agent name +
                  event type are sent (no personal data). Default: off.
  -L, --lang [en|uz]
                  Choose the interface language (asked on first run), or set it
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
ba'zi CLI'lar pullik, ba'zilari bepul/bepul tier (🆓/🔑/💳 belgilariga qarang).

FOYDALANISH:
  aidevix [TANLOV | AGENT]

TANLOVLAR:
  (argumentsiz)   Interaktiv menyuni ochadi (fzf bo'lsa fzf; bo'lmasa ichki
                  ↑/↓ ko'rsatkichli menyu — tafsilot bilan; terminal bo'lmasa
                  oxirgi chora sifatida raqamli)
  AGENT           Agentni nomi yoki binari bo'yicha to'g'ridan-to'g'ri ishga tushiradi
                  (masalan: `aidevix claude`, `aidevix gemini`)
  -l, --list      Agentlar ro'yxati va holatini ko'rsatadi
  -f, --free      Faqat BEPUL agentlar menyusini ochadi (🆓 / bepul tier)
  -t, --top       Faqat eng mashhur (top) agentlar menyusini ochadi
  -u, --update    O'rnatilgan barcha agentlarni yangilaydi
  -d, --doctor    Muhitni tekshiradi (node/npm/python/fzf, PATH, agentlar)
  -a, --add       Interaktiv tarzda yangi agent qo'shadi
  -s, --stats [on|off]
                  Global statistika (opt-in): holatni ko'rsatadi yoki yoqadi/o'chiradi.
                  Yoqilganda menyuda "🔥 #reyting" ko'rinadi. Faqat agent nomi +
                  hodisa turi yuboriladi (shaxsiy ma'lumotsiz). Standart — o'chiq.
  -L, --lang [en|uz]
                  Interfeys tilini tanlash (ilk ishga tushishda so'raladi) yoki o'rnatish
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

trim() { printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }

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
      panel "$(t '📊 Global statistika YOQILDI')" \
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
      panel "$(t '📊 Global statistika — holat: %s' "$state")" \
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
  panel "$(t '💡 Maslahat — global statistika (ixtiyoriy)')" \
    "$(t 'Qaysi AI CLI dunyoda eng mashhurligini menyuda ko'\''rmoqchimisiz?')" \
    "    aidevix --stats on" \
    "$(t "Yoqsangiz FAQAT agent nomi + hodisa turi yuboriladi (shaxsiy ma'lumotsiz).")" \
    "$(t 'Standart — o'\''CHIQ. Hozir hech narsa o'\''zgarmaydi; bu shunchaki eslatma.')"
}

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

  local B="${C_BOLD:-}" T="${C_TITLE:-}" R="${C_RESET:-}" Gy="${C_GRAY:-}"
  {
    printf '\n  %s%s🌐  Til tanlang  /  Choose your language%s\n\n' "$B" "$T" "$R"
    printf '     %s[1]%s English\n'   "$B" "$R"
    printf '     %s[2]%s Oʻzbekcha\n\n' "$B" "$R"
    printf '  %sEnter = avto / auto%s\n' "$Gy" "$R"
  } >/dev/tty
  local ans=""
  trap - ERR
  printf '  %s[1/2]%s › ' "$B" "$R" >/dev/tty
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

# maybe_show_intro — Aidevix nima EKANLIGINI (va nima EMASligini) BIR MARTA
# tushuntiradi. Ko'pchilik menyudagi CLI'larni "bepul" yoki "aidevix javob
# beradi" deb o'ylaydi — bu chalkashlikni oldindan oldini olamiz.
maybe_show_intro() {
  [[ -n "${CI:-}" ]] && return 0
  [[ -e "$INTRO_FILE" ]] && return 0
  mkdir -p "$STATE_DIR" 2>/dev/null || return 0
  : >"$INTRO_FILE" 2>/dev/null || true
  panel "$(t 'ℹ️  Aidevix nima — va nima EMAS')" \
    "$(t 'Aidevix — faqat ishga tushirgich (launcher): AI CLI'\''larni siz uchun')" \
    "$(t 'o'\''rnatib, ochib beradi — xolos.')" \
    "" \
    "$(t '• CLI'\''larning O'\''ZI uchinchi tomon dasturlar (Anthropic, Google, OpenAI, ...).')" \
    "$(t '• Ba'\''zilari PULLIK, ba'\''zilari bepul yoki bepul tier — menyuda 🆓 / 🔑 / 💳 belgisi.')" \
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
    panel "$(t "🔐 '%s' — login/kalit kerak" "$name")" \
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
    panel "$(t "🔐 '%s' — eslatma" "$name")" \
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

  if command -v npm >/dev/null 2>&1; then
    prefix="$(npm config get prefix 2>/dev/null || true)"
    if [[ -n "$prefix" && "$prefix" != "undefined" ]]; then
      # Unix'da binar $prefix/bin ichida, Windows'da $prefix ichida bo'ladi.
      dirs+=("$prefix/bin" "$prefix")
    fi
  fi
  # python3 Windows'da ko'pincha Store stub'i (user-base bermaydi) — haqiqiy
  # natija chiqquncha python3, so'ng python bilan urinamiz.
  local py
  for py in python3 python; do
    command -v "$py" >/dev/null 2>&1 || continue
    userbase="$("$py" -m site --user-base 2>/dev/null || true)"
    [[ -n "$userbase" ]] && break
  done
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
    "$HOME/.local/bin" "$HOME/bin" "$HOME/.cargo/bin"
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
    name="$(trim "${name:-}")"
    binary="$(trim "${binary:-}")"
    command="$(trim "${command:-}")"
    install="$(trim "${install:-}")"
    desc="$(trim "${desc:-}")"
    category="$(trim "${category:-}")"
    auth="$(trim "${auth:-}")"
    url="$(trim "${url:-}")"
    [[ -z "$category" ]] && category="$DEFAULT_CATEGORY"

    if [[ -z "$name" || -z "$binary" || -z "$command" ]]; then
      log_warn "$(t "Noto'g'ri qator o'tkazib yuborildi (#%s): %s" "$lineno" "$line")"
      continue
    fi
    # Agent izohi (desc) va login izohi (auth) — tanlangan tilga tarjima qilamiz
    # (en bo'lsa). Shunda menyu/preview/--list TO'LIQ bir tilda chiqadi (uz manba
    # — kalit). Emoji belgilari (🆓/🌐/🔑/💳) tarjimada ham saqlanadi — filtr/badge
    # ularga tayanadi.
    [[ -n "$desc" ]] && desc="$(t "$desc")"
    [[ -n "$auth" ]] && auth="$(t "$auth")"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$desc" "$binary" "$command" "$install" "$category" "$auth" "$url"
    found=1
  done <"$config"

  [[ "$found" -eq 1 ]] || die 1 "$(t 'Konfiguratsiyada yaroqli agent topilmadi: %s' "$config")"
}

# --- Holat ustuni bilan to'ldirilgan qatorlar -----------------------------
# Chiqish formati: NAME\tDESC\tBINARY\tCOMMAND\tINSTALL\tCATEGORY\tSTATUS
build_rows() {
  local config="$1" name desc binary command install category auth url status
  # IFS=US (0x1f) — TAB whitespace bo'lgani uchun bo'sh maydonlarni "yutib" yuboradi
  # (masalan install bo'sh bo'lsa, keyingi maydonlar siljiydi). Shu sababli TAB'ni
  # non-whitespace ajratgich (\037)ga o'giramiz — bo'sh maydonlar saqlanadi.
  while IFS=$'\037' read -r name desc binary command install category auth url; do
    if command -v "$binary" >/dev/null 2>&1; then
      status="$(t "✓ o'rnatilgan")"
    else
      status="$(t '✗ yo'\''q')"
    fi
    # Maydon tartibi: status 7-, auth 8-, url 9- (preview/menu $7 status'ga tayanadi).
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$name" "$desc" "$binary" "$command" "$install" "$category" "$status" "$auth" "$url"
  done < <(parse_agents "$config" | tr '\t' '\037')
}

# --- --list rejimi --------------------------------------------------------
# Agentlar lokal ishlatish sanog'i bo'yicha KAMAYISH tartibida ko'rsatiladi
# (eng ko'p ishlatilgan tepada); "MARTA" ustuni shu sanoqni ko'rsatadi.
list_agents() {
  local config; config="$(resolve_config)"
  log_info "$(t 'Konfiguratsiya: %s' "$config")"
  local statsfile="$STATS_FILE"; [[ -r "$statsfile" ]] || statsfile=/dev/null
  printf '\n%s%-18s %-14s %-9s %-7s %-34s %s%s\n' "$C_BOLD" "$(t AGENT)" "$(t HOLAT)" "$(t GURUH)" "$(t MARTA)" "$(t IZOH)" "$(t LOGIN)" "$C_RESET"
  printf '%s\n' "-------------------------------------------------------------------------------------------------"
  local name desc binary command install category status auth url count color icon label
  while IFS=$'\037' read -r name desc binary command install category status auth url count; do
    if [[ "$status" == *"✓"* ]]; then color="$C_GREEN"; else color="$C_RED"; fi
    # ✓/✗ belgisi 3 bayt (1 ustun) — `%-Ns` baytlab to'ldirgani uchun emoji'ni
    # to'ldirish maydonidan TASHQARIDA chiqaramiz; faqat ASCII holat matnini
    # to'ldiramiz (bayt=ustun → ustunlar to'g'ri tekislanadi). Qarang preview/menu.
    icon="${status%% *}"   # ✓ yoki ✗
    label="${status#* }"   # holat matni (o'rnatilgan/yo'q/installed/missing)
    printf '%-18s %b%s %-12s%b %-9s %-7s %-34s %s\n' "$name" "$color" "$icon" "$label" "$C_RESET" "$category" "${count}×" "$desc" "$auth"
  done < <(
    build_rows "$config" | awk -F'\t' -v sf="$statsfile" '
      BEGIN { while ((getline line < sf) > 0) { m = split(line, a, "\t"); if (m >= 2) cnt[a[2]] = a[1] } }
      { c = cnt[$1] + 0; printf "%010d\t%06d\t%s\t%d\n", c, (++idx), $0, c }
    ' | sort -t"$(printf '\t')" -k1,1nr -k2,2n | cut -f3- | tr '\t' '\037'
  )
}

# --- Preview (fzf tomonidan qism-jarayon sifatida chaqiriladi) -------------
# fzf preview'ni TTY'siz ishga tushiradi, shuning uchun ranglarni bevosita
# ANSI kodlari bilan beramiz (fzf --ansi ularni to'g'ri ko'rsatadi).
preview_agent() {
  local name="$1" datafile="$2"
  [[ -r "$datafile" ]] || return 0
  awk -F'\t' -v n="$name" \
    -v l_inst="$(t 'o'\''rnatilgan')" -v l_noinst="$(t 'o'\''rnatilmagan')" \
    -v l_status="$(t 'Holat')" -v l_binary="$(t 'Binar')" -v l_cmd="$(t 'Buyruq')" \
    -v l_cat="$(t 'Kategoriya')" -v l_login="$(t 'Login')" -v l_url="$(t 'Havola')" \
    -v l_install="$(t 'O'\''rnatish:')" -v l_unset="$(t '(belgilanmagan)')" '
    BEGIN {
      ESC = sprintf("%c", 27)
      B   = ESC "[1m";      R = ESC "[0m"
      CY  = ESC "[38;5;87m"; GY = ESC "[90m"
      GRN = ESC "[32m";      RED = ESC "[31m";  MG = ESC "[38;5;213m"
    }
    $1 == n {
      # Holat belgisi
      if ($7 ~ /✓/) { badge = GRN "● " l_inst R }
      else          { badge = RED "○ " l_noinst R }

      print ""
      print "  " B CY $1 R
      print "  " GY "────────────────────────────" R
      print ""
      print "  " GY sprintf("%-10s", l_status) R badge
      print "  " GY sprintf("%-10s", l_binary) R $3
      print "  " GY sprintf("%-10s", l_cmd)    R MG $4 R
      print "  " GY sprintf("%-10s", l_cat)    R $6
      print "  " GY sprintf("%-10s", l_login)  R ($8 == "" ? GY "—" R : $8)
      if ($9 != "") print "  " GY sprintf("%-10s", l_url) R CY $9 R
      print ""
      print "  " GY l_install R
      print "    " ($5 == "" ? GY l_unset R : $5)
      print ""
      print "  " GY "────────────────────────────" R
      print "  " $2
      exit
    }' "$datafile"
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
  awk -F'\t' -v sf="$statsfile" -v gf="$globalfile" -v tops=" $TOP_AGENTS " \
            -v last="$lastname" -v l_last="$(t 'oxirgi')" \
            -v g="${C_GREEN:-}" -v r="${C_RED:-}" -v z="${C_RESET:-}" \
            -v t="${C_TITLE:-}" -v gy="${C_GRAY:-}" -v b="${C_BOLD:-}" -v mg="${C_MAGENTA:-}" '
    function human(x) {
      if (x >= 1000000) return sprintf("%.1fM", x / 1000000)
      if (x >= 1000)    return sprintf("%.1fk", x / 1000)
      return x ""
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
      name=$1; desc=$2; binary=$3; status=$7; auth=$8;
      if (status ~ /✓/) { icon = g "✓" z } else { icon = r "✗" z }
      badge = "";
      if (index(auth, "🆓"))      badge = "🆓";
      else if (index(auth, "🌐")) badge = "🌐";
      else if (index(auth, "🔑")) badge = "🔑";
      else if (index(auth, "💳")) badge = "💳";
      c = cnt[name] + 0;
      istop = (index(tops, " " binary " ") > 0) ? 1 : 0;
      islast = (last != "" && name == last) ? 1 : 0;
      use = (c > 0) ? sprintf("  %s·%d×%s", gy, c, z) : "";
      gbadge = (name in grank) ? sprintf("  %s🔥#%d·%s%s", mg, grank[name], human(gcnt[name] + 0), z) : "";
      star = istop ? sprintf("  %s⭐%s", t, z) : "";
      lastm = islast ? sprintf("  %s↩ %s%s", mg, l_last, z) : "";
      disp = sprintf("%s  %s%s%-16s%s %s%s%s  %s%s%s%s%s", icon, b, t, name, z, gy, desc, z, badge, use, gbadge, star, lastm)
      # Tartiblash kalitlari: 1) oxirgi ishlatilgan (eng tepada), 2) lokal sanoq
      # (kamayish), 3) top/mashhurlik (kamayish — yangi foydalanuvchida ham
      # mashhurlar tepada), 4) config indeksi (barqaror).
      printf "%d\t%010d\t%d\t%06d\t%s\t%s\n", islast, c, istop, (++idx), disp, name
    }
  ' <<<"$rows" | sort -t"$(printf '\t')" -k1,1nr -k2,2nr -k3,3nr -k4,4n | cut -f5-
}

# --- fzf orqali tanlash ---------------------------------------------------
select_with_fzf() {
  local menu="$1" datafile="$2" selection rc
  local -a fzf_args=(
    --ansi
    --delimiter='\t'
    --with-nth=1
    --prompt="$(t '  qidirish › ')"
    --pointer='▶'
    --marker='✓'
    --height=~90%
    --layout=reverse
    --border=rounded
    --border-label=' ✦ Aidevix CLI '
    --border-label-pos=3
    --margin='1,2'
    --padding=1
    --info=inline
    --color='fg:-1,bg:-1,hl:51,fg+:231,bg+:236,hl+:87,info:245,prompt:213,pointer:213,marker:84,header:245,border:60,label:87'
    --header="$(t '↑/↓ tanlang · yozib qidiring · ENTER ishga tushirish · ESC bekor')"
  )

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
    fzf_args+=(
      --preview "bash \"$SELF\" __preview {2} \"$datafile\""
      --preview-window='right,52%,wrap,border-left'
      --preview-label=' tafsilot '
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

  log_warn "$(t "fzf topilmadi — oddiy menyu ishlatilmoqda (yaxshiroq tajriba uchun fzf o'rnating).")"
  printf '\n%s%s%s\n' "${C_BOLD:-}" "$(t 'AI CLI tanlang:')" "${C_RESET:-}" >&2
  local i
  for i in "${!names[@]}"; do
    printf '%b%3d)%b %b\n' "${C_BLUE:-}" "$((i + 1))" "${C_RESET:-}" "${displays[$i]}" >&2
  done
  printf '%s\n' "----------------------------------------" >&2

  local choice="" prompt; prompt="$(t 'Raqam kiriting (1-%s, ESC=bekor) › ' "${#names[@]}")"
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
  { : >/dev/tty; } 2>/dev/null || return 2  # faqat poyga holatida; trap'ni tripmaslik uchun shartli kontekstda emas — gate run_menu'da

  # Klavisha o'qish `dd`ga tayanadi (qarang _rd). Yo'q bo'lsa JIM o'lmaymiz:
  # rc=2 bilan qaytamiz → run_menu raqamli menyuga tushadi va sababini aytadi.
  command -v dd >/dev/null 2>&1 || return 2

  # Datafile (TSV, 9 maydon)ni BIR o'qishda massivlarga olamiz — klavish tsiklida
  # tashqi jarayon (awk) UMUMAN ochilmaydi. Windows/MSYS'da har fork ~50-150ms:
  # avvalgi per-keypress awk/subshell'lar bitta strelka bosishini soniyagacha
  # cho'zib, "menyuda scroll ishlamayapti" shikoyatiga sabab bo'lardi.
  # TAB → \037 (US) — bo'sh maydonlar "yutilmasligi" uchun (qarang build_rows).
  local -a r_name=() r_desc=() r_cmd=() r_inst=() r_cat=() r_st=() r_auth=() r_url=()
  local rn rd rb rc2 ri rcat rst ra ru
  while IFS=$'\037' read -r rn rd rb rc2 ri rcat rst ra ru; do
    [[ -n "$rn" ]] || continue
    r_name+=("$rn"); r_desc+=("$rd"); r_cmd+=("$rc2"); r_inst+=("$ri")
    r_cat+=("$rcat"); r_st+=("$rst"); r_auth+=("$ra"); r_url+=("$ru")
  done < <(tr '\t' '\037' <"$datafile")

  # QIDIRUV matnlari (kichik harf) — bitta tr bilan butun faylni kichraytirib
  # o'qiymiz (bash 3.2 da ${var,,} yo'q). Tartib r_* massivlari bilan bir xil.
  local -a r_hay=()
  while IFS=$'\037' read -r rn rd rb rc2 ri rcat rst ra ru; do
    [[ -n "$rn" ]] || continue
    r_hay+=("$rn $rd $rb $rcat $ra")
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

  # Ko'rinadigan qatorlar soni — terminal balandligiga moslab cheklaymiz.
  local th; th="$(tput lines 2>/dev/null || echo 24)"; [[ "$th" =~ ^[0-9]+$ ]] || th=24
  local page=$(( total < 10 ? total : 10 ))
  local maxlist=$(( th - 14 )); (( maxlist < 3 )) && maxlist=3
  (( page > maxlist )) && page=$maxlist
  # Ramka balandligi o'zgarmas: header2 + page + count1 + hr1 + det6 + footer1.
  # Alt-screen'da har chizish \033[H dan boshlanadi — balandlikni sanash shart emas,
  # lekin det[] DOIM 6 qator bo'lishi kerak (aks holda eski qatorlar qoladi).

  # Statik matn/yorliqlarni BIR MARTA hisoblaymiz — har $(t ...) command
  # substitution ham fork; ularni klavish tsiklida takrorlash Windows'da
  # menyuni sezilarli sekinlashtirardi.
  local S_HDR S_PROMPT S_HR S_FOOT S_NOMATCH S_INST S_NOINST
  local L_CMD L_CAT L_LOGIN L_URL L_INSTL L_UNSET
  S_HDR="  ${C_BOLD}${C_TITLE}✦ Aidevix CLI${C_RESET}  ${C_GRAY}$(t '↑/↓ tanlang · yozib qidiring · ENTER ishga tushirish · ESC bekor')${C_RESET}"
  S_PROMPT="$(t '  qidirish › ')"
  S_HR="  ${C_GRAY}$(hr 30)${C_RESET}"
  S_FOOT="  ${C_GRAY}$(t 'q yoki 2×ESC = bekor · Enter = tanlash')${C_RESET}"
  S_NOMATCH="  ${C_GRAY}$(t 'Moslik topilmadi — Backspace bilan qidiruvni tahrirlang.')${C_RESET}"
  S_INST="${C_GREEN}● $(t "o'rnatilgan")${C_RESET}"
  S_NOINST="${C_RED}○ $(t "o'rnatilmagan")${C_RESET}"
  L_CMD="$(t 'Buyruq')";  L_CAT="$(t 'Kategoriya')";     L_LOGIN="$(t 'Login')"
  L_URL="$(t 'Havola')";  L_INSTL="$(t "O'rnatish:")";   L_UNSET="$(t '(belgilanmagan)')"

  local cur=0 topv=0 query=""
  local -a vis=()

  # _af — joriy filtrga mos indekslar ro'yxatini (vis) quradi.
  _af() {
    vis=(); local q ii
    q="$(printf '%s' "$query" | tr '[:upper:]' '[:lower:]')"
    for ii in "${!names[@]}"; do
      if [[ -z "$q" ]]; then vis+=("$ii"); continue; fi
      case "${hay[ii]}" in *"$q"*) vis+=("$ii") ;; esac
    done
    (( cur >= ${#vis[@]} )) && cur=$(( ${#vis[@]} - 1 ))
    (( cur < 0 )) && cur=0
  }

  # _ad <menyu-indeksi> — tanlangan agentning qat'iy DET-qatorli tafsilotini
  # det[] ga yozadi. Sof bash (oldindan o'qilgan r_* massivlaridan) — har
  # siljishda awk/subshell ochilmaydi (Windows'da scroll sekinligining sababi edi).
  local -a det=()
  _ad() {
    det=(); local mi="${1:--1}" dj=-1 n2="" d2="" c2="" ins="" cat="" st="" a="" u="" badge
    if [[ "$mi" =~ ^[0-9]+$ ]]; then dj="${rowof[mi]:--1}"; fi
    if (( dj >= 0 )); then
      n2="${r_name[dj]}"; d2="${r_desc[dj]}"; c2="${r_cmd[dj]}"; ins="${r_inst[dj]}"
      cat="${r_cat[dj]}"; st="${r_st[dj]}"; a="${r_auth[dj]}"; u="${r_url[dj]}"
    fi
    if [[ "$st" == *✓* ]]; then badge="$S_INST"; else badge="$S_NOINST"; fi
    [[ -z "$a" ]] && a="—"; [[ -z "$u" ]] && u="—"; [[ -z "$ins" ]] && ins="$L_UNSET"
    det+=("  ${C_BOLD}${C_TITLE}${n2}${C_RESET}   ${badge}")
    det+=("  ${C_GRAY}${L_CMD}${C_RESET}     ${C_MAGENTA}${c2}${C_RESET}")
    det+=("  ${C_GRAY}${L_CAT}${C_RESET} ${cat}    ${C_GRAY}${L_LOGIN}${C_RESET} ${a}")
    det+=("  ${C_GRAY}${L_URL}${C_RESET}     ${C_CYAN}${u}${C_RESET}")
    det+=("  ${C_GRAY}${L_INSTL}${C_RESET} ${ins}")
    det+=("  ${C_GRAY}${d2}${C_RESET}")
  }

  # _ar — butun ramkani (qat'iy FH qator) chizadi. Sof bash: forksiz (statik
  # matnlar oldindan tayyor). Alt-screen'da har safar tepadan (\033[H) chiziladi.
  _ar() {
    local nvis=${#vis[@]}
    (( cur < topv )) && topv=$cur
    (( cur >= topv + page )) && topv=$(( cur - page + 1 ))
    (( topv < 0 )) && topv=0
    local -a out=()
    out+=("$S_HDR")
    if [[ -n "$query" ]]; then out+=("  ${C_MAGENTA}${S_PROMPT}${C_RESET}${query}")
    else                       out+=("  ${C_GRAY}${S_PROMPT}${C_RESET}"); fi
    local r vi oi
    for (( r=0; r<page; r++ )); do
      vi=$(( topv + r ))
      if (( vi < nvis )); then
        oi=${vis[vi]}
        if (( vi == cur )); then out+=("  ${C_TITLE}▶${C_RESET} ${displays[oi]}")
        else                     out+=("    ${displays[oi]}"); fi
      else
        out+=("")
      fi
    done
    if (( nvis > 0 )); then out+=("  ${C_GRAY}$((cur+1))/${nvis}${C_RESET}")
    else                    out+=("  ${C_GRAY}0/${total}${C_RESET}"); fi
    out+=("$S_HR")
    if (( nvis > 0 )); then
      _ad "${vis[cur]}"
    else
      det=("$S_NOMATCH" "" "" "" "" "")
    fi
    local dl
    for dl in "${det[@]}"; do out+=("$dl"); done
    out+=("$S_FOOT")

    printf '\033[H' >/dev/tty
    local L
    for L in "${out[@]}"; do printf '\r\033[K%s\n' "$L" >/dev/tty; done
  }

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
    printf "\033[?1007l\033[?25h\033[?7h\033[?1049l" 2>/dev/null >/dev/tty || true
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
  printf '\033[?1007l\033[?25h\033[?7h\033[?1049l' >/dev/tty

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

  case "$filter" in
    free) banner "Aidevix CLI" "$(t '🆓 bepul agentlar — login/kalitsiz yoki bepul tier')" ;;
    top)  banner "Aidevix CLI" "$(t '⭐ eng mashhur agentlar — vibecoding uchun')" ;;
    *)    banner ;;
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
      rows="$(awk -F'\t' '$8 ~ /🆓/ || tolower($8) ~ /bepul|free/' <<<"$rows")"
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
  if command -v fzf >/dev/null 2>&1; then
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
    # fzf yo'q, lekin TTY bor — ichki ↑/↓ menyu (to'liq ma'lumotli).
    name="$(select_with_arrows "$menu" "$datafile")" || rc=$?
    if (( rc == 2 )); then
      log_warn "$(t "Interaktiv menyu ochilmadi — raqamli menyuga o'tildi.")"
      rc=0; name="$(select_with_numbers "$menu")"
    elif (( rc == 130 )); then
      exit 130                                 # Ctrl+C — menyu o'zi tozalagan
    fi
  else
    # TTY ham yo'q (quvur/CI) — oddiy raqamli menyu (stdin'dan o'qiydi).
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
  local ans="" prompt; prompt="$(t "❓ '%s' hozir o'rnatilsinmi? [y/N] " "$name")"
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
    panel "$(t "❌ '%s' o'rnatilmadi — avval bitta dastur kerak" "$name")" \
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
      panel "$(t "🚫 '%s' bu operatsion tizimda qo'llab-quvvatlanmaydi" "$name")" \
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
      panel "$(t "🕒 '%s' o'rnatilmadi — kompyuter soati noto'g'ri ko'rinadi" "$name")" \
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

    panel "$(t "❌ '%s' o'rnatishda xatolik yuz berdi" "$name")" \
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
    panel "$(t "⚠️  '%s' o'rnatildi, lekin hali ishga tushmadi" "$name")" \
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
  banner "$(t 'Aidevix — Tashxis')" "$(t 'muhitingizni tekshiramiz')"

  local tool
  printf '%s%s%s\n' "${C_BOLD:-}" "$(t 'Vositalar:')" "${C_RESET:-}"
  for tool in bash fzf node npm python3 curl git; do
    if command -v "$tool" >/dev/null 2>&1; then
      printf '  %b✓%b %-8s %s\n' "${C_GREEN:-}" "${C_RESET:-}" "$tool" "$(command -v "$tool")"
    else
      printf '  %b✗%b %-8s %s\n' "${C_RED:-}" "${C_RESET:-}" "$tool" "$(t 'topilmadi')"
    fi
  done

  printf '\n%s%s%s\n' "${C_BOLD:-}" "$(t 'PATH tekshiruvi:')" "${C_RESET:-}"
  if command -v npm >/dev/null 2>&1; then
    local prefix bindir
    prefix="$(npm config get prefix 2>/dev/null || true)"
    printf '  npm prefix: %s\n' "${prefix:-$(t '(aniqlanmadi)')}"
    for bindir in "$prefix/bin" "$prefix"; do
      [[ -d "$bindir" ]] || continue
      if [[ ":$PATH:" == *":$bindir:"* ]]; then
        printf '  %b✓%b %s %s\n' "${C_GREEN:-}" "${C_RESET:-}" "$(t 'PATH ichida:')" "$bindir"
      else
        printf '  %b✗%b %s\n' "${C_YELLOW:-}" "${C_RESET:-}" "$(t "PATH da YO'Q: %s  (aidevix uni o'zi qo'shadi)" "$bindir")"
      fi
    done
  else
    printf '  %b!%b %s\n' "${C_YELLOW:-}" "${C_RESET:-}" "$(t "npm topilmadi — npm orqali o'rnatiladigan agentlar ishlamaydi.")"
  fi
  if [[ -d "$HOME/.local/bin" ]]; then
    if [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
      printf '  %b✓%b %s %s\n' "${C_GREEN:-}" "${C_RESET:-}" "$(t 'PATH ichida:')" "$HOME/.local/bin"
    else
      printf '  %b✗%b %s %s\n' "${C_YELLOW:-}" "${C_RESET:-}" "$(t "PATH da YO'Q:")" "$HOME/.local/bin"
    fi
  fi

  printf '\n%s%s%s\n' "${C_BOLD:-}" "$(t 'Global statistika:')" "${C_RESET:-}"
  if global_stats_enabled; then
    printf '  %b✓%b %s\n' "${C_GREEN:-}" "${C_RESET:-}" "$(t 'yoqilgan — server: %s' "$AIDEVIX_STATS_URL")"
    if [[ -r "$GLOBAL_CACHE" ]]; then
      printf '  %b✓%b %s\n' "${C_GREEN:-}" "${C_RESET:-}" "$(t 'kesh mavjud: %s' "$GLOBAL_CACHE")"
    else
      printf '  %b!%b %s\n' "${C_YELLOW:-}" "${C_RESET:-}" "$(t "kesh hali yo'q (keyingi menyuda yangilanadi)")"
    fi
  else
    printf '  %b•%b %s\n' "${C_GRAY:-}" "${C_RESET:-}" "$(t "o'chiq (opt-in). Yoqish: aidevix --stats on")"
  fi

  printf '\n%s%s%s\n' "${C_BOLD:-}" "$(t 'Agentlar holati:')" "${C_RESET:-}"
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
  ( curl -fsS -m 5 "https://registry.npmjs.org/-/package/$NPM_PKG/dist-tags" 2>/dev/null \
      | sed -n 's/.*"latest":"\([0-9][0-9A-Za-z.\-]*\)".*/\1/p' >"$NPM_LATEST_CACHE.tmp" 2>/dev/null \
      && [[ -s "$NPM_LATEST_CACHE.tmp" ]] \
      && mv -f "$NPM_LATEST_CACHE.tmp" "$NPM_LATEST_CACHE" 2>/dev/null \
      && printf '%s\n' "$now" >"$NPM_CHECK_STAMP" 2>/dev/null \
      || rm -f "$NPM_LATEST_CACHE.tmp" 2>/dev/null ) >/dev/null 2>&1 &
  return 0
}

# npm_autoupdate_apply <latest> [orig-args...] — yangi versiyaga yangilashni
# TAKLIF qiladi. Foydalanuvchi tasdiqlasa (std = ha) `npm i -g pkg@latest` qilib,
# joriy jarayonni YANGI versiya bilan qayta ishga tushiradi (exec). Shu yo'l bilan
# eski/crash beradigan versiyadagi userni avtomatik chiqarib olamiz. Rad etsa yoki
# o'rnatish muvaffaqiyatsiz bo'lsa — passiv eslatmaga qaytish uchun 1 qaytaradi.
npm_autoupdate_apply() {
  AIDEVIX_PHASE="update"
  local latest="$1"; shift
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
    log_ok "$(t 'Yangilandi (%s). Qayta ishga tushmoqda…' "$latest")"
    # `exec bash "$SELF"` — `exec "$0"` EMAS. Ikki sabab:
    #   1) npm orqali chaqirilganda $0 Windows uslubidagi yo'l bo'lishi mumkin
    #      (`C:\...\ai-selector.sh`, bin/cli.js shunday uzatadi) — uni to'g'ridan
    #      exec qilish shebang'ga tayanadi va MSYS'da ishonchsiz;
    #   2) skript endigina npm tomonidan QAYTA YOZILDI; bash skript faylini
    #      dangasa (lazy) o'qiydi, shuning uchun yangi jarayonni aniq interpretator
    #      bilan boshlagan ma'qul. auto_update ham xuddi shunday qiladi.
    trap - ERR
    cleanup 2>/dev/null || true
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

  # Interaktiv sessiya + npm bor → yangilashni TAKLIF qilamiz (tasdiqlasa exec).
  # Tasdiqlanib yangilansa, apply qaytmaydi (exec). Rad etilsa 1 qaytaradi →
  # pastdagi passiv eslatmaga tushadi. `[[ -t 0 ]]` SHART: quvur/CI/bats kabi
  # nointeraktiv holatda taklif qilmaymiz (aks holda promptда osilib qoladi).
  if command -v npm >/dev/null 2>&1 && [[ -t 0 ]] && { : >/dev/tty; } 2>/dev/null; then
    npm_autoupdate_apply "$latest" "$@" && return 0
  fi

  panel "$(t '🔄 Aidevix yangi versiya bor (%s → %s)' "$AIDEVIX_VERSION" "$latest")" \
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
    preview_agent "${2:-}" "${3:-}"
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
