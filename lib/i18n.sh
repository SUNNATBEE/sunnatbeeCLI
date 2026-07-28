#!/usr/bin/env bash
# shellcheck shell=bash
#
# lib/i18n.sh — yengil ko'p tillilik (i18n) qatlami.
#
# Dizayn: GETTEXT uslubi. O'zbekcha manba matni KALIT bo'ladi; inglizcha
# tarjima `lib/i18n/en.sh` da (assotsiativ massiv `MSG_EN`). Tarjima topilmasa
# — o'zbekcha manba o'zgarishsiz qaytadi. Shu tufayli:
#   • o'zbekcha (standart) til uchun hech narsa migratsiya qilish shart emas;
#   • tarjima qisman bo'lsa ham hech narsa buzilmaydi (uz'ga qaytadi).
#
# Til tanlash tartibi (birinchi mos kelgani):
#   1) AIDEVIX_LANG=uz|en        — aniq, hammasidan ustun
#   2) LC_ALL / LC_MESSAGES / LANG locale'i:
#        uz*           → uz
#        C / POSIX / '' → uz   (standart/minimal — loyiha tili)
#        boshqa har qanday (en*, ru*, de* ...) → en  (xalqaro o'qiluvchanlik)
#
# Foydalanuvchi xohlagan tilni majburlashi mumkin:  export AIDEVIX_LANG=en

# aidevix_detect_lang — joriy tilni aniqlaydi: "uz" yoki "en".
aidevix_detect_lang() {
  local l="${AIDEVIX_LANG:-${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}}"
  case "$l" in
    uz|uz[_.-]*)                           printf 'uz' ;;
    ''|C|POSIX|C.[!a-z]*|C.*|POSIX.*)      printf 'uz' ;;
    en|en[_.-]*)                           printf 'en' ;;
    *)                                     printf 'en' ;;
  esac
}

# Joriy til bir marta hal qilinadi (qayta hisoblamaslik uchun).
AIDEVIX_LANG_RESOLVED="$(aidevix_detect_lang)"

# Inglizcha katalog. Faqat "en" rejimida yuklanadi (uz uchun keraksiz I/O yo'q).
# `-g` SHART: bu fayl funksiya ichidan ham `source` qilinadi (testlarda
# load_selector, ishlab chiqarishda aidevix_set_lang). `-g` bo'lmasa massiv
# O'SHA FUNKSIYAGA LOKAL bo'lib qoladi va chiqishda yo'qoladi — keyin
# `${MSG_EN[$kalit]}` assotsiativ emas, INDEKSLI massiv sifatida o'qilib,
# kalitni arifmetik hisoblashga urinadi ("syntax error: operand expected")
# va tarjima jim ishlamay qo'yadi.
# `=()` ham SHART: `declare -gA MSG_EN` massivni e'lon qiladi, lekin QIYMAT
# BERMAYDI — shunda `${#MSG_EN[@]}` `set -u` ostida "unbound variable" bo'lib
# skriptni JIMGINA yiqitadi. Aynan shu sabab `aidevix --lang en` hech narsa
# chiqarmasdan 1 kod bilan to'xtardi (aidevix_set_lang ichidagi tekshiruv).
declare -gA MSG_EN=()
if [[ "$AIDEVIX_LANG_RESOLVED" == "en" ]]; then
  __i18n_dir="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
  if [[ -r "$__i18n_dir/i18n/en.sh" ]]; then
    # shellcheck source=i18n/en.sh
    source "$__i18n_dir/i18n/en.sh"
  fi
  unset __i18n_dir
fi

# t_v <var> <manba> [argumentlar...] — t() ning FORK'SIZ varianti: natijani
# stdout'ga emas, o'zgaruvchiga yozadi. `$(t ...)` — buyruq-almashtirish, ya'ni
# har chaqiruvda fork; konfiguratsiyani o'qish (parse_agents) va menyu chizish
# yo'llarida bu yuzlab fork bo'lib, Windows/MSYS'da sezilarli sekinlashtiradi.
t_v() {
  local __v="$1" __src="$2"; shift 2
  local __out="$__src"
  # `+x` — bo'sh tarjima ham hisobga olinsin (t() bilan bir xil semantika).
  if [[ "${AIDEVIX_LANG_RESOLVED:-uz}" == "en" && -n "${MSG_EN[$__src]+x}" ]]; then
    __out="${MSG_EN[$__src]}"
  fi
  if (( $# )); then
    # shellcheck disable=SC2059  # $__out — ataylab format-satr
    printf -v "$__v" "$__out" "$@"
  else
    printf -v "$__v" '%s' "$__out"
  fi
}

# aidevix_set_lang <uz|en> — tilni MAJBURAN o'rnatadi (picker yoki saqlangan
# tanlovdan keyin). Kerak bo'lsa inglizcha katalogni yuklaydi.
aidevix_set_lang() {
  case "$1" in
    en) AIDEVIX_LANG_RESOLVED=en ;;
    uz) AIDEVIX_LANG_RESOLVED=uz ;;
    *)  return 1 ;;
  esac
  if [[ "$AIDEVIX_LANG_RESOLVED" == "en" && "${#MSG_EN[@]}" -eq 0 ]]; then
    local d; d="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
    # shellcheck source=i18n/en.sh
    [[ -r "$d/i18n/en.sh" ]] && source "$d/i18n/en.sh"
  fi
  return 0
}

# t <uz-manba> [printf-arg...]
#   O'zbekcha manbani KALIT sifatida ishlatib, joriy tildagi matnni QAYTARADI
#   (chop etmaydi — odatdagi printf/log oqimiga mos). Argument berilsa, matn
#   printf format-satri sifatida ishlatiladi (masalan "%s").
t() {
  local fmt="$1"; shift
  if [[ "$AIDEVIX_LANG_RESOLVED" == "en" && -n "${MSG_EN[$fmt]+x}" ]]; then
    fmt="${MSG_EN[$fmt]}"
  fi
  if (( $# > 0 )); then
    # shellcheck disable=SC2059  # fmt — ataylab format-satr
    printf "$fmt" "$@"
  else
    printf '%s' "$fmt"
  fi
}
