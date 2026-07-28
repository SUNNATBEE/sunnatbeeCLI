#!/usr/bin/env bats
# top_rank.bats — build_menu'dagi "top/mashhur" agentlar saralashi va ⭐ belgisi.
#
# TOP_AGENTS — curated mashhur agentlar ro'yxati (binary nomi bo'yicha). Menyu
# lokal sanoq teng (yoki nol) bo'lganda ham top agentlarni tepaga ko'taradi va
# yonida ⭐ ko'rsatadi. Bu yangi foydalanuvchida ham "eng mashhurlar"ni ajratadi.

load test_helper

setup() {
  setup_env
  load_selector
}

# --- Top belgisi ATAYLAB yo'q --------------------------------------------
@test "build_menu: top agent yonida ⭐ belgisi CHIQMAYDI (tartibning o'zi yetarli)" {
  # Dizayn qarori: qatorlar allaqachon mashhurlik bo'yicha saralangan (istop
  # saralash kalitida qatnashadi), ya'ni yulduzcha o'sha ma'noni TAKRORLAB,
  # ro'yxatning yarmida shovqin hosil qilardi. Regressiya testi: belgi
  # qaytib kelmasin.
  export AI_PULT_CONFIG="$FIXTURE_CONFIG"
  TOP_AGENTS="charliebin"            # Charlie binari = top deb belgilaymiz
  local rows; rows="$(build_rows "$FIXTURE_CONFIG")"
  run build_menu "$rows" "$STATS_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" != *"⭐"* ]]
  # Top agent baribir tepada turishi kerak — ma'no yo'qolmagan.
  local first; first="$(printf '%s\n' "$output" | head -1)"
  [[ "$first" == *"Charlie"* ]]
}

# --- Saralash: top agent statistikasiz ham tepaga chiqadi ------------------
@test "build_menu: statistikasiz top agent config'da pastda bo'lsa ham tepaga chiqadi" {
  export AI_PULT_CONFIG="$FIXTURE_CONFIG"
  # NoInstall (nibin) config'da OXIRGI qator — uni top deb belgilaymiz.
  TOP_AGENTS="nibin"
  local rows; rows="$(build_rows "$FIXTURE_CONFIG")"
  run build_menu "$rows" "$STATS_FILE"
  [ "$status" -eq 0 ]
  local first; first="$(printf '%s\n' "$output" | head -1)"
  [[ "$first" == *"NoInstall"* ]]
}

# --- Lokal sanoq top'dan ustun (foydalanuvchi haqiqiy ishlatishi muhimroq) -
@test "build_menu: lokal sanoq top belgisidan ustun turadi" {
  export AI_PULT_CONFIG="$FIXTURE_CONFIG"
  TOP_AGENTS="nibin"                 # NoInstall = top
  record_usage "Alpha CLI"           # lekin Alpha CLI 1 marta ishlatilgan
  local rows; rows="$(build_rows "$FIXTURE_CONFIG")"
  run build_menu "$rows" "$STATS_FILE"
  [ "$status" -eq 0 ]
  # Ishlatilgan Alpha CLI top NoInstall'dan tepada bo'lishi kerak.
  local first; first="$(printf '%s\n' "$output" | head -1)"
  [[ "$first" == *"Alpha CLI"* ]]
}
