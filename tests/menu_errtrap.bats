#!/usr/bin/env bats
# menu_errtrap.bats — fzf'siz ↑/↓ menyudagi ERR-trap crash'i (v1.5.0 bug'i)
# QAYTIB KELMASLIGI uchun regressiya testlari.
#
# Bug: skript `set -Eeuo pipefail` + ERR-tutqich bilan ishlaydi. `select_with_arrows`
# ichidagi standalone `(( cur < 0 ))` kabi arifmetik ifoda FALSE bo'lsa exit code 1
# qaytaradi; ERR-tutqich uni "Kutilmagan xato" deb `die` qiladi → menyu qulaydi
# (Windows Git Bash userlarida ommaviy crash). Fix (eb56c6b, v1.5.1):
# `select_with_arrows` boshida `set +e; trap - ERR` — subshell ichida tutqichni
# o'chiradi, chegaralarni funksiya o'zi boshqaradi.
#
# Bu yerda tarmoq/TTY shart emas: STRUKTURAVIY tekshiruv — fix joyida ekanini va
# o'sha sinf bug (himoyalanmagan standalone `(( ))`) qaytib kelmaganini kafolatlaydi.

load test_helper

setup() {
  setup_env
}

# select_with_arrows tanasini ajratib oladi (funksiya boshidan birinchi ustun-0 `}` gacha).
_arrows_body() {
  awk '/^select_with_arrows\(\) \{/{f=1} f{print} f&&/^\}$/{exit}' "$SELECTOR"
}

# --- Fix joyidaligi: ERR-tutqich va errexit o'chirilgan -------------------
@test "select_with_arrows: ERR-tutqichni o'chiradi (trap - ERR)" {
  _arrows_body | grep -qE '^\s*trap - ERR\s*$'
}

@test "select_with_arrows: errexit'ni o'chiradi (set +e)" {
  _arrows_body | grep -qE '^\s*set \+e\s*$'
}

@test "select_with_arrows: read-tsikldan OLDIN himoya o'rnatiladi" {
  # `set +e` qatori interaktiv `while :` tsiklidan oldin kelishi shart, aks holda
  # tsikl ichidagi `(( cur ... ))` lar himoyasiz qoladi.
  local body se wl
  body="$(_arrows_body)"
  se="$(printf '%s\n' "$body" | grep -nE '^\s*set \+e\s*$' | head -1 | cut -d: -f1)"
  wl="$(printf '%s\n' "$body" | grep -nE '^\s*while :;\s*do' | head -1 | cut -d: -f1)"
  [ -n "$se" ] && [ -n "$wl" ]
  [ "$se" -lt "$wl" ]
}

# --- Sinf-bug: himoyalanmagan standalone `(( ))` qolmaganligi --------------
# --- crash(): kutilmagan xatoda KATTA yangilash eslatmasi -----------------
@test "barcha ERR-tutqichlar crash() ni chaqiradi (die-Kutilmagan emas)" {
  # ERR-tutqichlar endi crash() ga o'tgan; eski 'die 1 ... Kutilmagan' qolmagan.
  run grep -c "trap 'crash \"\$BASH_COMMAND\"" "$SELECTOR"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
  run grep -n "die 1.*Kutilmagan xato" "$SELECTOR"
  [ "$status" -ne 0 ]    # topilmasligi kerak
}

@test "crash: npm o'rnatishda 'npm i -g aidevix@latest' ni KATTA ko'rsatadi" {
  load_selector
  PROJECT_ROOT="/usr/lib/node_modules/aidevix"    # is_npm_install → ha
  run crash "false" "42"
  [ "$status" -eq 1 ]
  [[ "$output" == *"npm i -g aidevix@latest"* ]]
  [[ "$output" == *"YANGILANG"* || "$output" == *"UPDATE"* ]]
  [[ "$output" == *"42"* ]]    # xato qatori ham ko'rinadi
}

@test "crash: git checkout'da 'aidevix --update' ko'rsatadi" {
  load_selector
  # PROJECT_ROOT — repo (test PROJECT_ROOT'da .git bor).
  [ -d "$PROJECT_ROOT/.git" ] || skip "test PROJECT_ROOT git emas"
  run crash "false" "7"
  [ "$status" -eq 1 ]
  [[ "$output" == *"aidevix --update"* ]]
}

# --- Strelka navigatsiyasi: baytlar FAQAT bloklovchi dd bilan o'qiladi ------
# Ildiz sabab (haqiqiy conhost'da probe bilan isbotlangan): MSYS konsol
# tty'sida HAR QANDAY tcsetattr — `stty min/time` ham, bash `read -t/-n`ning
# ichki setattr'i ham — kutayotgan kiritish baytlarini O'CHIRIB yuboradi.
# Strelkaning `[A` dumi ESC o'qilgach bufferda turadi, timeout o'rnatish uchun
# qilingan setattr uni yo'q qiladi → har strelka "yolg'iz ESC = bekor" bo'lardi.
# Fix: raw rejim BIR MARTA boshda; tsiklda faqat bloklovchi `dd` (sof read()).
@test "select_with_arrows: klavish tsiklida timeout'li read yo'q (read -t taqiqlangan)" {
  local n
  n="$(_arrows_body | grep -vE '^\s*#' | grep -cE 'read -rsn?[0-9]* -t' || true)"
  [ "$n" -eq 0 ]
}

@test "select_with_arrows: baytlar bloklovchi dd bilan, tsiklda tcsetattr YO'Q" {
  local body; body="$(_arrows_body)"
  # _rd yordamchisi: dd bilan BITTA read() (termios'ga tegmaydi). Bo'lak
  # o'lchami muhim emas — muhimi bitta bloklovchi read va tcsetattr yo'qligi.
  printf '%s\n' "$body" | grep -qE 'dd bs=[0-9]+ count=1'
  # `stty min 0 time` (per-o'qish VTIME) endi BO'LMASLIGI shart — MSYS konsolida
  # u kutayotgan baytlarni o'chirib yuborardi.
  ! printf '%s\n' "$body" | grep -vE '^\s*#' | grep -qE 'stty min 0 time'
  # Raw rejim bir marta boshda o'rnatiladi (min 1 time 0) va EXIT'da tiklanadi.
  printf '%s\n' "$body" | grep -qE 'stty -echo -icanon -icrnl min 1 time 0'
}

@test "select_with_arrows: birinchi o'qish ham _rd (dd) bilan bo'ladi" {
  # bash `read -n1` ham ichida tcsetattr qiladi — tez bosilgan klavishlarni
  # o'chirib yubormasligi uchun birinchi o'qish ham dd orqali (bo'lakma-bo'lak).
  _arrows_body | grep -vE '^\s*#' | grep -qE '^\s*buf=""; _rd buf$'
}

@test "select_with_arrows: ESC davomi BLOKLAB o'qiladi, ESC-ESC = bekor" {
  local body n
  body="$(_arrows_body)"
  # Ketma-ketlik bo'lakka sig'masa (yolg'iz ESC yoki bo'lingan CSI) davomi
  # bloklovchi qo'shimcha _rd bilan olinadi — timeout ISHLATILMAYDI.
  n="$(printf '%s\n' "$body" | grep -vE '^\s*#' | grep -cE '_rd more')"
  [ "$n" -ge 2 ]
  # Yolg'iz ESC darhol bekor qilmaydi — ikkinchi ESC bekor qiladi.
  printf '%s\n' "$body" | grep -q "ESC-ESC"
}

@test "select_with_arrows: chiqishda TTY holatini tiklaydi (stty restore + EXIT trap)" {
  local body; body="$(_arrows_body)"
  printf '%s\n' "$body" | grep -qE 'stty -g'                 # eski holatni saqlaydi
  printf '%s\n' "$body" | grep -qE "trap '.*stty .*' EXIT"   # EXIT'da tiklaydi
}

@test "select_with_arrows: strelka baytlari harakatga bog'lanadi" {
  local body; body="$(_arrows_body)"
  printf '%s\n' "$body" | grep -qE '^\s*A\) action=up'
  printf '%s\n' "$body" | grep -qE '^\s*B\) action=down'
  printf '%s\n' "$body" | grep -qE '^\s*H\) action=home'
  printf '%s\n' "$body" | grep -qE '^\s*F\) action=end'
  # O'ng/chap (C/D) qidiruv satrini tahrirlamaydi — ular ilgari ham dispatch'da
  # tarmoqsiz edi (ya'ni amalda `skip`). Endi umumiy `*) action=skip` ga tushadi:
  # MUHIMI — menyuni YOPMAYDI. Buni 'notanish CSI' testi ham tekshiradi.
  printf '%s\n' "$body" | grep -qE '^\s*\*\) action=skip'
}

# --- Scroll/g'ildirak va notanish klavishlar tuzatishlari -------------------
@test "select_with_arrows: alt-screen + alternate-scroll (g'ildirak bilan scroll)" {
  local body; body="$(_arrows_body)"
  printf '%s\n' "$body" | grep -q '1049h'    # alt-screen'ga kirish
  printf '%s\n' "$body" | grep -q '1007h'    # g'ildirak → ↑/↓ strelka
  printf '%s\n' "$body" | grep -q '1049l'    # chiqishda tiklash
}

@test "select_with_arrows: notanish CSI ketma-ketlik menyuni YOPMAYDI (skip)" {
  local body; body="$(_arrows_body)"
  printf '%s\n' "$body" | grep -qE 'action=skip'
  # Eski xulq (har notanish c2 → cancel) qaytib kelmaganini tekshiramiz.
  ! printf '%s\n' "$body" | grep -vE '^\s*#' | grep -qE '^\s*\*\) action=cancel'
}

@test "select_with_arrows: klavish tsiklida awk chaqirilmaydi (Windows fork sekinligi)" {
  # Datafile bir marta oldindan o'qiladi; har siljishda awk/subshell ochish
  # MSYS'da bitta strelkani soniyagacha cho'zib, "scroll ishlamayapti"ga sabab edi.
  local n
  n="$(_arrows_body | grep -vE '^\s*#' | grep -c 'awk ' || true)"
  [ "$n" -eq 0 ]
}

@test "select_with_fzf: fzf xatosida die emas — ichki menyuga fallback (rc=3)" {
  awk '/^select_with_fzf\(\) \{/{f=1} f{print} f&&/^\}$/{exit}' "$SELECTOR" | grep -q 'return 3'
  grep -q "fzf ishga tushmadi" "$SELECTOR"
}

@test "bin/lib: himoyalanmagan standalone (( )) yo'q (ERR-trap tuzog'i)" {
  # Statement-pozitsiyadagi `(( ifoda ))` set -e ostida XAVFLI: ifoda false bo'lsa
  # 1 qaytaradi → die. Har bunday qator `&&` yoki `||` bilan o'ralgan bo'lishi
  # SHART (yoki set +e zonasida). `for ((` / `while ((` / `if ((` bular emas.
  run grep -rnE '^[[:space:]]*\(\(' "$PROJECT_ROOT/bin" "$PROJECT_ROOT/lib"
  if [ "$status" -eq 0 ]; then
    # Topilganlarning HAMMASI &&/|| bilan o'ralgan bo'lishi kerak. O'ralmagani bo'lsa — fail.
    local unguarded
    unguarded="$(printf '%s\n' "$output" | grep -vE '\)\)[[:space:]]*(&&|\|\|)' || true)"
    if [ -n "$unguarded" ]; then
      echo "Himoyalanmagan standalone (( )) topildi:"
      echo "$unguarded"
      false
    fi
  fi
}
