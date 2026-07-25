#!/usr/bin/env bats
# menu_reader.bats — ↑/↓ menyudagi KLAVISHA O'QISH qatlami uchun regressiya
# testlari.
#
# Bug (v1.7.2 dan keyingi ishlanma holat): klavisha o'qigich `_rb` dan bo'lak
# (chunk) o'qiydigan `_rd` ga qayta yozildi, lekin CHAQIRUV joylari `_rb` bo'lib
# qoldi. `select_with_arrows` ichida `set +e; trap - ERR` bo'lgani uchun
# "command not found" (127) JIM yutildi: `key` bo'sh qolib, menyu cheksiz
# aylanaverdi — foydalanuvchi buni "menyu qotib qoldi" deb ko'radi.
#
# Bu yerda TTY shart emas: STRUKTURAVIY tekshiruv — chaqirilgan har bir ichki
# yordamchi ANIQ e'lon qilinganini kafolatlaydi va shu sinf bug qaytmasligiga
# qarshi qo'riqchi bo'ladi.

load test_helper

setup() {
  setup_env
}

# select_with_arrows tanasini ajratib oladi (funksiya boshidan ustun-0 `}` gacha).
_arrows_body() {
  awk '/^select_with_arrows\(\) \{/{f=1} f{print} f&&/^\}$/{exit}' "$SELECTOR"
}

# --- ASOSIY qo'riqchi: chaqirilgan ichki yordamchilar e'lon qilinganmi? ----
@test "select_with_arrows: chaqirilgan har bir ichki _yordamchi e'lon qilingan" {
  local body called defined missing=""
  body="$(_arrows_body)"

  # E'lon qilinganlar: `  _xx() {` ko'rinishidagi qatorlar.
  defined="$(printf '%s\n' "$body" | grep -oE '^[[:space:]]*_[a-z_]+\(\)' | tr -d ' ()' | sort -u)"

  # Chaqirilganlar: buyruq o'rnida turgan `_xx` (qator boshida yoki `;`/`&&` dan
  # keyin). `_xx=...` (o'zgaruvchiga qiymat berish) va `local _xx` — chaqiruv
  # EMAS, shuning uchun ularni chiqarib tashlaymiz.
  called="$(printf '%s\n' "$body" \
    | grep -vE '^[[:space:]]*#' \
    | grep -vE '^[[:space:]]*(local|declare|readonly)\b' \
    | grep -oE '(^|[;&|]|then |else |do )[[:space:]]*_[a-z_]+([[:space:]]|$)' \
    | grep -oE '_[a-z_]+' | sort -u)"

  local fn
  for fn in $called; do
    printf '%s\n' "$defined" | grep -qx "$fn" || missing="$missing $fn"
  done

  [ -z "$missing" ] || {
    echo "E'lon qilinmagan yordamchi(lar) chaqirilgan:$missing"
    echo "E'lon qilinganlar: $(echo $defined)"
    false
  }
}

# --- O'qigich BITTA bloklovchi read() ishlatadi (tsiklda tcsetattr yo'q) ---
@test "select_with_arrows: _rd bo'lak (chunk) o'qigichi mavjud" {
  _arrows_body | grep -qE '^\s*_rd\(\)\s*\{.*dd bs=[0-9]+ count=1'
}

@test "select_with_arrows: klavisha tsiklida stty/tcsetattr yo'q" {
  # Yagona stty — tsikldan OLDIN (raw rejimga o'tish) va EXIT-trapda (tiklash).
  # Tsikl ichida stty bo'lsa MSYS konsolida kutayotgan baytlar o'chib ketadi.
  local loop
  # FAQAT tsikl tanasi: `  while :; do` dan mos keluvchi `  done` gacha.
  loop="$(_arrows_body | awk '/^  while :; do$/{f=1} f{print} f&&/^  done$/{exit}')"
  [ -n "$loop" ]
  run bash -c "printf '%s\n' \"\$1\" | grep -nE '(^|[;&| ])stty ' || true" _ "$loop"
  [ -z "$output" ]
}

# --- Bo'lak tahlili: bir bo'lakda BIR NECHTA klavisha bo'lishi mumkin ------
@test "select_with_arrows: bo'lak ichidagi barcha baytlar qayta ishlanadi" {
  # G'ildirak tez aylanganda alternate-scroll bitta read()da bir necha \033[A
  # yuboradi. Tahlil indeks bo'yicha (bi < blen) aylanishi SHART.
  _arrows_body | grep -qE 'while \(\( bi < blen \)\); do'
}

@test "select_with_arrows: enter/cancel ichki tsikldan `break 2` bilan chiqadi" {
  # Tahlil ikki qatlamli tsiklda: oddiy `break` faqat bo'lak tsiklini to'xtatib,
  # tanlangan agent bilan menyuni QAYTA chizib yuborardi.
  _arrows_body | grep -qE 'cancel\) cancelled=1; break 2'
  _arrows_body | grep -qE 'enter\).*break 2'
}

# --- Strelka hech qachon "bekor" bo'lib o'qilmaydi -------------------------
@test "select_with_arrows: ESC bo'lak oxirida bo'lsa davomi BLOKLAB o'qiladi" {
  # v1.5.0–v1.7.2 bug'i: ESC dan keyin TIMEOUT bilan o'qilardi; MSYS konsolida
  # tcsetattr kutayotgan baytlarni o'chirgani uchun har strelka "yolg'iz ESC" =
  # bekor bo'lib o'qilardi. Endi timeout YO'Q — bloklovchi qo'shimcha bo'lak
  # o'qiladi (strelka bo'linib kelsa ham to'g'ri yig'iladi).
  local body; body="$(_arrows_body)"
  printf '%s\n' "$body" | grep -qE '\(\( bi >= blen \)\); then'
  printf '%s\n' "$body" | grep -qE 'more=""; _rd more'
  # ESC ni davomi bilan qayta tahlil qilish (bi ni orqaga surish).
  printf '%s\n' "$body" | grep -qE 'bi=\$\(\( bi - 1 \)\)'
}

@test "select_with_arrows: ESC-ESC bekor qiladi (ekrandagi '2×ESC' yo'riqnomasi)" {
  _arrows_body | grep -qE "nx\" == \\\$'\\\\033' \]\]; then\$|action=cancel  *# ESC-ESC"
}

@test "select_with_arrows: bo'lingan CSI davomi ham bloklab o'qiladi" {
  # Ketma-ketlik parametrlar o'rtasida bo'linsa (ESC[ | B), yakuniy bayt keyingi
  # bo'lakda ODDIY HARF bo'lib qidiruvga tushib ketmasligi kerak.
  local body; body="$(_arrows_body)"
  printf '%s\n' "$body" | grep -qE 'while \(\( _g < 32 \)\); do'
  printf '%s\n' "$body" | grep -qE 'more=""; _rd more'
}

# --- dd bo'lmasa JIM o'lmaydi ---------------------------------------------
@test "select_with_arrows: dd bo'lmasa rc=2 (jim exit emas)" {
  _arrows_body | grep -qE 'command -v dd .* \|\| return 2'
}

# --- run_menu rc=2 ni tutib, raqamli menyuga tushadi ----------------------
@test "run_menu: select_with_arrows rc=2 bo'lsa raqamli menyuga fallback" {
  local body
  body="$(awk '/^run_menu\(\) \{/{f=1} f{print} f&&/^\}$/{exit}' "$SELECTOR")"
  # Har ikkala chaqiruv joyi ham rc'ni ushlashi kerak.
  [ "$(printf '%s\n' "$body" | grep -cE 'select_with_arrows .*\)" \|\| rc=\$\?')" -eq 2 ]
  [ "$(printf '%s\n' "$body" | grep -cE 'rc == 2')" -eq 2 ]
}

# --- crash() alt-screen'dan CHIQIB, so'ng xato yozadi ---------------------
@test "crash: xato matnidan OLDIN alt-screen'dan chiqadi" {
  # Aks holda xato ALTERNATE ekranga chiziladi va ekran tiklanganda O'CHADI —
  # "hech qanday xato ko'rsatmasdan yopildi" shikoyatining sababi.
  local body
  body="$(awk '/^crash\(\) \{/{f=1} f{print} f&&/^\}$/{exit}' "$SELECTOR")"
  local alt err
  alt="$(printf '%s\n' "$body" | grep -n '1049l' | head -1 | cut -d: -f1)"
  err="$(printf '%s\n' "$body" | grep -n 'log_error' | head -1 | cut -d: -f1)"
  [ -n "$alt" ] && [ -n "$err" ] && [ "$alt" -lt "$err" ]
}

# --- npm self-update aniq interpretator bilan qayta start beradi ----------
@test "npm_autoupdate_apply: exec bash \"\$SELF\" (exec \"\$0\" emas)" {
  local body
  body="$(awk '/^npm_autoupdate_apply\(\) \{/{f=1} f{print} f&&/^\}$/{exit}' "$SELECTOR")"
  printf '%s\n' "$body" | grep -qE 'exec bash "\$SELF" "\$@"'
  ! printf '%s\n' "$body" | grep -qE '^\s*exec "\$0"'
}
