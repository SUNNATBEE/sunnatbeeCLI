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
@test "build_menu: ko'p ishlatilgan agent O'Z GURUHIDA yuqorida turadi" {
  # ESLATMA: saralashda O'RNATILGANLIK sanoqdan USTUN turadi (o'rnatilganlar
  # doim tepada). Fixture'da faqat "Alpha CLI" o'rnatilgan, shuning uchun
  # sanoqning ta'sirini O'RNATILMAGANLAR guruhi ichida tekshiramiz.
  export AI_PULT_CONFIG="$FIXTURE_CONFIG"
  record_usage "Charlie"
  record_usage "NoInstall"
  record_usage "NoInstall"   # NoInstall = 2 → o'rnatilmaganlar ichida tepada
  local rows; rows="$(build_rows "$FIXTURE_CONFIG")"
  run build_menu "$rows" "$STATS_FILE"
  [ "$status" -eq 0 ]
  # O'rnatilgan Alpha CLI — eng tepada.
  local first; first="$(printf '%s\n' "$output" | head -1)"
  [[ "$first" == *"Alpha CLI"* ]]
  # O'rnatilmaganlar ichida NoInstall (2×) Charlie (1×) dan tepada.
  local pos_ni pos_ch
  pos_ni="$(printf '%s\n' "$output" | grep -n 'NoInstall' | head -1 | cut -d: -f1)"
  pos_ch="$(printf '%s\n' "$output" | grep -n 'Charlie'   | head -1 | cut -d: -f1)"
  [ "$pos_ni" -lt "$pos_ch" ]
  # Sanoq belgisi "2×" ko'rinishi kerak.
  [[ "$(printf '%s\n' "$output" | grep 'NoInstall')" == *"2×"* ]]
}

@test "build_menu: O'RNATILGAN agentlar o'rnatilmaganlardan TEPADA" {
  # Foydalanuvchi darhol ishlata oladigan agentni qidirib o'tirmasligi kerak.
  export AI_PULT_CONFIG="$FIXTURE_CONFIG"
  local rows; rows="$(build_rows "$FIXTURE_CONFIG")"
  run build_menu "$rows" "$STATS_FILE"
  [ "$status" -eq 0 ]
  # Fixture'da yagona o'rnatilgan agent — "Alpha CLI" (binari `bash`).
  local first; first="$(printf '%s\n' "$output" | head -1)"
  [[ "$first" == *"Alpha CLI"* ]]
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
