#!/usr/bin/env bats
# cli.bats — CLI sathidagi (qora-quti) xulq-atvor testlari.

load test_helper

setup() {
  setup_env
  export AI_PULT_CONFIG="$FIXTURE_CONFIG"
}

# --- --version / --help ---------------------------------------------------
@test "--version: versiyani VERSION faylidan chiqaradi" {
  run_cli --version
  [ "$status" -eq 0 ]
  local ver
  ver="$(cat "$PROJECT_ROOT/VERSION")"
  [[ "$output" == *"Aidevix CLI"* ]]
  [[ "$output" == *"$ver"* ]]
}

@test "-v: --version bilan bir xil" {
  run_cli -v
  [ "$status" -eq 0 ]
  [[ "$output" == *"Aidevix CLI"* ]]
}

@test "--help: foydalanish matnini ko'rsatadi" {
  run_cli --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"FOYDALANISH"* ]]
  [[ "$output" == *"--list"* ]]
}

# --- --list ---------------------------------------------------------------
@test "--list: fixture'dagi agentlarni ko'rsatadi" {
  run_cli --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"Alpha CLI"* ]]
  [[ "$output" == *"Bravo CLI"* ]]
}

@test "--list: o'rnatilgan/yo'q holatini ko'rsatadi" {
  run_cli --list
  [ "$status" -eq 0 ]
  # Holat MATNI tekshiriladi, belgi emas: belgi ikonka pog'onasiga bog'liq
  # (nerd/unicode/ascii), matn esa barqaror shartnoma.
  [[ "$output" == *"o'rnatilgan"* ]]
  [[ "$output" == *"yo'q"* ]]
}

@test "--list: chiqish STDOUT'ga ketadi (quvurga tushadi)" {
  # `aidevix --list | grep ...` ishlashi kerak — jadval stdout'da bo'lsin,
  # log/menyu esa stderr'da qolsin.
  run bash -c "bash '$SELECTOR' --list 2>/dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Alpha CLI"* ]]
}

@test "--list: ustunlar holat uzunligidan qat'i nazar tekis turadi" {
  # Rangli/belgili ustunlarni `%-Ns` bilan to'ldirib bo'lmaydi (ANSI baytlari
  # ham sanaladi) — to'ldirish ui_pad_v bilan qilinadi. Alpha (o'rnatilgan,
  # Coding) va Bravo (yo'q, Local) da GURUH ustuni bir joydan boshlanishi shart.
  run_cli --list
  [ "$status" -eq 0 ]
  local alpha bravo pa pb
  alpha="$(printf '%s\n' "$output" | grep 'Alpha CLI')"
  bravo="$(printf '%s\n' "$output" | grep 'Bravo CLI')"
  pa="${alpha%%Coding*}"
  pb="${bravo%%Local*}"
  [ "${#pa}" -eq "${#pb}" ]
}

@test "--list: interfeysda emoji qolmaydi" {
  run_cli --list
  [ "$status" -eq 0 ]
  [[ "$output" != *"🆓"* ]]
  [[ "$output" != *"🔑"* ]]
  [[ "$output" != *"🌐"* ]]
  [[ "$output" != *"💳"* ]]
  [[ "$output" != *"⭐"* ]]
}

# --- Noto'g'ri argumentlar ------------------------------------------------
@test "noma'lum tanlov (--badflag) → exit 2" {
  run_cli --badflag
  [ "$status" -eq 2 ]
  [[ "$output" == *"Noma'lum tanlov"* ]]
}

@test "mos kelmaydigan agent nomi → exit 2" {
  run_cli yyyzzz-mavjud-emas
  [ "$status" -eq 2 ]
  [[ "$output" == *"Mos agent topilmadi"* ]]
}

# --- __preview qism-jarayoni ---------------------------------------------
@test "__preview: berilgan agent tafsilotini chiqaradi" {
  # Preview datafile build_rows formatida bo'lishi kerak.
  local datafile="$BATS_TEST_TMPDIR/rows.tsv"
  bash "$SELECTOR" --list >/dev/null 2>&1 || true
  # build_rows chiqishini to'g'ridan-to'g'ri hosil qilamiz.
  bash -c 'source "'"$SELECTOR"'"; set +eEu; trap - ERR EXIT; build_rows "'"$FIXTURE_CONFIG"'"' > "$datafile"
  run bash "$SELECTOR" __preview "Alpha CLI" "$datafile"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Alpha CLI"* ]]
}

# --- quick_launch resolutsiyasi (launch_agent stub bilan) ----------------
# Haqiqiy ishga tushirishni (exec) o'rniga stub qo'yib, faqat tanlov mantig'ini
# tekshiramiz.
@test "quick_launch: aniq nom bo'yicha agentni topadi" {
  load_selector
  ensure_installed() { :; }
  maybe_show_auth_note() { :; }
  save_last() { :; }
  launch_agent() { printf 'LAUNCH|%s|%s|%s\n' "$1" "$2" "$3"; }
  export AI_PULT_CONFIG="$FIXTURE_CONFIG"
  run quick_launch "Alpha CLI"
  [ "$status" -eq 0 ]
  [[ "$output" == "LAUNCH|Alpha CLI|bash|bash -c true" ]]
}

@test "quick_launch: binar nomi bo'yicha (katta-kichik harf farqsiz) topadi" {
  load_selector
  ensure_installed() { :; }
  maybe_show_auth_note() { :; }
  save_last() { :; }
  launch_agent() { printf 'LAUNCH|%s\n' "$1"; }
  export AI_PULT_CONFIG="$FIXTURE_CONFIG"
  run quick_launch "CHARLIEBIN"
  [ "$status" -eq 0 ]
  [[ "$output" == "LAUNCH|Charlie" ]]
}

@test "quick_launch: qisman moslik bilan topadi" {
  load_selector
  ensure_installed() { :; }
  maybe_show_auth_note() { :; }
  save_last() { :; }
  launch_agent() { printf 'LAUNCH|%s\n' "$1"; }
  export AI_PULT_CONFIG="$FIXTURE_CONFIG"
  run quick_launch "brav"
  [ "$status" -eq 0 ]
  [[ "$output" == "LAUNCH|Bravo CLI" ]]
}

# --- npm launcher (bin/cli.js) --------------------------------------------
# Windows'da `where bash` KO'PINCHA C:\Windows\System32\bash.exe (WSL) ni
# birinchi qaytaradi. Uni ishga tushirsak Linux fayl tizimiga tushib qolamiz,
# `C:\...\ai-selector.sh` topilmaydi va CLI JIM yopiladi — global npm
# o'rnatishdagi "menyu ochilmay yopiladi" shikoyatining sabablaridan biri.
@test "cli.js: WSL (System32) bash'ini rad etadi" {
  command -v node >/dev/null 2>&1 || skip "node yo'q"
  grep -q 'isWslBash' "$PROJECT_ROOT/bin/cli.js"
  grep -q 'System32' "$PROJECT_ROOT/bin/cli.js"
  # Git Bash joylari PATH probe'idan OLDIN tekshirilishi kerak.
  local gitline probeline
  gitline="$(grep -n 'gitCandidates' "$PROJECT_ROOT/bin/cli.js" | head -1 | cut -d: -f1)"
  probeline="$(grep -n "spawnSync(win ? 'where'" "$PROJECT_ROOT/bin/cli.js" | head -1 | cut -d: -f1)"
  [ -n "$gitline" ] && [ -n "$probeline" ] && [ "$gitline" -lt "$probeline" ]
}

@test "cli.js: jim o'lmaydi — uncaught/unhandled tutiladi" {
  grep -q "uncaughtException" "$PROJECT_ROOT/bin/cli.js"
  grep -q "unhandledRejection" "$PROJECT_ROOT/bin/cli.js"
  # Signal bilan to'xtaganda ham sabab yoziladi.
  grep -q "res.status === null" "$PROJECT_ROOT/bin/cli.js"
}

@test "cli.js: --version node orqali ishlaydi" {
  command -v node >/dev/null 2>&1 || skip "node yo'q"
  run node "$PROJECT_ROOT/bin/cli.js" --version
  [ "$status" -eq 0 ]
  [[ "$output" == *"Aidevix CLI"* ]]
}
