#!/usr/bin/env bats
# global_stats.bats — global statistika (OPT-IN) klyent mantig'i uchun testlar.
#
# Tarmoq chaqiruvlari (report/fetch) test muhitida CI=1 tufayli o'chiq —
# shuning uchun testlar tarmoqqa chiqmaydi. Faqat opt-in mantig'i, JSON parsing
# va menyu belgisi tekshiriladi.

load test_helper

setup() {
  setup_env
  unset AIDEVIX_GLOBAL_STATS 2>/dev/null || true
  load_selector
}

NS_JSON='{"updated_at":"x","totals":{"install":4,"launch":1},"install":[{"agent":"Claude Code","count":2},{"agent":"Gemini CLI","count":1},{"agent":"Codebuff","count":1}],"launch":[{"agent":"Claude Code","count":1}]}'

# --- opt-in holati --------------------------------------------------------
@test "global_stats_enabled: standart holatda o'chiq" {
  run global_stats_enabled
  [ "$status" -ne 0 ]
}

@test "set_global_stats on → yoqiladi; off → o'chiriladi" {
  set_global_stats on
  run global_stats_enabled
  [ "$status" -eq 0 ]
  set_global_stats off
  run global_stats_enabled
  [ "$status" -ne 0 ]
}

@test "AIDEVIX_GLOBAL_STATS env opt-in faylidan ustun (1 → yoqilgan)" {
  set_global_stats off
  AIDEVIX_GLOBAL_STATS=1 run global_stats_enabled
  [ "$status" -eq 0 ]
}

@test "AIDEVIX_GLOBAL_STATS=0 env majburan o'chiradi" {
  set_global_stats on
  AIDEVIX_GLOBAL_STATS=0 run global_stats_enabled
  [ "$status" -ne 0 ]
}

# --- JSON reytingni parsing -----------------------------------------------
@test "global_install_tsv: install reytingini nom/rank/son ga aylantiradi" {
  mkdir -p "$STATE_DIR"
  printf '%s' "$NS_JSON" > "$GLOBAL_CACHE"
  run global_install_tsv
  [ "$status" -eq 0 ]
  # Birinchi qator: Claude Code, rank 1, son 2
  [ "$(printf '%s\n' "$output" | sed -n '1p')" = "$(printf 'Claude Code\t1\t2')" ]
  [ "$(printf '%s\n' "$output" | sed -n '2p')" = "$(printf 'Gemini CLI\t2\t1')" ]
  [ "$(printf '%s\n' "$output" | sed -n '3p')" = "$(printf 'Codebuff\t3\t1')" ]
}

@test "global_install_tsv: kesh yo'q bo'lsa bo'sh chiqaradi" {
  run global_install_tsv
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- menyu belgisi --------------------------------------------------------
@test "build_menu: global yoqilganda reyting raqamini ko'rsatadi (emoji'siz)" {
  export AI_PULT_CONFIG="$FIXTURE_CONFIG"
  mkdir -p "$STATE_DIR"
  # Fixture agentlaridan biri uchun global reyting beramiz.
  printf '%s' '{"install":[{"agent":"Alpha CLI","count":42}],"launch":[]}' > "$GLOBAL_CACHE"
  local gtsv; gtsv="$(mktemp)"
  global_install_tsv > "$gtsv"
  local rows; rows="$(build_rows "$FIXTURE_CONFIG")"
  run build_menu "$rows" "$STATS_FILE" "$gtsv"
  [ "$status" -eq 0 ]
  # Reyting KO'RINADI, lekin faqat raqam bilan: dizayn qayta ishlangandan keyin
  # meta zonasi emoji'siz (ma'no ikonka pog'onasi va so'nik rang orqali beriladi).
  [[ "$output" == *"#1"* ]]
  [[ "$output" != *"🔥"* ]]
}

# --- xavfsiz no-op (tarmoqsiz) --------------------------------------------
@test "report_usage_global: o'chiq bo'lsa darrov 0 qaytaradi (tarmoqqa chiqmaydi)" {
  run report_usage_global "Claude Code" "launch"
  [ "$status" -eq 0 ]
}

@test "fetch_global_stats: o'chiq bo'lsa darrov 0 qaytaradi" {
  run fetch_global_stats
  [ "$status" -eq 0 ]
}
