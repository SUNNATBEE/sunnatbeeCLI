#!/usr/bin/env bats
# usage.bats — lokal ishlatish statistikasi (record_usage / read_usage /
# build_menu tartibi) uchun testlar.
#
# Statistika FAQAT shu kompyuterda ($STATS_FILE) saqlanadi — tashqariga
# yuborilmaydi. Menyu va --list eng ko'p ishlatilgan agent bo'yicha tartiblanadi.

load test_helper

setup() {
  setup_env
  load_selector
}

# --- record_usage / read_usage --------------------------------------------
@test "read_usage: noma'lum agent uchun 0 qaytaradi" {
  run read_usage "Yo'q-Agent"
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "record_usage: yangi agent sanog'i 1 dan boshlanadi" {
  record_usage "Alpha CLI"
  run read_usage "Alpha CLI"
  [ "$output" = "1" ]
}

@test "record_usage: takror chaqirilsa sanoq oshadi" {
  record_usage "Bravo CLI"
  record_usage "Bravo CLI"
  record_usage "Bravo CLI"
  run read_usage "Bravo CLI"
  [ "$output" = "3" ]
}

@test "record_usage: turli agentlar mustaqil sanaladi" {
  record_usage "Alpha CLI"
  record_usage "Alpha CLI"
  record_usage "Charlie"
  run read_usage "Alpha CLI"
  [ "$output" = "2" ]
  run read_usage "Charlie"
  [ "$output" = "1" ]
}

@test "record_usage: bo'sh nom statistikani o'zgartirmaydi" {
  record_usage ""
  [ ! -s "$STATS_FILE" ] || [ -z "$(cat "$STATS_FILE" 2>/dev/null)" ]
}

# --- build_menu tartibi (eng ko'p ishlatilgan tepada) ----------------------
@test "build_menu: ko'p ishlatilgan agent yuqorida turadi" {
  export AI_PULT_CONFIG="$FIXTURE_CONFIG"
  record_usage "Charlie"
  record_usage "NoInstall"
  record_usage "NoInstall"   # NoInstall = 2 → eng tepada
  local rows; rows="$(build_rows "$FIXTURE_CONFIG")"
  run build_menu "$rows" "$STATS_FILE"
  [ "$status" -eq 0 ]
  # Birinchi qatorning yashirin NAME maydoni (TAB'dan keyin) NoInstall bo'lsin.
  local first; first="$(printf '%s\n' "$output" | head -1)"
  [[ "$first" == *"NoInstall"* ]]
  # Sanoq belgisi "·2×" ko'rinishi kerak.
  [[ "$first" == *"2×"* ]]
}

@test "build_menu: oxirgi ishlatilgan agent hammadan tepada ('oxirgi' belgisi bilan)" {
  export AI_PULT_CONFIG="$FIXTURE_CONFIG"
  record_usage "Alpha CLI"
  record_usage "Alpha CLI"       # boshqa agent ko'proq ishlatilgan bo'lsa ham
  local rows; rows="$(build_rows "$FIXTURE_CONFIG")"
  run build_menu "$rows" "$STATS_FILE" "" "Charlie"
  [ "$status" -eq 0 ]
  local first; first="$(printf '%s\n' "$output" | head -1)"
  [[ "$first" == *"Charlie"* ]]
  # Belgi POG'ONAGA bog'liq: unicode'da '↩', ascii'da '<'. Testlar LC_ALL=C
  # bilan (ya'ni ascii) ishlagani uchun belgini ICO jadvalidan olamiz.
  [[ "$first" == *"${ICO[last]}"* ]]
}

@test "build_menu: statistikasiz config tartibini saqlaydi (barqaror)" {
  export AI_PULT_CONFIG="$FIXTURE_CONFIG"
  local rows; rows="$(build_rows "$FIXTURE_CONFIG")"
  run build_menu "$rows" "$STATS_FILE"
  [ "$status" -eq 0 ]
  # Hech narsa ishlatilmagan — birinchi config qatori "Alpha CLI" tepada.
  local first; first="$(printf '%s\n' "$output" | head -1)"
  [[ "$first" == *"Alpha CLI"* ]]
}
