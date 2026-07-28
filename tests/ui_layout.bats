#!/usr/bin/env bats
# ui_layout.bats — ikki ustunli menyu maketi, status bar va ma'lumot
# normallashtirish (authclass / provider).
#
# Menyu odatda TTY talab qiladi; test uchun AIDEVIX_UI_DUMP=1 seam'i bor —
# u BITTA kadrni stdout'ga chizib qaytadi (interaktiv tsiklga kirmasdan).

load test_helper

setup() {
  setup_env
  unset NO_COLOR
  export FORCE_COLOR=1
  export AI_PULT_CONFIG="$FIXTURE_CONFIG"
  load_selector
}

# frame <ustun> <qator> [qidiruv] — bitta kadrni ANSI'siz qaytaradi.
frame() {
  local cols="${1:-100}" rows="${2:-24}" q="${3:-}"
  local config rows_data datafile menu
  UI_COLS=""                                  # kenglik keshini tozalaymiz
  export COLUMNS="$cols"
  config="$(resolve_config)"
  rows_data="$(build_rows "$config")"
  datafile="$BATS_TEST_TMPDIR/data.tsv"
  printf '%s\n' "$rows_data" >"$datafile"
  menu="$(build_menu "$rows_data" /dev/null /dev/null "")"
  # tput TTY'siz ishlamaydi — balandlikni o'zimiz beramiz.
  tput() { if [ "$1" = lines ]; then printf '%s' "$rows"; else command tput "$@"; fi; }
  AIDEVIX_UI_DUMP=1 AIDEVIX_UI_DUMP_QUERY="$q" \
    select_with_arrows "$menu" "$datafile" 2>/dev/null \
    | sed 's/\x1b\[[0-9;]*[A-Za-z]//g'
}

# --- Ikki ustunli maket ---------------------------------------------------

# Ajratgich belgisi POG'ONAGA bog'liq: unicode'da '│', ascii'da '|'. Testlar
# LC_ALL=C bilan ishlaydi (ya'ni ascii pog'ona), shuning uchun belgini
# qattiq yozib qo'ymay, ICO jadvalidan olamiz.
sep_char() { printf '%s' "${ICO[sep]}"; }

# body_of <ramka> — pastki uch qatorni (chiziq + status bar + footer) olib
# tashlaydi. Status bar HAM ajratgich ishlatadi, lekin u maket ustuni EMAS —
# tekislash tekshiruvlariga aralashmasligi kerak.
body_of() { printf '%s\n' "$1" | head -n -3; }

@test "maket: keng terminalda IKKI USTUN chiziladi (ajratgich bilan)" {
  local out s
  out="$(frame 110 26)"; s="$(sep_char)"
  # Ro'yxat qatorlarida vertikal ajratgich bo'lishi shart.
  [[ "$out" == *"Alpha CLI"* ]]
  local sep_lines
  sep_lines="$(body_of "$out" | grep -cF "$s" || true)"
  [ "$sep_lines" -ge 3 ]
}

@test "maket: o'ng ustunda tanlangan agent tafsiloti ko'rinadi" {
  local out
  out="$(frame 110 26)"
  # Tafsilot yorliqlari (buyruq/guruh/provayder) o'ng ustunda.
  [[ "$out" == *"buyruq"* ]] || [[ "$out" == *"command"* ]]
  [[ "$out" == *"provayder"* ]] || [[ "$out" == *"provider"* ]]
}

@test "maket: tor terminalda ikki ustun O'CHADI (stacked zaxira)" {
  local out s
  out="$(frame 70 24)"; s="$(sep_char)"
  [[ "$out" == *"Alpha CLI"* ]]
  # 70 ustunda ajratgichli ikki ustun bo'lmasligi kerak.
  local sep_lines
  sep_lines="$(body_of "$out" | grep -cF "$s" || true)"
  [ "$sep_lines" -eq 0 ]
}

@test "maket: hech bir qator terminal enidan oshmaydi" {
  local out line maxw=110
  out="$(frame "$maxw" 26)"
  while IFS= read -r line; do
    [ "${#line}" -le "$maxw" ] || {
      echo "qator juda uzun (${#line} > $maxw): $line"; return 1
    }
  done <<<"$out"
}

@test "maket: ustun ajratgichi HAMMA qatorda bir xil o'rinda" {
  # Ikki ustunli maketning butun ma'nosi shu: ajratgich qimirlamasin.
  local out line pos first="" s
  out="$(frame 110 26)"; s="$(sep_char)"
  while IFS= read -r line; do
    case "$line" in
      *"$s"*) : ;;
      *) continue ;;
    esac
    pos="${line%%"$s"*}"
    if [ -z "$first" ]; then first="${#pos}"; else
      [ "${#pos}" -eq "$first" ] || {
        echo "ajratgich siljidi: ${#pos} != $first"; return 1
      }
    fi
  done < <(body_of "$out")
  [ -n "$first" ]
}

# --- Qidiruv --------------------------------------------------------------

@test "maket: qidiruv ro'yxatni filtrlaydi" {
  local out
  out="$(frame 110 26 alpha)"
  [[ "$out" == *"Alpha CLI"* ]]
  [[ "$out" != *"Bravo CLI"* ]]
}

@test "maket: mos kelmaydigan qidiruvda tushuntirish beradi" {
  local out
  out="$(frame 110 26 zzzznomavjud)"
  [[ "$out" == *"0/"* ]]
}

@test "maket: past terminalda YOLG'IZ bo'lim sarlavhasi qolmaydi" {
  # Tafsilot paneli balandligi yetmasa "o'rnatish" sarlavhasi ko'rinib,
  # buyrug'ining o'zi kesilib qolardi — foydalanuvchi bo'sh sarlavha ko'rardi.
  detail_init
  local label="$DL_L_INSTALL" out
  [ -n "$label" ]
  # 20 qatorli terminal: panel aynan sarlavha ustida tugaydi.
  out="$(frame 100 20)"
  if [[ "$out" == *"$label"* ]]; then
    # Sarlavha ko'rinsa — tanasi (o'rnatish buyrug'i) ham ko'rinishi SHART.
    [[ "$out" == *"npm install -g alpha"* ]]
  fi
}

@test "maket: baland terminalda o'rnatish bo'limi TO'LIQ ko'rinadi" {
  # Teskari tomoni: joy yetganda sarlavha ham, buyruq ham chiqishi kerak.
  detail_init
  local out
  out="$(frame 100 30)"
  [[ "$out" == *"$DL_L_INSTALL"* ]]
  [[ "$out" == *"npm install -g alpha"* ]]
}

@test "maket: ascii pog'onasida BUTUN ramka faqat ASCII belgilardan iborat" {
  # ascii pog'ona aynan UTF-8 ko'tarmaydigan terminallar uchun. Bitta literal
  # unicode belgi (masalan footer'dagi '↑↓' yoki status bar'dagi '—') o'sha
  # yerda buzuq kvadratcha bo'lib chiqadi — shuning uchun butun kadr tekshiriladi.
  AIDEVIX_ICONS=ascii ui_icons_set ascii
  local out
  out="$(frame 100 24)"
  [ -n "$out" ]
  ! printf '%s' "$out" | LC_ALL=C grep -q '[^[:print:][:space:]]'
}

@test "maket: footer eng tor (40 ustun) terminalga ham sig'adi" {
  # ui_width 40 ustunda pol qo'yadi — footer o'sha kenglikda 44 belgi bo'lib
  # o'ralib ketardi va butun ramkani buzardi.
  local out line
  out="$(frame 40 24)"
  while IFS= read -r line; do
    [ "${#line}" -le 40 ] || { echo "qator juda uzun (${#line} > 40): $line"; return 1; }
  done <<<"$out"
}

# --- Status bar -----------------------------------------------------------

@test "status bar: agentlar sanog'i va versiya ko'rsatiladi" {
  local out
  out="$(frame 110 26)"
  [[ "$out" == *"/"* ]]                       # "N/M o'rnatilgan"
  [[ "$out" == *"v$AIDEVIX_VERSION"* ]]
}

@test "status bar: TO'QIB CHIQARILGAN token/kontekst ko'rsatkichi YO'Q" {
  # Aidevix LLM API'ga murojaat qilmaydi — token/kontekst sarfini O'LCHAY
  # OLMAYDI. Bunday maydon paydo bo'lsa, u yolg'on ma'lumot bo'lardi.
  local out
  out="$(frame 110 26)"
  [[ "$out" != *"token"* ]]
  [[ "$out" != *"ctx"* ]]
  [[ "$out" != *"context"* ]]
}

@test "status bar: model muhitda berilmagan bo'lsa '—' ko'rsatadi" {
  unset ANTHROPIC_MODEL OPENAI_MODEL GEMINI_MODEL
  local out
  out="$(frame 110 26)"
  [[ "$out" == *"—"* ]] || [[ "$out" == *"-"* ]]
}

@test "status bar: latency hech qachon o'lchanmagan bo'lsa ko'rsatilmaydi" {
  rm -f "$LATENCY_FILE" 2>/dev/null || true
  run status_latency_field
  [ -z "$output" ]
}

@test "status bar: latency o'lchovi millisekundga aylantiriladi" {
  mkdir -p "$STATE_DIR"
  printf '0.142\n' >"$LATENCY_FILE"
  run status_latency_field
  [[ "$output" == *"142ms"* ]]
}

# --- Ma'lumot normallashtirish -------------------------------------------

@test "classify_auth: emoji va matnni bir xil tushunadi" {
  [ "$(classify_auth '🆓 bepul tier')" = "free" ]
  [ "$(classify_auth 'free tier')" = "free" ]
  [ "$(classify_auth '🌐 brauzer login')" = "browser" ]
  [ "$(classify_auth '🔑 ANTHROPIC_API_KEY')" = "key" ]
  [ "$(classify_auth '💳 obuna')" = "paid" ]
  [ "$(classify_auth '')" = "none" ]
}

@test "classify_auth: bepul tier boshqa belgilar bilan birga kelsa ham ustun" {
  # "🆓 bepul tier — 🌐 Google login yoki 🔑 KEY" → foydalanuvchi uchun BEPUL.
  [ "$(classify_auth '🆓 bepul tier — 🌐 login yoki 🔑 GEMINI_API_KEY')" = "free" ]
}

@test "detect_provider: vendor github havolasidan USTUN turadi" {
  # Ko'p agent github.com'da yashaydi — umumiy naqsh vendorni bosib ketmasin.
  [ "$(detect_provider qwen 'npm i -g @qwen-code/qwen' 'https://github.com/QwenLM/qwen')" = "qwen" ]
  [ "$(detect_provider claude 'npm i -g @anthropic-ai/claude-code' 'https://console.anthropic.com')" = "anthropic" ]
  [ "$(detect_provider copilot 'npm i -g @github/copilot' 'https://github.com/features/copilot')" = "github" ]
}

@test "detect_provider: noma'lum agent uchun 'local' qaytaradi" {
  [ "$(detect_provider mytool 'pip install mytool' '')" = "local" ]
}

@test "trim_v: bo'shliqlarni oladi (sof bash, sed'siz)" {
  local out
  trim_v out "   matn   "
  [ "$out" = "matn" ]
  trim_v out ""
  [ "$out" = "" ]
}
