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

# --- Interfeys tanlash (regressiya) ---------------------------------------

@test "run_menu: STANDART interfeys — ichki menyu, fzf emas" {
  # Bu redizaynning butun ma'nosi: ikki ustunli maket, status bar va footer
  # FAQAT select_with_arrows da bor. fzf o'rnatilgan bo'lsa ham u STANDART
  # bo'lib qolmasligi kerak — aks holda foydalanuvchi tekis ro'yxat ko'radi
  # va redizaynni umuman ko'rmaydi (aynan shunday bo'lgan).
  local body
  body="$(awk '/^run_menu\(\) \{/{f=1} f{print} f&&/^\}$/{exit}' "$SELECTOR")"
  # fzf faqat AIDEVIX_USE_FZF bilan yoqiladi.
  [[ "$body" == *'AIDEVIX_USE_FZF'* ]]
  # Asosiy tarmoqlanish `use_fzf` bo'yicha bo'lishi SHART va u birinchi
  # `select_with_*` chaqiruvidan OLDIN kelishi kerak. (fzf ni ichki menyu
  # ochilmagan holatda ZAXIRA sifatida chaqirish — bu boshqa narsa, u mumkin.)
  local gate first
  gate="$(grep -n 'if (( use_fzf ))' <<<"$body" | head -1 | cut -d: -f1)"
  first="$(grep -n 'select_with_' <<<"$body" | head -1 | cut -d: -f1)"
  [ -n "$gate" ]
  [ -n "$first" ]
  [ "$gate" -lt "$first" ]
}

@test "run_menu: fzf ishlamasa ham raqamli menyuga zaxira yo'l bor" {
  local body
  body="$(awk '/^run_menu\(\) \{/{f=1} f{print} f&&/^\}$/{exit}' "$SELECTOR")"
  [[ "$body" == *'select_with_arrows'* ]]
  [[ "$body" == *'select_with_numbers'* ]]
  [[ "$body" == *'select_with_fzf'* ]]
}

# --- Uzun ro'yxat: skroll (regressiya) ------------------------------------
#
# Ro'yxat 47 agentgacha o'sganda menyu ularning atigi 20 tasini ko'rsatardi
# (qattiq `body=20` cheklovi) va skroll indikatori YO'Q edi. Natijada
# ro'yxat oxirgi ko'ringan agentda TUGAGANdek tuyulardi — pastdagi agentlarni
# (Forge, Kimi CLI, Fabric, CodeRabbit, ...) foydalanuvchi topa olmasdi.

# big_frame <ustun> <qator> [nechta-agent] — ko'p agentli konfig bilan kadr.
big_frame() {
  local cols="$1" rows="$2" n="${3:-40}" i
  local cfg="$BATS_TEST_TMPDIR/big.conf"
  : >"$cfg"
  for (( i = 1; i <= n; i++ )); do
    printf 'Agent%02d|nope-%02d|nope-%02d|npm install -g nope|Test agent %02d|Coding|🆓 bepul|\n' \
      "$i" "$i" "$i" "$i" >>"$cfg"
  done
  AI_PULT_CONFIG="$cfg" frame "$cols" "$rows"
}

@test "skroll: ro'yxat balandligi TERMINALGA qarab o'sadi (qattiq 20 cheklovi yo'q)" {
  local out n20 n40
  # 30 qatorli terminal: eski qattiq cheklov 20 ta agentda to'xtatardi.
  out="$(big_frame 110 34 40)"
  n34="$(printf '%s\n' "$out" | grep -cE '(^|[^0-9])Agent[0-9]{2}' || true)"
  [ "$n34" -gt 20 ]
  # Pastroq terminalda esa KAMROQ ko'rinadi — ya'ni balandlik haqiqatan
  # terminalga bog'liq (qattiq son emas).
  out="$(big_frame 110 20 40)"
  n20="$(printf '%s\n' "$out" | grep -cE '(^|[^0-9])Agent[0-9]{2}' || true)"
  [ "$n20" -lt "$n34" ]
}

@test "skroll: oyna ro'yxatdan kalta bo'lsa indikator chiziladi" {
  local out thumb track
  out="$(big_frame 110 26 40)"
  # ascii pog'onasida polzunok '#', yo'lak ':' (ICO jadvalidan olamiz).
  thumb="$(printf '%s' "${ICO[sb_thumb]}")"
  track="$(printf '%s' "${ICO[sb_track]}")"
  [ -n "$thumb" ]
  [ -n "$track" ]
  # Ikkalasi ham bo'lishi SHART: polzunok bor, lekin ro'yxatning qolgan
  # qismini bildiradigan yo'lak ham ko'rinadi.
  [ "$(body_of "$out" | grep -cF "$thumb" || true)" -ge 1 ]
  [ "$(body_of "$out" | grep -cF "$track" || true)" -ge 1 ]
}

@test "skroll: hamma agent sig'sa yo'lak chizilmaydi" {
  local out track
  # 6 ta agent, baland terminal — skroll kerak emas.
  out="$(big_frame 110 30 6)"
  track="$(printf '%s' "${ICO[sb_track]}")"
  [ "$(body_of "$out" | grep -cF "$track" || true)" -eq 0 ]
}

@test "skroll: indikator qatorlarni terminal enidan chiqarib yubormaydi" {
  local out line
  out="$(big_frame 110 34 40)"
  while IFS= read -r line; do
    [ "${#line}" -le 110 ]
  done <<<"$out"
  # Tor (stacked) maketda ham.
  out="$(big_frame 60 24 40)"
  while IFS= read -r line; do
    [ "${#line}" -le 60 ]
  done <<<"$out"
}
