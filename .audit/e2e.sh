#!/usr/bin/env bash
# e2e.sh — tuzatilgan ichki menyuni haqiqiy konsolda sinash (SendKeys bilan).
# DOWN/UP/ENTER yuboriladi; muvaffaqiyat = "Alpha CLI" tanlanib ishga tushishi.
ROOT="F:/Desktop/Real Project/CLI"
export AI_PULT_CONFIG="$ROOT/tests/fixtures/agents.conf"
export XDG_STATE_HOME="$ROOT/.audit/e2e-state"
export AIDEVIX_NO_AUTOUPDATE=1 AI_NO_ANIM=1 NO_COLOR=1 AIDEVIX_LANG=uz
mkdir -p "$XDG_STATE_HOME/ai-cli"
: > "$XDG_STATE_HOME/ai-cli/seen_intro"
: > "$XDG_STATE_HOME/ai-cli/global_stats_hint"
bash "$ROOT/bin/ai-selector.sh" 2>"$ROOT/.audit/e2e.log"
echo "RC=$?" >>"$ROOT/.audit/e2e.log"
