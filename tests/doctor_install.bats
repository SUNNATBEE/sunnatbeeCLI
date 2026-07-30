#!/usr/bin/env bats
# doctor_install.bats — `aidevix --doctor` dagi "O'rnatish" bo'limi.
#
# NEGA KERAK: "kimda yangi versiya o'rnatiladi, kimda yo'q" shikoyatining eng
# keng tarqalgan sababi — PATH'da BIR NECHTA alohida o'rnatilgan nusxa.
# `npm i -g aidevix@latest` bittasini yangilaydi, terminal esa PATH'da OLDINDA
# turgan boshqasini ishga tushiradi. Doctor buni ko'rsatishi SHART, aks holda
# foydalanuvchi "yangiladim, lekin o'zgarmadi" degan tuzoqda qoladi.

load test_helper

setup() {
  setup_env
  export AI_PULT_CONFIG="$FIXTURE_CONFIG"
}

# _fake_install <ildiz> <versiya> <shim-papka> — soxta o'rnatish + PATH shim'i.
_fake_install() {
  local root="$1" ver="$2" bindir="$3"
  mkdir -p "$root/bin" "$bindir"
  printf '%s\n' "$ver" > "$root/VERSION"
  : > "$root/bin/ai-selector.sh"
  cat > "$bindir/aidevix" <<EOF
#!/usr/bin/env bash
exec bash "$root/bin/ai-selector.sh" "\$@"
EOF
  chmod +x "$bindir/aidevix"
}

@test "doctor: ishlayotgan nusxani va uning ildizini ko'rsatadi" {
  run bash "$SELECTOR" --doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"$PROJECT_ROOT"* ]]
  # Ishlayotgan nusxa ALOHIDA belgilanadi.
  [[ "$output" == *"hozir ishlayotgan"* || "$output" == *"currently running"* ]]
}

@test "doctor: PATH'dagi BOSHQA nusxani topadi va nomuvofiqlikni aytadi" {
  local other="$BATS_TEST_TMPDIR/other" fakebin="$BATS_TEST_TMPDIR/fakebin"
  _fake_install "$other" "9.9.9" "$fakebin"

  # Soxta shim PATH'da BIRINCHI — ya'ni `aidevix` O'SHANI ishga tushirardi.
  PATH="$fakebin:$PATH" run bash "$SELECTOR" --doctor
  [ "$status" -eq 0 ]
  # Boshqa nusxa versiyasi bilan sanab o'tiladi.
  [[ "$output" == *"9.9.9"* ]]
  # Ko'p o'rnatish haqida ogohlantirish.
  [[ "$output" == *"alohida o'rnatish topildi"* \
     || "$output" == *"separate installations found"* ]]
  # Va ENG MUHIMI: PATH'da birinchi turgani ishlayotgani EMAS.
  [[ "$output" == *"BIRINCHI"* || "$output" == *"FIRST in PATH"* ]]
}

@test "doctor: yangilanish kanali (git/npm) ko'rsatiladi" {
  run bash "$SELECTOR" --doctor
  [ "$status" -eq 0 ]
  # Repo ichida ishlaganda kanal — git.
  [[ "$output" == *"git"* ]]
  [[ "$output" == *"Yangilanish holati:"* || "$output" == *"Update status:"* ]]
}

@test "doctor: AIDEVIX_NO_AUTOUPDATE=1 bo'lsa buni AYTADI" {
  # Jim o'chib qolgan avto-yangilanish — "nega yangilanmayapti?" savolining
  # yana bir sababi. Doctor buni yashirmasligi kerak.
  AIDEVIX_NO_AUTOUPDATE=1 run bash "$SELECTOR" --doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"AIDEVIX_NO_AUTOUPDATE"* ]]
}
