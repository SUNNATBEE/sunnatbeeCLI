#!/usr/bin/env bash
# tests/test_helper.bash — barcha .bats fayllar uchun umumiy yordamchilar.
#
# Yuklash: har bir test faylida `load test_helper`.

# --- Yo'llar --------------------------------------------------------------
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_ROOT="$(cd "$TESTS_DIR/.." >/dev/null 2>&1 && pwd)"
export TESTS_DIR PROJECT_ROOT
export SELECTOR="$PROJECT_ROOT/bin/ai-selector.sh"
export COMMON="$PROJECT_ROOT/lib/common.sh"
export FIXTURE_CONFIG="$TESTS_DIR/fixtures/agents.conf"

# --- Deterministik muhit --------------------------------------------------
# Rang, animatsiya va avto-yangilanishni o'chiramiz; HOME/state'ni har bir test
# uchun alohida vaqtinchalik papkaga olamiz — real foydalanuvchi fayllariga tegmaymiz.
setup_env() {
  export NO_COLOR=1            # ranglarni o'chiradi → chiqish deterministik
  export CI=1                  # animatsiya + auto_update'ni o'chiradi
  export AI_NO_ANIM=1
  export AIDEVIX_NO_AUTOUPDATE=1
  export LC_ALL=C              # UTF-8 logikasini deterministik qiladi
  export HOME="${BATS_TEST_TMPDIR:-/tmp}/home"
  export XDG_STATE_HOME="${BATS_TEST_TMPDIR:-/tmp}/state"
  export XDG_CONFIG_HOME="${BATS_TEST_TMPDIR:-/tmp}/config"
  mkdir -p "$HOME" "$XDG_STATE_HOME" "$XDG_CONFIG_HOME"
  # Test agentlaridagi kalitlar muhitda BO'LMASLIGI kerak (should_open_login_link).
  unset ALPHA_API_KEY ANTHROPIC_API_KEY OPENAI_API_KEY GEMINI_API_KEY 2>/dev/null || true
}

# --- Bats tutqichlarini saqlash/tiklash -----------------------------------
# MUHIM: bats testning yiqilganini O'ZINING ERR/EXIT tutqichlari orqali
# aniqlaydi. Sinaladigan skriptlar esa `set -Eeuo pipefail` + o'z tutqichlarini
# (`crash`) o'rnatadi va ularni BOSIB KETADI. Ilgari bu yerda shunchaki
# `trap - ERR; trap - EXIT` qilinardi — natijada bats yiqilishni umuman
# ko'rmay qolardi va YIQILGAN test ham "ok" bo'lib chiqardi (butun to'plam
# soxta yashil edi). Shuning uchun endi tutqichlar source'dan OLDIN saqlanadi
# va keyin QAYTA tiklanadi.
_save_bats_traps() {
  __BATS_ERR_TRAP="$(trap -p ERR)"
  __BATS_EXIT_TRAP="$(trap -p EXIT)"
}
_restore_bats_traps() {
  trap - ERR
  trap - EXIT
  [[ -n "${__BATS_ERR_TRAP:-}"  ]] && eval "$__BATS_ERR_TRAP"
  [[ -n "${__BATS_EXIT_TRAP:-}" ]] && eval "$__BATS_EXIT_TRAP"
  # bats semantikasi: xato qaytargan buyruq testni yiqitadi (`run`/`!`/`||`
  # bilan o'ralganlar bundan mustasno). nounset va pipefail esa o'chiq —
  # ular skriptning ichki qoidasi, testga aloqasi yo'q.
  set -eE
  set +u
  set +o pipefail
  return 0
}

# load_selector — ai-selector.sh'ni source qiladi (funksiyalarni test qilish uchun).
load_selector() {
  _save_bats_traps
  # shellcheck disable=SC1090
  source "$SELECTOR"
  _restore_bats_traps
}

# load_common — faqat lib/common.sh'ni source qiladi.
load_common() {
  _save_bats_traps
  # shellcheck disable=SC1090
  source "$COMMON"
  _restore_bats_traps
}

# run_cli — ai-selector.sh'ni alohida jarayonda (qora-quti) ishga tushiradi.
run_cli() {
  run bash "$SELECTOR" "$@"
}
