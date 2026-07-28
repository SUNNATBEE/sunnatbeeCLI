<div align="center">

<img src="assets/log.jpg" alt="Aidevix logosi" width="120" />

# ✦ Aidevix CLI

### *Bitta buyruq. 28 ta top AI CLI. Cheksiz imkoniyat.*

`aidevix` deb yozing → ro'yxatdan tanlang → CLI avtomatik ishga tushadi.
O'rnatilmagan bo'lsa — o'zi o'rnatadi. 🪄

**🇺🇿 O'zbekcha** · [🇬🇧 English](./README.en.md)

[![Release](https://img.shields.io/github/v/release/SUNNATBEE/sunnatbeeCLI?label=release&logo=github&color=8a2be2&sort=semver)](https://github.com/SUNNATBEE/sunnatbeeCLI/releases/latest)
[![CI](https://github.com/SUNNATBEE/sunnatbeeCLI/actions/workflows/ci.yml/badge.svg)](https://github.com/SUNNATBEE/sunnatbeeCLI/actions/workflows/ci.yml)
[![Shell](https://img.shields.io/badge/shell-bash%20%7C%20zsh-1f425f.svg?logo=gnu-bash&logoColor=white)](#)
[![Powered by fzf](https://img.shields.io/badge/powered%20by-fzf-00b894.svg)](https://github.com/junegunn/fzf)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)

[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows-555?logo=linux&logoColor=white)](#-ornatish-installation)
[![PRs welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](./CONTRIBUTING.md)
[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-fe5196?logo=conventionalcommits&logoColor=white)](https://www.conventionalcommits.org/)
[![Stars](https://img.shields.io/github/stars/SUNNATBEE/sunnatbeeCLI?style=social)](https://github.com/SUNNATBEE/sunnatbeeCLI/stargazers)

[![⚡ Hoziroq o'rnatish](https://img.shields.io/badge/⚡_Hoziroq_o'rnatish-bir_buyruq-ff69b4?style=for-the-badge)](#-ornatish-installation)
[![📦 Eng so'nggi reliz](https://img.shields.io/badge/📦_Eng_so'nggi_reliz-v1.1.0-8a2be2?style=for-the-badge&logo=github)](https://github.com/SUNNATBEE/sunnatbeeCLI/releases/latest)

<br/>

<img src="assets/demo.svg" alt="Aidevix CLI demo" width="680" />

<sub>▶ Jonli (animatsion) demoni yaratish: <code>bash scripts/record-demo.sh</code> → <code>assets/demo.gif</code></sub>

</div>

> **⚡ Tezkor o'rnatish** — Git Bash (Windows) yoki terminal (Linux/macOS)da:
>
> ```bash
> curl -fsSL https://raw.githubusercontent.com/SUNNATBEE/sunnatbeeCLI/main/bootstrap.sh | bash
> ```
>
> So'ng `source ~/.bashrc && aidevix`. To'liq qo'llanma: [**O'rnatish**](#-ornatish-installation) · Yuklab olish: [**Releases**](https://github.com/SUNNATBEE/sunnatbeeCLI/releases/latest)

---

## 📖 Loyiha haqida

**Aidevix CLI** — terminaldagi 28 ta top AI CLI agentini (Claude Code, Codex,
Gemini, Copilot, Aider, Ollama va h.k.) yagona interaktiv menyu orqali bitta
buyruq bilan boshqarish vositasi. `bash`, `zsh`, `cmd` va `PowerShell`'da ishlaydi.

> 🎓 Bu loyiha **o'quvchilar uchun** maxsus tuzilgan: ular bitta buyruq bilan
> o'rnatadi va istalgan AI CLI'dan darrov foydalana boshlaydi — qaysi paket
> qaysi buyruq bilan o'rnatilishini eslab o'tirish shart emas.

> ⚠️ **Aidevix nima — va nima EMAS.** Aidevix faqat **ishga tushirgich (launcher)**:
> AI CLI'larni o'rnatib, ochib beradi — xolos. CLI'larning **o'zi** uchinchi tomon
> dasturlar (Anthropic, Google, OpenAI…). **Ba'zilari pullik, ba'zilari bepul/bepul
> tier** (menyuda 🆓/🔑/💳 belgilari). Aidevix **savollarga javob bermaydi** va
> **API kalit/token bermaydi** — kalitni o'zingiz tegishli xizmatdan olasiz.

---

## ✨ Imkoniyatlar (Features)

| | Imkoniyat | Tavsif |
|---|---|---|
| 🎨 | **Professional dizayn** | AD logosi + gradientli banner, jonli **spinner** animatsiyasi, rangli preview — toza va zamonaviy |
| ⚡ | **Bir buyruq bilan o'rnatish** | `curl ... \| bash` — qolgani avtomatik |
| 🎛️ | **Yagona `aidevix` menyusi** | 28 ta top AI CLI bitta interaktiv ro'yxatda (status + preview) |
| 🪄 | **Avtomatik o'rnatish** | Tanlangan CLI yo'q bo'lsa — ruxsat so'rab o'zi o'rnatadi |
| 🔐 | **Login yo'riqnomasi** | Har agent uchun qaysi login/API kalit kerakligi ko'rsatiladi; kalitlar saqlanmaydi |
| 🚀 | **Tezkor ishga tushirish** | `aidevix claude` — menyusiz, to'g'ridan-to'g'ri |
| 📊 | **Lokal statistika** | Har agent necha marta ishlatilganini sanaydi; menyu va `--list` eng ko'p ishlatilgan bo'yicha tartiblanadi (yonida `· N×`). **Faqat shu kompyuterda** — hech qayoqqa yuborilmaydi |
| 🪄 | **fzf avtomatik o'rnatiladi** | O'rnatishda fzf'ni o'zi yuklab oladi (sudo kerak emas); bo'lmasa raqamli menyuga o'tadi |
| 🔄 | **Avtomatik yangilanish** | Loyiha yangilansa — `aidevix` o'zini jim yangilaydi va "nima yangilangani"ni ko'rsatadi (qo'lda hech narsa qilish shart emas) |
| 🆕 | **Agentlar har doim eng so'nggi** | Tanlangan agentni ishga tushirishdan oldin, vaqti-vaqti bilan (3 soatda bir) eng so'nggi versiyaga yangilab qo'yadi — eski Gemini CLI'dagi *"client no longer supported"* kabi muammolar o'z-o'zidan tuzaladi |
| ♻️ | **`aidevix --update`** | O'rnatilgan barcha agentlarni bir buyruq bilan yangilaydi |
| 🩺 | **`aidevix --doctor`** | Muhitni (node/npm/python/fzf, PATH) tekshiradi |
| ➕ | **`aidevix --add`** | Interaktiv tarzda yangi agent qo'shadi (faylni qo'lda tahrirlamasdan) |
| 🧭 | **PATH avtomatik tuzatish** | npm/pip global bin papkasini o'zi topadi — yangi kompyuterda ham ishlaydi |
| 🩺 | **Tushunarli xato xabarlari** | Xato bo'lsa — sababini va yechimini **oddiy tilda** aytadi (bolalar ham tushunadi) |
| ⌨️ | **Shell completion** | `aidevix <TAB>` agent nomlarini to'ldiradi (bash/zsh) |
| 🪟 | **Windows wrapper** | `aidevix.cmd` / `aidevix.ps1` — PowerShell/cmd'dan ham ishlaydi |
| 🔌 | **Kengaytiriluvchi** | Yangi agent qo'shish — kod yozmasdan, bitta qator |
| 🛡️ | **Xavfsiz** | `.bashrc`/`.zshrc` o'zgartirishdan oldin **zaxiralanadi** |
| 🧹 | **Toza o'chirish** | `uninstall.sh` hammasini izsiz qaytaradi |

---

## 🤖 Qo'llab-quvvatlanadigan AI CLI agentlar

| # | Agent | Buyruq | Guruh | Login |
|---|---|---|---|---|
| 1 | 🧠 Claude Code | `claude` | Coding | 🔑 / 💳 |
| 2 | ⚡ OpenAI Codex | `codex` | Coding | 🌐 / 🔑 |
| 3 | ✨ Gemini CLI | `gemini` | Coding | 🌐 / 🔑 |
| 4 | 🐙 GitHub Copilot | `copilot` | Coding | 💳 |
| 5 | 🟢 OpenCode | `opencode` | Coding | 🔑 |
| 6 | 💅 Crush | `crush` | Coding | 🔑 |
| 7 | 🐉 Qwen Code | `qwen` | Coding | 🌐 / 🔑 |
| 8 | 🔁 Continue | `cn` | Coding | 🌐 / 🔑 |
| 9 | 🎯 Cursor Agent | `cursor-agent` | Coding | 🌐 |
| 10 | 🗺️ Plandex | `plandex` | Coding | 🌐 / 🔑 |
| 11 | 🤝 Aider | `aider` | Pair | 🔑 |
| 12 | 🦢 Goose | `goose` | Agent | 🔑 |
| 13 | 🦙 Ollama | `ollama` | Local | 🆓 |
| 14 | 💬 llm | `llm` | Chat | 🔑 |
| 15 | 🗨️ AIChat | `aichat` | Chat | 🔑 |
| 16 | 💻 Open Interpreter | `interpreter` | Agent | 🆓 **bepul** |
| 17 | 🙌 OpenHands | `openhands` | Agent | 🆓 **bepul** |
| 18 | 🛠️ SWE-agent | `sweagent` | Agent | 🆓 **bepul** |
| 19 | 🧩 Cline CLI | `cline` | Coding | 🆓 **bepul** |
| 20 | 🦘 Kilo CLI | `kilo` | Coding | 🆓 **bepul** |
| 21 | 🤖 Grok Build | `grok` | Coding | 💳 / 🌐 |
| 22 | 🚀 Antigravity | `antigravity` | Coding | 🆓 **bepul** |
| 23 | 🐙 GitHub CLI | `gh` | Tools | 🆓 **bepul** |
| 24 | 🛡️ Freebuff | `freebuff` | Coding | 🌐 |
| 25 | 🐝 Codebuff | `codebuff` | Coding | 🆓 / 🔑 / 💳 |
| 26 | 🧰 gptme | `gptme` | Agent | 🆓 **bepul** |
| 27 | 💬 Shell GPT | `sgpt` | Chat | 🔑 |
| 28 | 🪄 Mods | `mods` | Chat | 🔑 |

> **Login belgilari:** 🔑 API kalit · 🌐 brauzer orqali login · 💳 obuna · 🆓 **bepul** (ochiq manba / bepul tier).
> 💡 **`aidevix --free`** — faqat bepul agentlarni ko'rsatadi (11+ ta).
> Ro'yxat `config/agents.conf`'da — istalgancha o'zgartirish/qo'shish mumkin.
> ⚠️ Cursor Agent hozircha Windows'da ishlamaydi; Antigravity — qo'lda yuklab olinadi
> (IDE); GitHub CLI Windows'da `winget install GitHub.cli` bilan ham o'rnatiladi.

---

## 🎬 Video qo'llanma (O'quvchilar uchun)

> 🎥 O'rnatish va foydalanishning **to'liq jarayonini** video orqali ko'rib
> o'rganing — ayniqsa birinchi marta o'rnatayotgan bo'lsangiz tavsiya etiladi.

<div align="center">

<!--
  📌 VIDEO HAVOLASINI SHU YERGA QO'YING.
  Havola tayyor bo'lganda quyidagi qatordagi "#" o'rniga to'liq manzilni yozing
  (masalan: https://youtu.be/XXXXXXXX yoki Telegram post havolasi).
-->
[![Video qo'llanma](https://img.shields.io/badge/▶_Video_qo'llanma-tez_orada-lightgrey?style=for-the-badge&logo=youtube&logoColor=white)](#)

*📌 Video havolasi tez orada shu yerga qo'shiladi.*

</div>

---

## 🚀 O'rnatish (Installation)

O'rnatish atigi **bir necha daqiqa**. Quyidagi 3 qadamni ketma-ket bajaring.

> 💡 Pastdagi yozma yo'riqnoma bilan birga yuqoridagi **video qo'llanma**ni ham
> ko'rsangiz, jarayon yanada oson kechadi.

### 1️⃣-qadam — Kerakli dasturlar (Prerequisites)

O'rnatishdan oldin kompyuteringizda quyidagilar bo'lishi kerak:

| Dastur | Majburiymi? | Nima uchun | Qanday o'rnatish |
|---|:---:|---|---|
| **git** | ✅ Ha | Loyihani yuklab olish uchun | [git-scm.com/downloads](https://git-scm.com/downloads) |
| **curl** yoki **wget** | ✅ Ha | O'rnatuvchini yuklab olish | macOS/Linux'da odatda bor; Windows'da Git Bash bilan keladi |
| **fzf** | 🪄 Avtomatik | Chiroyli izlanadigan menyu | O'rnatuvchi **o'zi yuklab oladi** (sudo kerak emas) |
| **Node.js / Python** | ❌ Yo'q | Faqat tanlangan AI CLI uchun | `aidevix` keraklisini o'zi taklif qiladi |

> 🪟 **Windows foydalanuvchilari diqqat!** Bu vosita **Git Bash** ichida ishlaydi.
> Avval [**Git for Windows**](https://git-scm.com/download/win) ni o'rnating
> (Next → Next → Finish), so'ng **"Git Bash"** dasturini oching va quyidagi
> buyruqlarni **o'sha oynada** yozing — oddiy `cmd` yoki PowerShell'da emas.

### 2️⃣-qadam — O'z terminalingizga mos buyruqni tanlang

Qaysi dasturda ishlayotganingizga qarab quyidagilardan **birini** nusxalab,
**Enter** bosing. (Hamma yo'l bir xil natijaga olib keladi.)

> 🧠 **Qisqacha qoida:** yadro `bash` skripti. Linux/macOS'da to'g'ridan-to'g'ri,
> Windows'da esa **Git Bash** oynasida ishlaydi. ⚠️ Oddiy `cmd` yoki PowerShell'dan
> foydalanmang — ularda `bash` PATH'da bo'lmaganligi sababli `"bash" topilmadi`
> xatosi chiqadi. **Git Bash dasturini oching.**

#### 🐧 Linux / 🍎 macOS — `bash` yoki `zsh`

```bash
curl -fsSL https://raw.githubusercontent.com/SUNNATBEE/sunnatbeeCLI/main/bootstrap.sh | bash
```

<sub>`curl` yo'q bo'lsa, `wget` bilan:</sub>

```bash
wget -qO- https://raw.githubusercontent.com/SUNNATBEE/sunnatbeeCLI/main/bootstrap.sh | bash
```

#### 🪟 Windows — Git Bash

Start menyudan **"Git Bash"** dasturini oching (oddiy `cmd`/PowerShell EMAS) va
xuddi yuqoridagi buyruqni yozing:

```bash
curl -fsSL https://raw.githubusercontent.com/SUNNATBEE/sunnatbeeCLI/main/bootstrap.sh | bash
```

> ❓ **"bash" topilmadi degan xato?** Demak siz `cmd` yoki PowerShell'dasiz.
> Ularni yoping va **Git Bash** dasturini oching — buyruq o'sha oynada ishlaydi.

> ⚠️ **`curl: (35) ... CRYPT_E_NO_REVOCATION_CHECK` xatosi?** Bu Windows'da curl
> sertifikat-otzыv serveriga ulana olmaganda chiqadi (internetdagi muammo, sizda
> emas). Yechimi — buyruqqa `--ssl-no-revoke` qo'shing:
>
> ```bash
> curl --ssl-no-revoke -fsSL https://raw.githubusercontent.com/SUNNATBEE/sunnatbeeCLI/main/bootstrap.sh | bash
> ```

> 💡 **Windows'da `aidevix` buyrug'ini ishlatish:** o'rnatishdan keyin `aidevix`
> Git Bash'da darrov ishlaydi. PowerShell/cmd'da ham ishlashi uchun
> `%USERPROFILE%\.local\bin` papkasini Windows **PATH**'iga qo'shing (yoki
> shunchaki Git Bash'dan foydalaning).

#### 📦 Paket menejerlari orqali

```bash
# npm (cross-platform — Node.js va ishga tushish uchun bash kerak)
npm install -g aidevix

# Scoop (Windows)
scoop bucket add aidevix https://github.com/SUNNATBEE/sunnatbeeCLI
scoop install aidevix
```

> Scoop manifesti [`packaging/`](./packaging) papkasida. Homebrew formulasi ham
> shu yerda tayyor turibdi (`packaging/homebrew/aidevix.rb`), lekin u faqat
> alohida tap repozitoriyasi ochilganda ishlaydi.

---

Yuqoridagi buyruq qaysi terminalda bo'lsa ham, hamma narsani **avtomatik** bajaradi:

1. 📥 Loyihani `~/.ai-cli` papkasiga yuklab oladi
2. 🔍 Kerakli dasturlarni tekshiradi va **`fzf`'ni avtomatik o'rnatadi** (chiroyli menyu uchun)
3. 💾 `~/.bashrc` / `~/.zshrc` faylini **zaxiralaydi** (xavfsizlik uchun)
4. 🔗 `aidevix` buyrug'ini o'rnatadi (+ Windows uchun `aidevix.cmd` / `aidevix.ps1`)
5. ⚙️ Agentlar ro'yxatini `~/.config/ai-cli/` ga ko'chiradi
6. ⌨️ `PATH` va avtomatik to'ldirishni (completion) sozlaydi

<details>
<summary><b>🛠️ Variant B — Qo'lda o'rnatish (git clone bilan)</b></summary>

Avtomatik buyruqni ishlatishni xohlamasangiz:

```bash
git clone https://github.com/SUNNATBEE/sunnatbeeCLI.git ~/.ai-cli
bash ~/.ai-cli/install.sh
```

</details>

### 3️⃣-qadam — Terminalni qayta oching va tekshiring

O'rnatish tugagach, **terminalni butunlay yopib, qaytadan oching**
(yoki `source ~/.bashrc`). So'ng tekshiring:

```bash
aidevix --doctor     # muhit to'g'ri sozlanganini tekshiradi
aidevix              # menyuni ochadi 🎉
```

✅ Menyu ochildimi? Tabriklaymiz — tayyor! Endi istalgan AI CLI'ni tanlang.

---

> 📌 **Eslatma:** repozitoriyaning standart branchi `master` bo'lsa, URL'dagi
> `main` so'zini `master` ga almashtiring.
>
> 🩺 **Muammo chiqdimi?** Avval **`aidevix --doctor`** ni ishga tushiring — u
> muammoni topib, oddiy tilda nima qilish kerakligini aytadi. To'liq qo'llanma:
> [**TROUBLESHOOTING.md**](./TROUBLESHOOTING.md).

<details>
<summary><b>fzf qo'lda o'rnatish (agar avtomatik o'rnatilmasa)</b></summary>

```bash
brew install fzf            # macOS
sudo apt install fzf        # Debian / Ubuntu
sudo pacman -S fzf          # Arch Linux
winget install fzf          # Windows
# Boshqalar: https://github.com/junegunn/fzf#installation
```
</details>

---

## 🎮 Foydalanish (Usage)

```bash
aidevix
```

```text
  ◆ Aidevix
  ────────────────────────────────────────────────────────────────────────────────────────
  › qidirish   1/28

  ▸ ● Claude Code                        │ Claude Code  ● o'rnatilgan
    ● OpenAI Codex                       │
    ● Gemini CLI                         │ Anthropic'ning rasmiy Claude kod agenti
    ○ GitHub Copilot                     │
    ● OpenCode                           │ buyruq    claude
    ○ Qwen Code                          │ guruh     Coding
    ○ Cursor Agent                       │ provayder anthropic
    ● Freebuff                           │ login     ▪ API kalit
    ○ Codebuff                           │ havola    https://console.anthropic.com/set…
    ○ Aider                              │
    ○ Crush                              │ o'rnatish
    ○ Continue                           │ npm install -g @anthropic-ai/claude-code@lat…
    ○ Plandex                            │
  ────────────────────────────────────────────────────────────────────────────────────────
  ◆ anthropic │ — │ ○ kalit yo'q │ 7/28 o'rnatilgan │ v1.8.0 ● eng so'nggi
  ↑↓ harakat   ⏎ ishga tushirish   a-z qidirish   esc chiqish
```

Yozib qidiring → `↑/↓` bilan tanlang → `ENTER`. **O'ng ustunda** tanlangan
agentning tafsiloti (holati, buyrug'i, provayderi, login talabi, o'rnatish
usuli) jonli ko'rinadi. Pastdagi **status bar** — provayder, model, API-kalit
holati, o'rnatilgan/jami va versiya.

> 💡 `fzf` yo'q bo'lsa, xuddi shu narsa ichki `↑/↓` menyusida chiqadi; terminal
> umuman bo'lmasa — **raqamli menyu**. Hech narsa yo'qolmaydi.

### 📐 Tor terminal — avtomatik ustma-ust maket

Terminal **84 ustundan tor** bo'lsa ikki ustun avtomatik ustma-ust (stacked)
maketga o'tadi — ro'yxat tepada, tafsilot pastda:

```text
  ◆ Aidevix
  ────────────────────────────────────────────────────────────────────
  › qidirish   1/28

  ▸ ●  Claude Code         Anthropic'ning rasm…
    ●  OpenAI Codex        OpenAI Codex termi…
    ●  Gemini CLI          Google Gemini term…
    ○  GitHub Copilot      GitHub Copilot CLI…
    ●  OpenCode            Ochiq kodli termin…
  ────────────────────────────────────────────────────────────────────
  Claude Code  ● o'rnatilgan

  Anthropic'ning rasmiy Claude kod agenti

  buyruq    claude
  guruh     Coding
  provayder anthropic
  ────────────────────────────────────────────────────────────────────
  ◆ anthropic │ — │ ○ kalit yo'q │ 7/28 o'rnatilgan │ v1.8.0 ● eng so'nggi
  ↑↓ harakat   ⏎ ishga tushirish   a-z qidirish   esc chiqish
```

### 🎨 Ikonka uslublari (`--icons`)

Interfeys belgilari **uch pog'onada** keladi va Aidevix uni o'zi aniqlaydi
(Nerd Font o'rnatilganmi · terminal UTF-8'mi):

| Pog'ona | Qachon | Namuna |
|---|---|---|
| `nerd` | Nerd Font shrifti topilsa |    |
| `unicode` | Odatiy UTF-8 terminal (standart) | `◆ ● ○ ▪ ▸ │ ─` |
| `ascii` | `LANG=C`, UTF-8 yo'q yoki eski konsol | `# * o k > \| -` |

```bash
aidevix --icons            # joriy uslub + namuna belgilar
aidevix --icons ascii      # majburan ASCII (saqlanadi)
aidevix --icons auto       # keshni tashlab, qaytadan aniqlaydi
export AIDEVIX_ICONS=nerd  # bir sessiya uchun (saqlangan tanlovdan ustun)
```

### 🪄 O'rnatishda jonli animatsiya

CLI o'rnatilayotganda quruq kutish o'rniga — aylanuvchi **spinner** va o'tgan vaqt:

```text
⠹ 📦 Claude Code o'rnatilmoqda  3s
✓ 📦 Claude Code o'rnatilmoqda  (8s)
🚀 Ishga tushirilmoqda  Claude Code
```

### 🪄 Avtomatik o'rnatish

Agar tanlangan CLI tizimda yo'q bo'lsa, `aidevix` shunchaki xato bermaydi — u o'zi
o'rnatishni taklif qiladi:

```text
[!] Agent topilmadi: 'Claude Code' (kerakli buyruq: 'claude').
[i] O'rnatish buyrug'i: npm install -g @anthropic-ai/claude-code
❓ 'Claude Code' hozir o'rnatilsinmi? [y/N] y
[i] O'rnatilmoqda: Claude Code ...
[✓] O'rnatildi: Claude Code
[✓] Ishga tushirilmoqda: Claude Code  ➜  claude
```

### Boshqa buyruqlar

| Buyruq | Vazifasi |
|---|---|
| `aidevix` | Interaktiv menyuni ochadi (fzf bo'lsa fzf + preview, bo'lmasa raqamli) |
| `aidevix <agent>` | Agentni nomi/binari bo'yicha **to'g'ridan-to'g'ri** ishga tushiradi (masalan `aidevix claude`) |
| `aidevix --list` | Barcha CLI'lar va ularning **o'rnatilgan/yo'q** holatini ko'rsatadi |
| `aidevix --free` | 🆓 **Faqat bepul** agentlar menyusi (sinab ko'rish uchun eng yaxshisi) |
| `aidevix --top` | ⭐ **Faqat eng mashhur** (top) agentlar menyusi |
| `aidevix --update` | O'rnatilgan barcha agentlarni yangilaydi |
| `aidevix --doctor` | Muhitni tekshiradi (vositalar, PATH, agentlar holati) |
| `aidevix --add` | Interaktiv tarzda yangi agent qo'shadi |
| `aidevix --stats [on\|off]` | 📊 Global statistika (**opt-in**, standart o'chiq). Yoqilganda menyuda `🔥 #reyting` ko'rinadi; faqat agent nomi + hodisa turi yuboriladi (shaxsiy ma'lumotsiz) |
| `aidevix --lang [uz\|en]` | Interfeys tilini tanlaydi (argumentsiz — interaktiv tanlov) |
| `aidevix --icons [nerd\|unicode\|ascii\|auto]` | 🎨 Ikonka uslubi. Argumentsiz — joriy uslub va namuna belgilar; `auto` — keshni tashlab qaytadan aniqlaydi |
| `aidevix --version` | Aidevix CLI versiyasini ko'rsatadi |
| `aidevix --help` | Yordam matnini chiqaradi |

> 💡 `aidevix <TAB>` — agent nomlarini avtomatik to'ldiradi (o'rnatishdan keyin).

---

## 🔐 Login / API kalitlar

Ko'pchilik AI CLI'lar ishlashidan oldin **hisobga kirish (login)** yoki **API
kalit** talab qiladi. Aidevix buni siz uchun soddalashtiradi:

- 📋 Menyuda har agent yonida belgi (🆓/🔑/🌐/💳), preview'da to'liq login talabi
  va **havola** ko'rinadi.
- 🌐 Login sahifasi brauzerда **faqat zarur bo'lganda** ochiladi — ya'ni agent
  o'zingiz API kalit olishingizni talab qilsa **va** o'sha kalit hali
  o'rnatilmagan bo'lsa. Agar agent o'zi login qilsa (brauzer-login), obuna yoki
  bepul bo'lsa, **yoki kalit allaqachon bor bo'lsa** — brauzer ochilmaydi, faqat
  qisqa eslatma chiqadi.
- 🔒 Kalitlarni o'zingiz, agentning o'z ko'rsatmasi bo'yicha kiritasiz. **Aidevix
  hech qanday parol yoki kalitni ko'rmaydi va saqlamaydi** — ular faqat sizning
  kompyuteringizda qoladi.

> 💡 **Bepulini sinab ko'rmoqchimisiz?** `aidevix --free` — faqat bepul agentlarni
> (Gemini, Qwen, Ollama, Continue, Open Interpreter, OpenHands, SWE-agent, Cline,
> Kilo, GitHub CLI, Antigravity — 11 ta) ko'rsatadi. `aidevix --top` — eng
> mashhurlarini.

| Belgi | Ma'nosi | Misol |
|:---:|---|---|
| 🔑 | **API kalit** kerak | `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, OpenRouter |
| 🌐 | **Brauzer orqali login** | Google / ChatGPT / Cursor hisobi |
| 💳 | **Obuna** kerak | GitHub Copilot, Claude Pro/Max |
| 🆓 | **Bepul** — login shart emas | Ollama (lokal modellar) |

> 💡 Masalan, Claude Code'ni tanlasangiz, u birinchi ishga tushganda
> `ANTHROPIC_API_KEY` so'raydi yoki brauzerda Claude hisobingizga kirishni
> taklif qiladi — ekrandagi ko'rsatmaga amal qiling.

---

## ➕ O'z agentlaringizni qo'shish

Eng kuchli tomoni — **kod yozish shart emas**. Agentlar oddiy matnli faylda:

```bash
~/.config/ai-cli/agents.conf
```

Eng oson yo'li — interaktiv qo'shuvchi:

```bash
aidevix --add
```

Yoki qo'lda — har bir agent **bitta qator**, `|` bilan ajratilgan **5 majburiy + 1
ixtiyoriy maydon**:

```text
NOM | BINARY | BUYRUQ | INSTALL | IZOH | KATEGORIYA
```

| Maydon | Ma'nosi |
|---|---|
| **NOM** | Menyuda ko'rinadigan nom |
| **BINARY** | PATH'da tekshiriladigan bajariluvchi fayl (`command -v`) |
| **BUYRUQ** | Ishga tushiriladigan buyruq (argumentlar bilan) |
| **INSTALL** | CLI yo'q bo'lsa ishlatiladigan o'rnatish buyrug'i |
| **IZOH** | Qisqacha tavsif |
| **KATEGORIYA** | *(ixtiyoriy)* Guruh nomi: `Coding`, `Chat`, `Local` va h.k. |

### Misol

`agents.conf` oxiriga yangi qator qo'shing:

```text
Continue|cn|cn|npm install -g @continuedev/cli|🔁 Continue terminal agenti|Coding
```

> 💡 **Eslatma:** `INSTALL` maydonida `|` (pipe) ishlatmang — u maydon ajratgichi.
> `curl ... | bash` o'rniga pipe-siz shakldan foydalaning:
> ```text
> ...|bash -c "$(curl -fsSL https://example.com/install.sh)"|...
> ```

Saqlang — keyingi `aidevix` ishga tushishida agent menyuda paydo bo'ladi. 🎉

> 🔧 **Muhit o'zgaruvchilari:**
> | O'zgaruvchi | Vazifasi |
> |---|---|
> | `AI_PULT_CONFIG` | Boshqa konfiguratsiya faylini ko'rsatish |
> | `AI_NO_ANIM=1` | Animatsiyalarni o'chirish (spinner/banner) |
> | `NO_COLOR=1` | Ranglarni butunlay o'chirish |
> | `AIDEVIX_LANG` | Interfeys tili: `uz` yoki `en` (berilmasa `LANG`/locale'dan aniqlanadi) |
> | `AIDEVIX_ICONS` | Ikonka uslubi: `nerd`, `unicode`, `ascii` yoki `auto`. Avtomatik aniqlash va saqlangan tanlovdan (`--icons`) USTUN turadi |
> | `AIDEVIX_FZF_PREVIEW=1` | fzf menyusida o'ng preview'ni majburan yoqadi (Windows'da standart o'chiq) |
> | `AIDEVIX_NO_AUTOUPDATE=1` | Avtomatik yangilanishni o'chirish |
> | `AIDEVIX_UPDATE_INTERVAL` | Yangilanish tekshiruvi oralig'i (sekund, standart 10800 = 3 soat) |

---

## 🌐 Til (o'zbekcha / inglizcha)

Aidevix **o'zbekcha** va **inglizcha** to'liq ishlaydi (menyu, izohlar, login
eslatmalari — hammasi bir tilda). **Ilk marta `aidevix` ishga tushganda til
so'raladi:**

```text
  🌐  Til tanlang  /  Choose your language
     [1] English
     [2] Oʻzbekcha
```

Tanlov saqlanadi va keyingi safar so'ralmaydi. Istalgan vaqtda o'zgartirish:

```bash
aidevix --lang          # qayta tanlash (interaktiv)
aidevix --lang en       # inglizcha
aidevix --lang uz       # o'zbekcha
export AIDEVIX_LANG=en  # yoki muhit o'zgaruvchisi bilan
```

Til berilmasa `LANG`/locale'dan aniqlanadi (`en*`/boshqa → en; `uz*`/`C`/bo'sh → uz).

---

## 🔄 Avtomatik yangilanish

`aidevix` **o'zini avtomatik yangilab turadi** — qo'lda hech narsa qilish shart emas.
Loyihaga yangi imkoniyat yoki agent qo'shilsa (ya'ni `main` branchга push qilinsa),
keyingi safar `aidevix` ishga tushganda:

```text
  🔄 Aidevix CLI — yangi versiya topildi, yangilanmoqda...
  Yangi o'zgarishlar:
    • feat: 3 yangi bepul agent qo'shildi
  ✓ Yangilandi! Yangi imkoniyatlar tayyor.
```

- 🔒 **Xavfsiz:** lokal o'zgarishlaringiz bo'lsa, ular ustidan yozilmaydi.
- ⏱️ **Tejamkor:** har 3 soatda bir marta tekshiriladi (sozlanadi).
- 🆕 **Yangi agentlar darrov ko'rinadi:** ro'yxat repo'dan o'qiladi, siz qo'shgan
  agentlar esa saqlanib qoladi.
- ⛔ O'chirish: `export AIDEVIX_NO_AUTOUPDATE=1`.

> ℹ️ Yuqoridagi avtomatik yangilanish **git orqali** (`curl | bash`, `install.sh`)
> o'rnatganlar uchun ishlaydi.

### 📦 npm orqali o'rnatganlar

`npm install -g aidevix` bilan o'rnatsangiz paket `node_modules` ichida bo'ladi
(`.git` yo'q), shuning uchun u **o'zini git orqali yangilamaydi**. Buning o'rniga
`aidevix` npm registry'dan eng so'nggi versiyani jim tekshiradi va yangisi chiqsa
**har ishga tushganda** eslatma ko'rsatadi (yangilaguningizcha):

```text
🔄 Aidevix yangi versiya bor (1.5.1 → 1.6.0)
   Yangilash uchun terminalga yozing:
       npm i -g aidevix@latest
   Eslatmani o'chirish: AIDEVIX_NO_AUTOUPDATE=1
```

- 📡 **Fonda:** tekshiruv ishga tushishni sekinlashtirmaydi (throttled, std 3 soat).
- 🔁 **Eslatib turadi:** npm o'zini avtomatik yangilamagani uchun, yangi versiya bo'lsa har safar eslatadi.
- 🙅 **Avtomatik o'rnatmaydi:** yangilashni siz `npm i -g aidevix@latest` bilan o'zingiz qilasiz.
- ⛔ O'chirish: `export AIDEVIX_NO_AUTOUPDATE=1` (`CI=1` bo'lsa ham o'chiq).

### 🆕 Agentlarning o'zini eng so'nggi versiyada saqlash

Yuqoridagilar `aidevix`ning **o'zini** yangilaydi. Bundan tashqari, `aidevix`
tanlangan **agentni** (Gemini, Claude Code, Codex, ...) ishga tushirishdan oldin,
vaqti-vaqti bilan eng so'nggi versiyaga yangilab qo'yadi:

- ⏱️ **Throttled:** har agent uchun 3 soatda bir marta (sozlash: `AIDEVIX_UPDATE_INTERVAL`).
- 🎯 **Nega kerak:** eski o'rnatilgan agentlar buzilishi mumkin — masalan eski Gemini CLI
  *"This client is no longer supported"* deydi. Avtomatik yangilash buni hal qiladi.
- 📦 **Faqat yangilana oladiganlar:** `@latest` / `--upgrade` / `curl`-skript orqali
  o'rnatiladigan agentlar (brew/cargo o'tkazib yuboriladi).
- 🚦 **Bloklamaydi:** yangilash xato bersa ham agent baribir ishga tushadi.
- ⛔ O'chirish: `export AIDEVIX_NO_AUTOUPDATE=1` (`CI=1` bo'lsa ham o'chiq).

> 💡 Sertifikat/sana xatosi (masalan *"certificate is not yet valid"*) chiqsa,
> `aidevix` buni internet emas — **kompyuter soati noto'g'ri** ekanini tushuntiradi.

---

## 🗑️ O'chirish (Uninstall)

```bash
bash ~/.ai-cli/uninstall.sh
```

Bu `.bashrc`/`.zshrc` blokini (zaxira olib) olib tashlaydi va `aidevix`
buyrug'ini o'chiradi. Konfiguratsiyani esa xohlasangiz qo'lda o'chirasiz:

```bash
rm -rf ~/.config/ai-cli ~/.ai-cli
```

---

## 📂 Loyiha tuzilmasi

```text
aidevix-cli/
├── README.md             # Ushbu hujjat
├── TROUBLESHOOTING.md    # Muammolar va sodda yechimlar
├── CHANGELOG.md          # O'zgarishlar tarixi (SemVer)
├── CONTRIBUTING.md       # Hissa qo'shish qo'llanmasi
├── CODE_OF_CONDUCT.md    # Xulq-atvor kodeksi
├── SECURITY.md           # Xavfsizlik siyosati va zaiflik xabari
├── CLAUDE.md             # Loyiha xaritasi (AI yordamchilar uchun konteks)
├── README.en.md          # English README
├── Makefile              # make test / lint / syntax / check
├── package.json          # npm paketi (aidevix)
├── VERSION               # Joriy versiya (masalan 1.0.0)
├── LICENSE               # MIT
├── bootstrap.sh          # Bir buyruq bilan o'rnatuvchi (curl | bash)
├── install.sh            # Asosiy o'rnatuvchi (zaxira + symlink + completion)
├── uninstall.sh          # Toza o'chiruvchi
├── .editorconfig         # Izchil kod uslubi
├── .github/              # CI, release, issue/PR shablonlari
│   ├── workflows/        #   ci.yml (shellcheck · bash -n · bats) · release.yml
│   ├── ISSUE_TEMPLATE/   #   bug / feature shablonlari
│   ├── dependabot.yml    #   Actions versiyalarini avtomatik yangilash
│   ├── CODEOWNERS
│   └── PULL_REQUEST_TEMPLATE.md
├── tests/                # Bats testlari (unit + CLI + common)
│   ├── *.bats            #   unit_parse · cli · common
│   ├── test_helper.bash  #   umumiy setup
│   └── fixtures/         #   test agents.conf
├── scripts/              # demo.sh + record-demo.sh (asciinema → GIF)
├── packaging/            # Paket menejer manifestlari
│   ├── homebrew/aidevix.rb
│   └── scoop/aidevix.json
├── man/
│   └── aidevix.1         # man sahifa (man aidevix)
├── assets/
│   ├── log.jpg           # Aidevix "AD" logosi
│   └── demo.svg          # README demo posteri
├── bin/
│   ├── ai-selector.sh    # `aidevix` buyrug'i — menyu + avtomatik o'rnatish
│   ├── cli.js            # npm uchun Node launcher (bash'ni topib chaqiradi)
│   ├── aidevix.cmd       # Windows (cmd.exe) wrapper
│   └── aidevix.ps1       # Windows (PowerShell) wrapper
├── lib/
│   └── common.sh         # Umumiy funksiyalar (log, rang, xato boshqaruvi)
├── completions/
│   ├── aidevix.bash      # bash/zsh (bashcompinit) avtomatik to'ldirish
│   ├── _aidevix          # zsh native completion
│   └── aidevix.fish      # fish completion
└── config/
    └── agents.conf       # Agentlar ro'yxati (28 ta top AI CLI)
```

---

## 🤝 Hissa qo'shish

PR'lar mamnuniyat bilan! To'liq qo'llanma: [**CONTRIBUTING.md**](./CONTRIBUTING.md).

Qisqacha: Fork → branch → commit ([Conventional Commits](https://www.conventionalcommits.org/))
→ Pull Request. Yangi AI CLI qo'shish eng oson hissa — `config/agents.conf` oxiriga
bitta qator. Shell skriptlarini [shellcheck](https://www.shellcheck.net/) bilan
tekshirib yuborganingiz — alohida rahmat (CI buni avtomatik tekshiradi). 🙏

Loyihada qatnashuvchilar [Xulq-atvor kodeksi](./CODE_OF_CONDUCT.md)ga amal qiladi.

### 🧪 Testlar

```bash
make test     # yoki: bats tests/
make check    # syntax + lint + test (CI bilan bir xil)
```

Tafsilot: [`tests/README.md`](./tests/README.md). Har push/PR'da CI avtomatik ishlatadi.

---

## 🔐 Xavfsizlik

Aidevix uchinchi-tomon o'rnatuvchilarini (`npm`, `pip`, `curl | bash`) **ruxsatingiz
bilan** ishga tushiradi va API kalitlaringizni **ko'rmaydi/saqlamaydi**. To'liq
xavfsizlik modeli va zaiflik haqida xabar berish: [**SECURITY.md**](./SECURITY.md).

---

## 📜 Litsenziya

[MIT](./LICENSE) — erkin foydalaning, o'zgartiring, tarqating.

<div align="center">

**⭐ Foydali bo'lsa, repozitoriyaga yulduzcha qo'ying!**

</div>
