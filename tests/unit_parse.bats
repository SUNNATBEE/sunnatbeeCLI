#!/usr/bin/env bats
# unit_parse.bats — config parsing va sof yordamchi funksiyalar uchun unit testlar.

load test_helper

setup() {
  setup_env
  load_selector
}

# --- trim -----------------------------------------------------------------
@test "trim: ikki tomondagi bo'shliqlarni olib tashlaydi" {
  run trim "   salom dunyo   "
  [ "$status" -eq 0 ]
  [ "$output" = "salom dunyo" ]
}

@test "trim: bo'shliqsiz matnni o'zgartirmaydi" {
  run trim "claude"
  [ "$output" = "claude" ]
}

@test "trim: faqat bo'shliqdan iborat matnni bo'sh qaytaradi" {
  run trim "      "
  [ "$output" = "" ]
}

# --- detect_install_tool --------------------------------------------------
@test "detect_install_tool: npm buyrug'ini aniqlaydi" {
  run detect_install_tool "npm install -g @anthropic-ai/claude-code@latest"
  [ "$output" = "npm" ]
}

@test "detect_install_tool: pip/python3 buyrug'ini aniqlaydi" {
  run detect_install_tool "python3 -m pip install --user aider-chat"
  [ "$output" = "python3" ]
}

@test "detect_install_tool: brew buyrug'ini aniqlaydi" {
  run detect_install_tool "brew install gh"
  [ "$output" = "brew" ]
}

@test "detect_install_tool: curl buyrug'ini aniqlaydi" {
  run detect_install_tool 'bash -c "$(curl -fsSL https://example.com/i.sh)"'
  [ "$output" = "curl" ]
}

@test "detect_install_tool: noma'lum buyruq uchun bo'sh qaytaradi" {
  run detect_install_tool "magic-installer do-it"
  [ "$output" = "" ]
}

# --- parse_agents ---------------------------------------------------------
@test "parse_agents: fixture'dagi barcha 4 agentni qaytaradi" {
  run parse_agents "$FIXTURE_CONFIG"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 4 ]
}

@test "parse_agents: izoh va bo'sh qatorlarni o'tkazib yuboradi" {
  run parse_agents "$FIXTURE_CONFIG"
  # Birinchi qator Alpha CLI bo'lishi kerak (izohlar emas).
  [[ "${lines[0]}" == "Alpha CLI"* ]]
}

@test "parse_agents: bo'sh kategoriyani DEFAULT_CATEGORY (AI) bilan to'ldiradi" {
  run parse_agents "$FIXTURE_CONFIG"
  # Charlie qatorida kategoriya BO'SH edi → "AI" bo'lishi kerak.
  # Format: NAME\tDESC\tBINARY\tCOMMAND\tINSTALL\tCATEGORY\tAUTH\tURL
  local charlie
  charlie="$(printf '%s\n' "${lines[@]}" | grep '^Charlie')"
  local category
  category="$(printf '%s' "$charlie" | cut -f6)"
  [ "$category" = "AI" ]
}

@test "parse_agents: bo'sh fayl uchun die (exit 1)" {
  local empty="$BATS_TEST_TMPDIR/empty.conf"
  printf '# faqat izoh\n\n' > "$empty"
  run parse_agents "$empty"
  [ "$status" -eq 1 ]
}

# --- build_rows (holat ustuni) -------------------------------------------
# STATUS endi MASHINA O'QIYDIGAN token ("installed"/"missing"), belgi/tarjima
# emas. Belgiga (✓/●/*) aylantirish faqat CHIZISH bosqichida bo'ladi va
# ikonka pog'onasiga bog'liq — shuning uchun test tokenni tekshiradi.
@test "build_rows: mavjud binar uchun 'installed' tokeni beradi" {
  run build_rows "$FIXTURE_CONFIG"
  local alpha
  alpha="$(printf '%s\n' "${lines[@]}" | grep '^Alpha CLI')"
  # 7-maydon = status. Alpha binari = bash → mavjud.
  [ "$(printf '%s' "$alpha" | cut -f7)" = "installed" ]
}

@test "build_rows: mavjud bo'lmagan binar uchun 'missing' tokeni beradi" {
  run build_rows "$FIXTURE_CONFIG"
  local bravo
  bravo="$(printf '%s\n' "${lines[@]}" | grep '^Bravo CLI')"
  [ "$(printf '%s' "$bravo" | cut -f7)" = "missing" ]
}

@test "build_rows: authclass va provider maydonlarini qo'shadi (10, 11)" {
  run build_rows "$FIXTURE_CONFIG"
  local alpha
  alpha="$(printf '%s\n' "${lines[@]}" | grep '^Alpha CLI')"
  # Fixture'dagi Alpha AUTH maydoni 🔑 bilan → authclass "key".
  [ "$(printf '%s' "$alpha" | cut -f10)" = "key" ]
  # Provider bo'sh bo'lmasligi kerak (aniqlanmasa ham "local" qaytadi).
  [ -n "$(printf '%s' "$alpha" | cut -f11)" ]
}

@test "build_rows: DESC va AUTH maydonlaridan emoji olib tashlanadi" {
  run build_rows "$FIXTURE_CONFIG"
  # Butun chiqishda auth/desc emoji belgilari qolmasligi kerak.
  [[ "$output" != *"🔑"* ]]
  [[ "$output" != *"🆓"* ]]
  [[ "$output" != *"🌐"* ]]
  [[ "$output" != *"💳"* ]]
}

# --- should_open_login_link ----------------------------------------------
@test "should_open_login_link: 🔑 kalit kerak va muhitda yo'q → 0 (link ochiladi)" {
  run should_open_login_link "🔑 ALPHA_API_KEY kerak"
  [ "$status" -eq 0 ]
}

@test "should_open_login_link: 🌐 brauzer login → 1 (link ochilmaydi)" {
  run should_open_login_link "🌐 brauzer login"
  [ "$status" -eq 1 ]
}

@test "should_open_login_link: 🆓 bepul → 1 (link ochilmaydi)" {
  run should_open_login_link "🆓 bepul — login shart emas"
  [ "$status" -eq 1 ]
}

@test "should_open_login_link: kalit muhitda mavjud bo'lsa → 1 (link ochilmaydi)" {
  export ALPHA_API_KEY="sk-test-123"
  run should_open_login_link "🔑 ALPHA_API_KEY kerak"
  [ "$status" -eq 1 ]
}

# --- resolve_config -------------------------------------------------------
@test "resolve_config: AI_PULT_CONFIG berilsa o'sha yo'lni qaytaradi" {
  export AI_PULT_CONFIG="$FIXTURE_CONFIG"
  run resolve_config
  [ "$status" -eq 0 ]
  [ "$output" = "$FIXTURE_CONFIG" ]
}
