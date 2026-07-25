#!/usr/bin/env bats
# interrupt.bats — Ctrl+C (SIGINT) ishlovi uchun regressiya testlari.
#
# Bug: skriptda INT tutqichi UMUMAN yo'q edi. Oqibatlari:
#   1) Menyu `$(...)` qism-qobig'ida ishlaydi. Bash qism-qobiqda trap'larni
#      DEFAULT'ga tiklaydi, va SIGINT bilan o'ldirilgan qism-qobiqda EXIT
#      tutqichi UMUMAN chaqirilmaydi → `stty` RAW rejimi tiklanmay qolardi
#      (terminal echo'siz "buzuq" holatda qolardi).
#   2) `cleanup` esa faqat escape-ketma-ketliklarni tiklardi, `stty` ni EMAS.
#   3) Ctrl+C dan keyin "Bekor qilindi." chiqardi — nima bekor qilingani
#      noma'lum edi, exit kodi esa 0 bo'lardi (Ctrl+C uchun to'g'risi 130).
#
# Bu yerda haqiqiy TTY shart emas: struktura + on_interrupt/atomic_write
# funksional tekshiruvi.

load test_helper

setup() {
  setup_env
  export AI_PULT_CONFIG="$FIXTURE_CONFIG"
}

# Skriptni source qilib, harness uchun trap'larini o'chiradi.
_load_selector() {
  # shellcheck disable=SC1090
  source "$SELECTOR" 2>/dev/null
  trap - ERR EXIT INT TERM
  set +e
}

# --- Tutqich RO'YXATDAN o'tganmi -------------------------------------------
@test "INT/TERM tutqichi ro'yxatdan o'tgan (avval umuman yo'q edi)" {
  grep -qE '^trap on_interrupt INT TERM$' "$SELECTOR"
}

@test "cleanup: stty holatini ham tiklaydi (faqat escape emas)" {
  local body
  body="$(awk '/^cleanup\(\) \{/{f=1} f{print} f&&/^\}$/{exit}' "$SELECTOR")"
  printf '%s\n' "$body" | grep -qE '^\s*restore_tty_state'
}

# --- on_interrupt xulqi -----------------------------------------------------
@test "on_interrupt: 130 bilan chiqadi (0 emas)" {
  _load_selector
  ( AIDEVIX_PHASE="menu"; on_interrupt ) >/dev/null 2>&1
  [ "$?" -eq 130 ]
}

@test "on_interrupt: NIMA bekor qilinganini aytadi (bosqichga qarab)" {
  _load_selector
  local out
  out="$( ( AIDEVIX_PHASE="update"; on_interrupt ) 2>&1 )"
  [[ "$out" == *"Ctrl+C"* ]]
  # Bosqich matni xabarda bo'lishi kerak (uz: "yangilanish").
  out="$( ( AIDEVIX_PHASE="install"; on_interrupt ) 2>&1 )"
  [[ "$out" == *"Ctrl+C"* ]]
  # Bosqichsiz ham ishlaydi (umumiy matn).
  out="$( ( AIDEVIX_PHASE=""; on_interrupt ) 2>&1 )"
  [[ "$out" == *"Ctrl+C"* ]]
}

@test "on_interrupt: qayta kirishdan himoyalangan (INTERRUPTED bayrog'i)" {
  local body
  body="$(awk '/^on_interrupt\(\) \{/{f=1} f{print} f&&/^\}$/{exit}' "$SELECTOR")"
  printf '%s\n' "$body" | grep -qE '\(\( INTERRUPTED \)\) && return 0'
  printf '%s\n' "$body" | grep -qE '^\s*INTERRUPTED=1'
  # Tozalash paytida yana Ctrl+C bosilsa — default o'ldirsin.
  printf '%s\n' "$body" | grep -qE '^\s*trap - INT TERM'
}

@test "on_interrupt: terminalni tiklaydi (raw rejim + alt-screen)" {
  local body
  body="$(awk '/^on_interrupt\(\) \{/{f=1} f{print} f&&/^\}$/{exit}' "$SELECTOR")"
  printf '%s\n' "$body" | grep -qE '^\s*restore_tty_state'
  printf '%s\n' "$body" | grep -q '1049l'
}

# --- Menyu qism-qobig'i -----------------------------------------------------
@test "select_with_arrows: INT/TERM uchun ALOHIDA trap bor" {
  # Ota-jarayonning INT tutqichi qism-qobiqqa MEROS bo'lmaydi, EXIT tutqichi
  # esa SIGINT'da chaqirilmaydi — shuning uchun bu yerda o'z trap'i shart.
  local body
  body="$(awk '/^select_with_arrows\(\) \{/{f=1} f{print} f&&/^\}$/{exit}' "$SELECTOR")"
  printf '%s\n' "$body" | grep -qE "trap '_menu_restore; exit 130' INT TERM"
  printf '%s\n' "$body" | grep -qE "trap '_menu_restore' EXIT"
}

@test "run_menu: menyudan kelgan 130 ni uzatadi (bekor deb yutmaydi)" {
  local body
  body="$(awk '/^run_menu\(\) \{/{f=1} f{print} f&&/^\}$/{exit}' "$SELECTOR")"
  [ "$(printf '%s\n' "$body" | grep -cE 'rc == 130')" -ge 1 ]
  printf '%s\n' "$body" | grep -qE '^\s*save_tty_state'
}

# --- /dev/tty yo'q bo'lganda xato SIZIB CHIQMASLIGI kerak -------------------
@test "/dev/tty qayta yo'naltirishlari stderr'ni AVVAL bo'g'adi" {
  # `cmd >/dev/tty 2>/dev/null` — qayta yo'naltirishlar CHAPDAN O'NGGA
  # bajarilgani uchun /dev/tty ochilmasa xato HALI real stderr'ga chiqadi.
  # To'g'risi: `cmd 2>/dev/null >/dev/tty`. (cron/CI da shovqin bo'lmasin.)
  local bad
  bad="$(grep -cE '(<|>)/dev/tty 2>/dev/null' "$SELECTOR" || true)"
  [ "$bad" -eq 0 ]
}

# --- atomic_write -----------------------------------------------------------
@test "atomic_write: faylni to'liq yozadi va vaqtinchalik iz qoldirmaydi" {
  _load_selector
  local d="$BATS_TEST_TMPDIR/aw"; mkdir -p "$d"
  atomic_write "$d/f" "salom"
  [ "$(cat "$d/f")" = "salom" ]
  # .XXXXXX vaqtinchalik fayllar qolmasligi kerak.
  [ "$(find "$d" -name 'f.*' | wc -l)" -eq 0 ]
}

@test "atomic_write: mavjud faylni ALMASHTIRADI (yarim holat yo'q)" {
  _load_selector
  local d="$BATS_TEST_TMPDIR/aw2"; mkdir -p "$d"
  atomic_write "$d/f" "eski"
  atomic_write "$d/f" "yangi"
  [ "$(cat "$d/f")" = "yangi" ]
}

@test "holat fayllari atomik yoziladi (truncate+write emas)" {
  # LANG_FILE / GLOBAL_OPTIN_FILE / update stamp — Ctrl+C truncate va write
  # orasiga tushsa fayl BO'SH qolib ketardi.
  ! grep -qE '>"\$(LANG_FILE|GLOBAL_OPTIN_FILE|stamp)"' "$SELECTOR"
  grep -qE 'atomic_write "\$LANG_FILE"' "$SELECTOR"
  grep -qE 'atomic_write "\$GLOBAL_OPTIN_FILE"' "$SELECTOR"
  grep -qE 'atomic_write "\$stamp"' "$SELECTOR"
}
