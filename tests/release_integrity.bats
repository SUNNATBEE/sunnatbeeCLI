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

# --- CR (CRLF) himoyasi ------------------------------------------------------
# Windows'da `core.autocrlf=true` VERSION ni CRLF bilan checkout qiladi (bu
# faylga .gitattributes qoidasi YO'Q edi). CR versiyada qolsa `version_gt`
# oxirgi bo'lakni ("2\r") raqam emas deb 0 sanaydi → CLI o'zini ESKI deb
# biladi → yana cheksiz yangilash taklifi.
#
# DIQQAT — nima uchun bu yerda "CR taqqoslashni buzadi" degan test YO'Q:
# u PLATFORMAGA bog'liq bo'lib chiqdi. Git for Windows (MSYS) bash'i so'zlarga
# bo'lishda oxiridagi CR ni o'zi jimgina tashlab yuboradi (`igncr` o'chiq
# bo'lsa ham), MSYS `cat` ham CRLF ni LF ga aylantiradi — ya'ni Windows'da
# buzilish KO'RINMAYDI, Linux/macOS'da esa maydon "2\r" bo'lib qoladi va
# `version_gt` uni raqam emas deb 0 sanaydi. Shunday testni yozsak, u shu
# mashinada YIQILARDI (buzilishni ko'rsata olmagani uchun) — foydasi yo'q.
# Shuning uchun MEXANIZMni sinaymiz: tozalash ifodasi CR ni olib tashlaydimi,
# skriptda o'sha himoya bormi va .gitattributes qoidasi joyidami.
@test "version_gt: tozalangandan keyin to'g'ri taqqoslaydi" {
  load_selector
  local raw="1.9.2"$'\r' clean
  clean="${raw//[$'\r\n\t ']/}"          # ai-selector.sh dagi AYNAN shu ifoda
  [ "$clean" = "1.9.2" ]
  run version_gt "$clean" "1.9.1"
  [ "$status" -eq 0 ]
  # Teng versiyalar — yangilash TAKLIF QILINMAYDI (halqa yo'q).
  run version_gt "$clean" "1.9.2"
  [ "$status" -ne 0 ]
}

@test "AIDEVIX_VERSION: o'qilgandan keyin CR/bo'shliq tozalanadi" {
  # Himoya skriptdan olib tashlansa shu test yiqiladi.
  grep -qE 'AIDEVIX_VERSION="\$\{AIDEVIX_VERSION//\[\$.\\r\\n\\t .\]/\}"' "$SELECTOR"
}

@test ".gitattributes: VERSION har doim LF bilan checkout qilinadi" {
  grep -qE '^VERSION[[:space:]]+text[[:space:]]+eol=lf' "$PROJECT_ROOT/.gitattributes"
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

@test "npm_autoupdate_apply: exec'dan OLDIN markerni EXPORT qiladi" {
  # Marker exec orqali yangi jarayonga o'tishi shart — aks holda halqa
  # kafolati ishlamaydi (yangi jarayon markerni ko'rmaydi).
  local body markerline execline
  body="$(awk '/^npm_autoupdate_apply\(\) \{/{f=1} f{print} f&&/^\}$/{exit}' "$SELECTOR")"
  printf '%s\n' "$body" | grep -qE 'export AIDEVIX_UPDATE_ATTEMPTED='
  # `^[^#]*` — izohlarni chetlab o'tadi: `exec bash "$SELF"` funksiya ichidagi
  # IZOHDA ham uchraydi, uni haqiqiy chaqiruv deb olsak tartib xato hisoblanadi.
  markerline="$(printf '%s\n' "$body" | grep -nE '^[^#]*export AIDEVIX_UPDATE_ATTEMPTED=' | head -1 | cut -d: -f1)"
  execline="$(printf '%s\n' "$body" | grep -nE '^[^#]*exec bash "\$SELF"' | head -1 | cut -d: -f1)"
  [ -n "$markerline" ] && [ -n "$execline" ] && [ "$markerline" -lt "$execline" ]
}

# === 4. Menyu kadri BITTA yozuv bilan chiziladi ==============================
# Miltillashning sababi: kadr har qator uchun alohida `printf` bilan
# `/dev/tty` ga yozilardi (bitta kadr = 25-30 write). Endi bufer + DECSET 2026.
@test "menyu kadri: bitta printf, sinxron chiqish (DECSET 2026) ichida" {
  local body
  body="$(awk '/^select_with_arrows\(\) \{/{f=1} f{print} f&&/^\}$/{exit}' "$SELECTOR")"
  # Kadr buferga yig'iladi va bir marta yuboriladi.
  printf '%s\n' "$body" | grep -qE 'frame\+='
  printf '%s\n' "$body" | grep -qE "printf '%s' \"\\\$frame\" >/dev/tty"
  # Sinxron chiqish ochiladi VA yopiladi.
  printf '%s\n' "$body" | grep -q '2026h'
  printf '%s\n' "$body" | grep -q '2026l'
  # Ilgarigi qatorma-qator yozuv QAYTMASIN.
  ! printf '%s\n' "$body" | grep -qE "for L in .*do printf '\\\\r\\\\033\[K%s\\\\n' \"\\\$L\" >/dev/tty"
}

@test "terminalni tiklash: sinxron chiqish rejimi ham yopiladi" {
  # Kadr o'rtasida uzilish bo'lsa terminal 2026 rejimida qolib, EKRAN
  # MUZLAB qolardi. Har bir tiklash ketma-ketligi 2026l ni ham yuborishi kerak.
  # Faqat HAQIQIY chiqarish qatorlari (printf), izohlar emas.
  local n_restore n_2026
  n_restore="$(grep -cE '^[^#]*printf.*1049l' "$SELECTOR")"
  n_2026="$(grep -cE '^[^#]*printf.*2026l.*1049l' "$SELECTOR")"
  [ "$n_restore" -gt 0 ]
  [ "$n_restore" -eq "$n_2026" ]
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
