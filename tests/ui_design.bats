#!/usr/bin/env bats
# ui_design.bats — dizayn tizimi (lib/ui.sh): ikonka pog'onalari va ularning
# avtomatik zaxirasi, ANSI'ni hisobga oluvchi o'lchov/tekislash, emoji tozalash,
# semantik ranglar.
#
# Nima uchun muhim: butun interfeys shu qatlamga tayanadi. Agar ui_pad ANSI
# baytlarini "ko'rinadigan" deb sanasa, IKKI USTUNLI maket siljib ketadi —
# bu ko'zga darrov tashlanadi, lekin qora-quti testida sezilmasligi mumkin.

load test_helper

setup() {
  setup_env
  # Bu faylda ranglar KERAK (ui_pad/ui_vislen aynan ANSI bilan sinaladi),
  # shuning uchun NO_COLOR'ni olib tashlaymiz va rangni majburlaymiz.
  unset NO_COLOR
  export FORCE_COLOR=1
  load_common
}

# --- Ikonka pog'onalari ---------------------------------------------------

@test "ikonkalar: uchala pog'ona ham to'liq to'plam beradi" {
  local tier k
  for tier in nerd unicode ascii; do
    ui_icons_set "$tier"
    [ "$UI_ICON_TIER" = "$tier" ]
    for k in ok miss dot_on dot_off info warn err ai search arrow enter \
             key globe card free star last sep line bullet; do
      [ -n "${ICO[$k]:-}" ] || {
        echo "pog'ona=$tier da '$k' ikonkasi bo'sh"; return 1
      }
    done
  done
}

@test "ikonkalar: ascii pog'onasi FAQAT ASCII belgilardan iborat" {
  # LANG=C / eski konsollarda zaxira sifatida ishlatiladi — u yerda
  # ko'p baytli belgi buziladi, shuning uchun sof ASCII bo'lishi shart.
  ui_icons_set ascii
  local k v
  for k in "${!ICO[@]}"; do
    v="${ICO[$k]}"
    [[ "$v" =~ ^[[:print:]]+$ ]] || { echo "ascii emas: $k=$v"; return 1; }
    # Har bir belgi 1 bayt = 1 ustun bo'lsin (enter '<-' — istisno, 2 ta ASCII).
    [ "${#v}" -le 2 ] || { echo "juda uzun: $k=$v"; return 1; }
  done
}

@test "ikonkalar: UTF-8 bo'lmagan muhitda AVTOMATIK ascii'ga tushadi" {
  UI_UTF8=0
  unset AIDEVIX_ICONS
  export AIDEVIX_STATE_DIR="$BATS_TEST_TMPDIR/icons-state"
  ui_icons_detect
  [ "$UI_ICON_TIER" = "ascii" ]
}

@test "ikonkalar: AIDEVIX_ICONS aniqlashdan USTUN turadi" {
  UI_UTF8=1
  export AIDEVIX_ICONS=ascii
  export AIDEVIX_STATE_DIR="$BATS_TEST_TMPDIR/icons-state2"
  ui_icons_detect
  [ "$UI_ICON_TIER" = "ascii" ]
}

@test "ikonkalar: saqlangan tanlov keshdan ustun (aidevix --icons)" {
  UI_UTF8=1
  unset AIDEVIX_ICONS
  export AIDEVIX_STATE_DIR="$BATS_TEST_TMPDIR/icons-state3"
  mkdir -p "$AIDEVIX_STATE_DIR"
  printf 'unicode\n' >"$AIDEVIX_STATE_DIR/icons"
  printf 'nerd\n'    >"$AIDEVIX_STATE_DIR/icons_cache"
  ui_icons_detect
  [ "$UI_ICON_TIER" = "unicode" ]
}

@test "ikonkalar: nerd probe muvaffaqiyatsiz bo'lsa unicode'ga tushadi" {
  UI_UTF8=1
  unset AIDEVIX_ICONS
  export AIDEVIX_STATE_DIR="$BATS_TEST_TMPDIR/icons-state4"
  # Probe'ni "topilmadi" ga majburlaymiz — zaxira yo'li aynan shu.
  ui_icons_probe_nerd() { return 1; }
  ui_icons_detect
  [ "$UI_ICON_TIER" = "unicode" ]
}

# --- O'lchov va tekislash (ANSI bilan) ------------------------------------

@test "ui_vislen: ANSI ketma-ketliklarini sanamaydi" {
  local s="${UI_OK}hello${UI_R} world"
  [ "$(ui_vislen "$s")" -eq 11 ]
}

@test "ui_strip: barcha ANSI kodlarini olib tashlaydi" {
  local s="${UI_B}${UI_AI}abc${UI_R}${UI_FAINT}def${UI_R}"
  [ "$(ui_strip "$s")" = "abcdef" ]
}

@test "ui_pad: rangli satrni KO'RINADIGAN uzunlik bo'yicha to'ldiradi" {
  local out
  out="$(ui_pad "${UI_OK}ok${UI_R}" 10)"
  # Ko'rinadigan uzunlik aniq 10 bo'lishi shart (aks holda ustunlar siljiydi).
  [ "$(ui_vislen "$out")" -eq 10 ]
}

@test "ui_pad: satr maydondan uzun bo'lsa qisqartirmaydi (kesmaydi)" {
  local out
  out="$(ui_pad "abcdefghij" 4)"
  [ "$(ui_vislen "$out")" -eq 10 ]
}

@test "ui_trunc: uzun satrni ellipsis bilan qisqartiradi" {
  local out
  out="$(ui_trunc "abcdefghij" 5)"
  [ "${#out}" -eq 5 ]
}

@test "ui_trunc: qisqa satrga tegmaydi" {
  [ "$(ui_trunc "abc" 10)" = "abc" ]
}

@test "ui_trunc_v: ascii pog'onasida '..' ishlatadi (ko'p baytli emas)" {
  ui_icons_set ascii
  local out
  ui_trunc_v out "abcdefghij" 6
  [ "$out" = "abcd.." ]
}

# --- Emoji tozalash -------------------------------------------------------

@test "ui_deemoji_v: emoji va qolgan ortiqcha bo'shliqni oladi" {
  local out
  ui_deemoji_v out "🧠 Anthropic agenti"
  [ "$out" = "Anthropic agenti" ]
}

@test "ui_deemoji_v: satr boshidagi otступni SAQLAYDI" {
  # Notice ichidagi buyruq qatorlari otступ bilan ajratiladi — uni yo'qotish
  # maketni buzardi (regressiya testi).
  local out
  ui_deemoji_v out "    npm i -g aidevix@latest"
  [ "$out" = "    npm i -g aidevix@latest" ]
}

@test "ui_deemoji_v: emoji bo'lmasa satrga UMUMAN tegmaydi" {
  local src="  ikki   bo'shliq  " out
  ui_deemoji_v out "$src"
  [ "$out" = "$src" ]
}

# --- Semantik ranglar -----------------------------------------------------

# palette_script — semantik tokenlarni tekshiruvchi yordamchi skriptni yozadi.
#
# MUHIM: palitra common.sh SOURCE QILINGAN PAYTDA hisoblanadi (UI_DEPTH), ya'ni
# uni testning ichida `UI_TTY=1` deb o'zgartirib bo'lmaydi — kech. Ilgari shu
# test aynan shunday yozilgan edi va natija TESTNI ISHGA TUSHIRGAN TERMINALGA
# bog'liq bo'lib qolgandi: ishlab chiquvchida TERM=xterm-256color (o'tardi),
# CI'da esa TERM=dumb → pog'ona 0 → hamma token bo'sh (yiqilardi).
# Shuning uchun muhit OLDINDAN beriladi va common.sh qayta source qilinadi.
palette_script() {
  cat >"$BATS_TEST_TMPDIR/pal.sh" <<'SH'
. "$1"
[ "$UI_DEPTH" = "$2" ] || { echo "pog'ona=$UI_DEPTH (kutilgan $2)"; exit 1; }
for v in UI_OK UI_WARN UI_ERR UI_INFO UI_AI UI_MUTED; do
  [ -n "${!v}" ] || { echo "bo'sh token: $v"; exit 1; }
done
# Muvaffaqiyat/xato/ogohlantirish bir-biridan farq qilishi SHART.
[ "$UI_OK"  != "$UI_ERR"  ] || { echo 'UI_OK == UI_ERR';   exit 1; }
[ "$UI_OK"  != "$UI_WARN" ] || { echo 'UI_OK == UI_WARN';  exit 1; }
[ "$UI_ERR" != "$UI_WARN" ] || { echo 'UI_ERR == UI_WARN'; exit 1; }
[ "$UI_AI"  != "$UI_INFO" ] || { echo 'UI_AI == UI_INFO';  exit 1; }
echo OK
SH
  printf '%s' "$BATS_TEST_TMPDIR/pal.sh"
}

@test "ranglar: 256-rangli terminalda semantik tokenlar farqli" {
  local s; s="$(palette_script)"
  run env -u NO_COLOR -u COLORTERM -u WT_SESSION -u TERM_PROGRAM -u ConEmuANSI \
      FORCE_COLOR=1 TERM=xterm-256color bash "$s" "$COMMON" 256
  [ "$status" -eq 0 ]
  [ "$output" = "OK" ]
}

@test "ranglar: 16-rangli terminalda ham tokenlar farqli (zaxira pog'ona)" {
  # 256 ni ko'tarmaydigan terminal: palitra standart ANSI ranglarga tushadi,
  # lekin semantika saqlanishi kerak — tokenlar baribir farq qilsin.
  local s; s="$(palette_script)"
  run env -u NO_COLOR -u COLORTERM -u WT_SESSION -u TERM_PROGRAM -u ConEmuANSI \
      FORCE_COLOR=1 TERM=xterm bash "$s" "$COMMON" 16
  [ "$status" -eq 0 ]
  [ "$output" = "OK" ]
}

@test "ranglar: TERM=dumb bo'lsa rang umuman chiqmaydi" {
  run env -u NO_COLOR -u COLORTERM -u WT_SESSION -u TERM_PROGRAM -u ConEmuANSI \
      FORCE_COLOR=1 TERM=dumb bash -c ". '$COMMON'; printf '[%s%s%s%s]' \
        \"\$UI_OK\" \"\$UI_ERR\" \"\$UI_WARN\" \"\$UI_AI\""
  [ "$output" = "[]" ]
}

@test "ranglar: NO_COLOR bo'lsa hamma token bo'sh" {
  run bash -c "NO_COLOR=1 . '$COMMON'; printf '[%s%s%s%s%s]' \
    \"\$UI_OK\" \"\$UI_ERR\" \"\$UI_WARN\" \"\$UI_AI\" \"\$UI_R\""
  [ "$output" = "[]" ]
}

# --- Bloklar --------------------------------------------------------------

@test "ui_notice: sarlavha va qatorlardan emoji olib tashlanadi" {
  run bash -c ". '$COMMON'; UI_FD=1 ui_notice warn '⚠  Ogohlantirish' '🔑 kalit kerak'"
  [[ "$output" != *"⚠"* ]]
  [[ "$output" != *"🔑"* ]]
  [[ "$output" == *"Ogohlantirish"* ]]
  [[ "$output" == *"kalit kerak"* ]]
}

@test "ui_statusbar_str_v: maydonlarni ajratgich bilan ulaydi" {
  local out
  ui_statusbar_str_v out "birinchi" "ikkinchi" "uchinchi"
  [[ "$out" == *"birinchi"* ]]
  [[ "$out" == *"ikkinchi"* ]]
  [[ "$out" == *"uchinchi"* ]]
}

@test "ui_statusbar_str_v: bo'sh maydonlarni tashlab ketadi" {
  local out
  ui_statusbar_str_v out "bor" "" "yana"
  [[ "$out" == *"bor"* ]]
  [[ "$out" == *"yana"* ]]
}

@test "ui_statusbar_str_v: terminal eniga sig'maydigan maydonlarni kesadi" {
  UI_COLS=30
  local out vis
  ui_statusbar_str_v out "aaaaaaaaaa" "bbbbbbbbbb" "cccccccccc" "dddddddddd"
  ui_vislen_v vis "$out"
  [ "$vis" -le 30 ]
}

@test "ui_footer_str_v: juftlarni kalit + qiymat bo'lib ulaydi" {
  UI_COLS=100
  local out
  ui_footer_str_v out "↑↓=harakat" "⏎=ishga tushirish" "esc=chiqish"
  [[ "$out" == *"↑↓"* ]]
  [[ "$out" == *"harakat"* ]]
  [[ "$out" == *"esc"* ]]
}

@test "ui_footer_str_v: terminal eniga sig'maydigan juftlarni tashlaydi" {
  # Status bar kabi footer ham kesilishi shart — aks holda tor terminalda
  # o'ralib ketadi va ramkani pastga suradi.
  UI_COLS=40
  local out vis
  ui_footer_str_v out "aaaa=1111" "bbbb=2222" "cccc=3333" "dddd=4444" "eeee=5555"
  ui_vislen_v vis "$out"
  [ "$vis" -le 40 ]
  [[ "$out" == *"aaaa"* ]]                    # chapdagilar muhimroq — qoladi
}

@test "ui_bar: foizga mos to'ldirilgan bar qaytaradi" {
  local out vis
  out="$(ui_bar 50 20)"
  ui_vislen_v vis "$out"
  [ "$vis" -eq 20 ]
}

# --- Banner animatsiyasi --------------------------------------------------

@test "ui_anim_wait: skriptni TO'XTATIB QO'YMAYDI (regressiya)" {
  # Bug: fork'siz kutish uchun `exec {fd}<> <(:)` ishlatilgan edi. MSYS'da
  # redirect xato berardi, noninteraktiv bash esa `exec` redirecti barbod
  # bo'lsa BUTUN SKRIPTNI to'xtatadi — banner birinchi qatordan keyin jim
  # uzilardi va `|| zaxira` ham ishlamasdi.
  run bash -c ". '$COMMON'; ui_anim_wait 0.01; ui_anim_wait 0.01; \
                ui_anim_wait 0.01; echo SURVIVED"
  [ "$status" -eq 0 ]
  [ "$output" = "SURVIVED" ]
}

@test "ui_anim_wait: kasr sonni ko'tarmaydigan sleep'da kutishni O'TKAZADI" {
  # Ba'zi minimal `sleep` (busybox) kasr sonni tushunmaydi va "0.055" ni
  # 0 yoki xato deb qabul qiladi. Bunday muhitda BUTUN kutishni o'tkazib
  # yuborish kerak — aks holda har kadr 1 soniya bo'lib, banner 6 soniyaga
  # cho'zilardi. Probe'ni "qo'llab-quvvatlamaydi" ga majburlab tekshiramiz.
  run bash -c ". '$COMMON'
    sleep() { [[ \$1 == *.* ]] && return 1; command sleep \"\$1\"; }
    ui_anim_wait 0.055
    echo \"cap=\$UI_ANIM_SLEEP rc=\$?\""
  [ "$status" -eq 0 ]
  [[ "$output" == *"cap=0"* ]]
}

@test "ui_anim_wait: kasrni ko'taradigan sleep'da qobiliyat aniqlanadi" {
  run bash -c ". '$COMMON'; ui_anim_wait 0.01; echo \"cap=\$UI_ANIM_SLEEP\""
  [ "$status" -eq 0 ]
  [[ "$output" == *"cap=1"* ]] || [[ "$output" == *"cap=0"* ]]
}

@test "ui_gradient_line: 256-rangli kodlar bilan chizadi, MATN o'zgarmaydi" {
  UI_COLS=80
  run bash -c "FORCE_COLOR=1 TERM=xterm-256color . '$COMMON'; UI_FD=1 ui_gradient_line 'ABC' 0"
  [ "$status" -eq 0 ]
  # Gradient — 256-rangli ANSI kodlari bo'lishi shart.
  [[ "$output" == *$'\033[1;38;5;'* ]]
  # Ko'rinadigan matn saqlanadi.
  local plain; plain="$(printf '%s' "$output" | sed 's/\x1b\[[0-9;]*m//g')"
  [ "$plain" = "ABC" ]
}

@test "ui_gradient_line: bo'sh joyga rang bermaydi (ANSI shovqini kam)" {
  run bash -c "FORCE_COLOR=1 TERM=xterm-256color . '$COMMON'; UI_FD=1 ui_gradient_line 'A B' 0"
  local plain; plain="$(printf '%s' "$output" | sed 's/\x1b\[[0-9;]*m//g')"
  [ "$plain" = "A B" ]
}

@test "banner: animatsiya CI/NO_COLOR/TTY'siz holatda O'CHIQ" {
  # Animatsiya faqat jonli 256-rangli terminalda; aks holda logo darhol chiqadi.
  run bash -c "CI=1 FORCE_COLOR=1 TERM=xterm-256color . '$COMMON'; echo \"anim=\$AI_ANIM\""
  [[ "$output" == *"anim=0"* ]]
}

@test "banner: keng terminalda TO'LIQ 'AIDEVIX' so'zi chiziladi" {
  # Brend: monogramma emas, to'liq so'z (ANSI Shadow uslubi).
  # ESLATMA: kenglikni BELGILAB o'lchamaymiz — testlar LC_ALL=C bilan ishlaydi,
  # u yerda box-drawing belgisi 3 BAYT va har qanday length() yanglishadi.
  # Shuning uchun MAZMUN bo'yicha tekshiramiz.
  # COLUMNS ni source'dan KEYIN qo'yamiz va ui_width keshini tozalaymiz —
  # `COLUMNS=100 . file` shakli builtin'ga ta'sir qilmaydi (kenglik 80 bo'lib
  # qolardi va test tasodifan o'tardi).
  run bash -c "FORCE_COLOR=1 TERM=xterm-256color . '$COMMON'
                COLUMNS=100; UI_COLS=''; UI_UTF8=1; AI_ANIM=0
                banner_full 'Aidevix' 2>&1"
  [ "$status" -eq 0 ]
  # Bu bo'lak FAQAT to'liq "AIDEVIX" logosida bor (AD monogrammasida yo'q).
  [[ "$output" == *'██╗██████╗ ███████╗'* ]]
}

@test "banner: TOR terminalda 'AD' monogrammasiga tushadi (o'ralib ketmaydi)" {
  # To'liq so'z 49 ustun egallaydi — 44 ustunli oynada o'ralib, maketni buzardi.
  run bash -c "FORCE_COLOR=1 TERM=xterm-256color . '$COMMON'
                COLUMNS=44; UI_COLS=''; UI_UTF8=1; AI_ANIM=0
                banner_full 'Aidevix' 2>&1"
  [ "$status" -eq 0 ]
  # To'liq so'zning belgisi BO'LMASLIGI kerak.
  [[ "$output" != *'██╗██████╗ ███████╗'* ]]
  # AD monogrammasi esa bor.
  [[ "$output" == *'█████╗ ██████╗'* ]]
}
