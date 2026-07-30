#!/usr/bin/env bats
# release_integrity.bats — RELIZ butunligi: aynan v1.9.1 da foydalanuvchini
# cheksiz halqaga tushirgan ikki nuqson uchun regressiya to'siqlari.
#
# NIMA BO'LGANDI (v1.9.1, npm):
#   1) `npm_autoupdate_apply` ichida MAVJUD BO'LMAGAN funksiya chaqirilgan edi
#      (`log_ok` — haqiqiy nomi `log_success`). Har yangilashdan keyin
#      "log_ok: command not found" chiqardi.
#   2) Paketda `package.json` = 1.9.1, lekin `VERSION` fayli 1.7.4 bo'lib
#      qolgan edi. Skript versiyani VERSION faylidan o'qiganligi uchun
#      yangilangandan keyin ham o'zini eski deb bilib, YANA yangilashni
#      taklif qilardi → cheksiz "[Y/n]" halqasi.
#
# Bu fayl ikkalasini ham QAYTA sodir bo'lishidan to'sadi.

load test_helper

setup() {
  setup_env
}

# === 1. Aniqlanmagan log_* funksiyasi chaqirilmasin =========================
# `log_ok` shu tekshiruv bo'lmagani uchun relizga chiqib ketdi. Endi yetkazib
# beriladigan barcha skriptlardagi HAR BIR `log_*` nomi lib/common.sh da
# aniqlangan bo'lishi shart.
@test "log_* chaqiruvlari: hammasi lib/common.sh da aniqlangan" {
  local defined used name bad=""
  # lib/common.sh dagi aniqlanishlar: `log_xxx() { … }`.
  defined="$(grep -oE '^log_[a-z_]+\(\)' "$PROJECT_ROOT/lib/common.sh" \
             | sed 's/()$//' | sort -u)"
  [ -n "$defined" ]

  # Yetkazib beriladigan skriptlarda CHAQIRILGAN nomlar. Faqat BUYRUQ o'rnidagi
  # nomlarni olamiz: token oldida qator boshi / bo'shliq / `;&|(` bo'lishi va
  # ORTIDAN bo'shliq kelishi shart. Shu tufayli o'zgaruvchilar (`log_text=…`,
  # `"$log_text"`) tashqarida qoladi — ular funksiya emas.
  used="$(grep -ohE '(^|[[:space:]]|[;&|(])log_[a-z_]+[[:space:]]' \
            "$PROJECT_ROOT/bin/ai-selector.sh" \
            "$PROJECT_ROOT/lib/common.sh" \
            "$PROJECT_ROOT/lib/ui.sh" \
            "$PROJECT_ROOT/lib/i18n.sh" \
          | grep -oE 'log_[a-z_]+' | sort -u)"
  [ -n "$used" ]

  for name in $used; do
    grep -qx "$name" <<<"$defined" || bad+=" $name"
  done
  [ -z "$bad" ] || {
    echo "Aniqlanmagan log funksiyalari:$bad"
    echo "Aniqlanganlar: $defined"
    false
  }
}

# === 2. VERSION va package.json BIR XIL bo'lsin =============================
@test "versiya sinxron: VERSION == package.json" {
  local vfile pjson
  vfile="$(tr -d ' \t\r\n' < "$PROJECT_ROOT/VERSION")"
  pjson="$(node -e 'console.log(require(process.argv[1]).version)' \
             "$PROJECT_ROOT/package.json")"
  [ "$vfile" = "$pjson" ]
}

@test "check-version-sync.js: nomuvofiqlikda publish'ni to'xtatadi (exit 1)" {
  # Reponing nusxasi: package.json'ni buzamiz va skript YIQITISHI kerak.
  local sandbox="$BATS_TEST_TMPDIR/relcheck"
  mkdir -p "$sandbox/scripts"
  cp "$PROJECT_ROOT/scripts/check-version-sync.js" "$sandbox/scripts/"
  printf '1.0.0\n' > "$sandbox/VERSION"
  printf '{"name":"aidevix","version":"9.9.9"}\n' > "$sandbox/package.json"

  run node "$sandbox/scripts/check-version-sync.js"
  [ "$status" -eq 1 ]
  [[ "$output" == *"1.0.0"* ]]
  [[ "$output" == *"9.9.9"* ]]
}

@test "check-version-sync.js: mos kelganda o'tadi (exit 0)" {
  local sandbox="$BATS_TEST_TMPDIR/relok"
  mkdir -p "$sandbox/scripts"
  cp "$PROJECT_ROOT/scripts/check-version-sync.js" "$sandbox/scripts/"
  # CRLF bilan yozamiz — Windows'da tahrirlangan VERSION ham o'tishi kerak.
  printf '2.3.4\r\n' > "$sandbox/VERSION"
  printf '{"name":"aidevix","version":"2.3.4"}\n' > "$sandbox/package.json"

  run node "$sandbox/scripts/check-version-sync.js"
  [ "$status" -eq 0 ]
}

# === 3. Yangilash HALQASI qaytmasin =========================================
@test "npm_autoupdate_apply: marker bo'lsa qayta SO'RAMAYDI (npm chaqirilmaydi)" {
  load_selector
  local stub="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$stub"
  cat > "$stub/npm" <<EOF
#!/usr/bin/env bash
echo called > "$BATS_TEST_TMPDIR/npm_called"
exit 0
EOF
  chmod +x "$stub/npm"

  # Marker o'rnatilgan = bu exec-zanjirida allaqachon yangilanib bo'lingan.
  AIDEVIX_UPDATE_ATTEMPTED="1.7.4" PATH="$stub:$PATH" \
    run npm_autoupdate_apply 999.0.0
  [ "$status" -eq 1 ]                    # passiv eslatmaga qaytaradi
  [ ! -f "$BATS_TEST_TMPDIR/npm_called" ]  # npm umuman chaqirilmaydi
  [ -z "$output" ]                       # prompt ham chiqmaydi
}

@test "maybe_npm_update_hint: yangilanib versiya o'zgarmasa TASHXIS beradi" {
  load_selector
  unset AIDEVIX_NO_AUTOUPDATE CI
  PROJECT_ROOT="/usr/lib/node_modules/aidevix"   # npm o'rnatishga taqlid
  mkdir -p "$STATE_DIR"
  printf '%s\n' "999.0.0" > "$NPM_LATEST_CACHE"
  printf '%s\n' "$(date +%s)" > "$NPM_CHECK_STAMP"

  # Marker joriy versiyaga TENG = yangilandik, lekin versiya o'zgarmadi.
  AIDEVIX_UPDATE_ATTEMPTED="$AIDEVIX_VERSION" run maybe_npm_update_hint </dev/null
  [ "$status" -eq 0 ]
  # Tashxis: nima bo'lgani va qanday tekshirish aytiladi.
  [[ "$output" == *"npm ls -g"* ]]
  [[ "$output" == *"999.0.0"* ]]
  # "Yangilaymizmi?" degan taklif QAYTA chiqmaydi — halqa yo'q.
  [[ "$output" != *"[Y/n]"* ]]
}
