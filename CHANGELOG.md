# O'zgarishlar tarixi (Changelog)

Barcha muhim o'zgarishlar shu faylda hujjatlanadi.

Format [Keep a Changelog](https://keepachangelog.com/uz/1.1.0/) asosida,
loyiha [Semantik versiyalash](https://semver.org/lang/uz/) (SemVer)ga amal qiladi.

## [Nashr qilinmagan]

## [1.9.1] — 2026-07-29

### O'zgardi
- **Katta "AIDEVIX" logotipi endi HAR ishga tushishda chiziladi.** Ilgari to'liq
  brend bloki faqat ILK run'da ko'rinardi (`~/.local/state/ai-cli/seen_banner`
  marker'i), keyingi safarlar ixcham bir qatorli sarlavha bilan ochilardi —
  natijada logotip "yo'qolgandek" tuyulardi. Marker fayl saqlanib qoldi (ilk
  run faktini yozadi), lekin logo ko'rsatishga endi ta'sir qilmaydi.
  Ixcham sarlavhaga qaytish: `BANNER_FULL=0`.

## [1.9.0] — 2026-07-28

### Qo'shildi
- **Logotip endi TO'LIQ "AIDEVIX" so'zi** (ilgari "AD" monogrammasi edi).
  52 ustundan tor terminalda monogrammaga qaytadi — to'liq so'z 49 ustun
  egallaydi va tor oynada o'ralib, maketni buzardi.
- **Banner animatsiyasi qaytdi** — logo qatorma-qator ochiladi va gradient
  bilan (moviy → siyoh → ko'k) chiziladi. Butun effekt ~0.35 s (Windows'da
  ~0.8 s). FAQAT jonli 256-rangli terminalda; `CI`, `AI_NO_ANIM`, `NO_COLOR`,
  quvur va 16-rangli terminalda logo AVVALGIDEK bir zumda chiqadi.
  Yangi: `ui_gradient_line`, `ui_anim_wait` (lib/ui.sh), `hide_cursor`.
- **Menyu tartibi: O'RNATILGAN agentlar endi TEPADA.** Saralash kalitlari:
  oxirgi ishlatilgan → o'rnatilgan → lokal sanoq → top → config tartibi.
  Foydalanuvchi darhol ishlata oladigan agentni ro'yxatdan qidirmaydi.

### Tuzatildi
- **Ikki ustunli menyu va status bar ko'pchilikka UMUMAN ko'rinmasdi.** `run_menu`
  fzf o'rnatilgan bo'lsa darrov fzf'ni tanlardi, redizaynning butun maketi esa
  (ikki ustun · status bar · klavish footer'i) faqat ichki `select_with_arrows`
  da bor edi. Windows'da fzf preview ham standart o'chiq — natijada fzf'li
  foydalanuvchi TEKIS RO'YXAT ko'rardi. Endi standart — ichki menyu;
  fzf'ni afzal ko'rganlar uchun `AIDEVIX_USE_FZF=1`. Ichki menyu ochilmasa
  fzf'ga, u ham bo'lmasa raqamli menyuga zaxira yo'l bor.
- Raqamli menyudagi "fzf topilmadi" xabari yanglish edi (u endi fzf yo'qligidan
  emas, TERMINAL yo'qligidan chiqadi) — matn aniqlashtirildi.

## [1.8.0] — 2026-07-27

Butun interfeys qayta ishlangan: endi u **yagona dizayn tizimidan** chiziladi.

### Qo'shildi
- **🎨 `lib/ui.sh` — dizayn tizimi.** Butun interfeysning yagona manbai:
  - **Ikonkalar uch pog'onada** — `nerd` · `unicode` · `ascii`. `ui_icons_detect`
    o'zi aniqlaydi (fontconfig · macOS shrift papkalari · Windows reyestri),
    natija keshlanadi. UTF-8 bo'lmagan muhitda (`LANG=C`) avtomatik `ascii`.
  - **Semantik ranglar** — `UI_OK/WARN/ERR/INFO/AI/MUTED/FAINT/TEXT/BRAND`,
    terminalga qarab 256 → 16 → rangsiz pog'onasiga tushadi. `NO_COLOR`
    hurmat qilinadi.
  - **Maket yordamchilari** — `ui_vislen/pad/trunc` (ANSI'ni hisobga oladi),
    `ui_rule`, `ui_kv`, `ui_badge`, `ui_notice`, `ui_header`, `ui_footer`,
    `ui_statusbar`, `ui_bar`. Har birining fork'siz `_v` varianti bor.
- **📐 Ikki ustunli menyu.** Chapda qidiriladigan ro'yxat, o'ngda tanlangan
  agent tafsiloti, pastda status bar va klavish footer'i. **fzf preview ham
  AYNAN shu `detail_lines()` dan chiziladi** — ikkala interfeys bir xil
  ko'rinadi (ilgari ular ikki alohida maket edi va bir-biridan uzoqlashgandi).
- **📱 Ustma-ust (stacked) zaxira maket** — terminal 84 ustundan tor bo'lsa
  avtomatik yoqiladi.
- **📊 Status bar** — provayder, model va API-kalit holati (muhit
  o'zgaruvchilaridan), o'rnatilgan/jami, versiya va tarmoq latency'si.
  **Kontekst/token sarfi ATAYLAB yo'q:** Aidevix LLM API'ga murojaat qilmaydi,
  ya'ni uni o'lchay olmaydi — to'qib chiqarilgan raqamdan ko'ra yo'qligi to'g'ri.
- **`aidevix --icons [nerd|unicode|ascii|auto]`** (qisqasi `-i`) — ikonka
  uslubini ko'rsatadi yoki majburlaydi; `auto` keshni tashlab qayta aniqlaydi.
  Tanlov saqlanadi. Muhit o'zgaruvchisi: **`AIDEVIX_ICONS`** (undan ustun).
- **Test seam `AIDEVIX_UI_DUMP=1`** — menyuning BITTA kadrini stdout'ga chizadi,
  TTY talab qilmaydi. Maket testlari shu orqali yoziladi
  (`AIDEVIX_UI_DUMP_QUERY` bilan qidiruv holati ham).
- 40 ga yaqin yangi test: `tests/ui_design.bats` va `tests/ui_layout.bats`.

### O'zgardi
- **Emoji interfeysdan CHIQARILDI, ma'nosi esa saqlandi.** Config va tarjima
  kalitlarida emoji ATAYLAB qoladi (foydalanuvchi configlari bilan moslik
  uchun), lekin ekranga chiqmaydi: `classify_auth_v` 🆓/🌐/🔑/💳 ni
  `free|browser|key|paid|none` sinfiga, `detect_provider_v` esa provayderga
  aylantiradi; `ui_deemoji_v` matndan belgini oladi. Ma'no endi ikonka
  pog'onasi orqali beriladi.
- **`build_rows` STATUS ustuni — mashina o'qiydigan token** (`installed` /
  `missing`). Ilgari u `"✓ o'rnatilgan"` edi: belgi, rang va tarjima bitta
  satrda aralashib, ustun tekislashini buzardi. Belgiga aylantirish endi
  faqat chizish paytida bo'ladi. `parse_agents` 10, `build_rows` 11 maydon.
- fzf menyusi ichki menyu bilan **bir xil semantik palitradan** foydalanadi
  (ilgari feruza/pushti gradient bor edi — bitta mahsulot ikki xil tuyulardi).
- `lib/common.sh` dagi `panel()` endi `ui_notice()` ustidagi yupqa qobiq.

### Tuzatildi
- **Testlar YIQILGANDA ham "ok" deb ko'rsatilardi.** `tests/test_helper.bash`
  dagi `load_selector`/`load_common` bats'ning ERR/EXIT tutqichlarini
  `trap -` bilan olib tashlardi — bats yiqilishni umuman ko'rmay qolardi va
  butun to'plam SOXTA YASHIL edi. Endi tutqichlar source'dan oldin saqlanib,
  keyin qayta tiklanadi (`_save_bats_traps`/`_restore_bats_traps`).
- **Tor terminalda footer o'ralib ketardi.** `ui_footer_str_v` endi status bar
  kabi sig'magan juftlarni tashlaydi (`ui_width` 40 ustunda pol qo'yadi, footer
  esa o'sha yerda 44 belgi bo'lardi).
- **Past terminalda yolg'iz bo'lim sarlavhasi qolardi** — "o'rnatish" sarlavhasi
  ko'rinib, buyrug'ining o'zi kesilib ketardi. `detail_clip` uni olib tashlaydi.
- **Emoji olib tashlangan izohlarda ortiqcha bo'shliq qolardi** (`│  Anthropic…`
  ikki bo'shliq bilan). `parse_agents` endi de-emoji'dan keyin `trim_v` qiladi.
- macOS'da Nerd Font aniqlash `ls | grep` orqali edi (ikki fork + g'alati
  nomli fayllarda yanglishish) — endi sof glob.

### Ishlab chiqish
- `make lint` va `make syntax` endi `lib/ui.sh`, `lib/i18n.sh`, `lib/i18n/en.sh`
  ni ham tekshiradi (ilgari yangi dizayn tizimi umuman lint qilinmasdi). CI ham.

## [1.7.4] — 2026-07-26

### Tuzatildi
- **Ctrl+C (SIGINT) endi toza to'xtatadi** — terminal buzuq holatda qolmaydi
  (alt-screen, kursor va termios tiklanadi).

## [1.7.3] — 2026-07-25

### Tuzatildi
- npm orqali agent o'rnatishda menyu qotib qolib, jim yopilishi tuzatildi.

## [1.7.2] — 2026-07-14

### Tuzatildi
- Menyu scroll'i va qayta-o'rnatish (reinstall) aylanasi tuzatildi:
  `locate_binary` PATH'da ko'rinmagan binarni ma'lum joylardan topadi va
  keshlaydi.
- Strelka bosilganda "Bekor qilindi" chiqishi — o'lik konsollar uchun
  timeout'larning uchinchi qatlami qo'shildi.

## [1.7.1] — 2026-06-22

### Tuzatildi
- `--list` HOLAT ustuni emoji bo'lganda ham tekis tekislanadi.
- Windows'da strelkalar bilan navigatsiya menyuni yopib qo'ymaydi.

## [1.7.0] — 2026-06-21

### Qo'shildi
- Kutilmagan xatoda **KATTA yangilash eslatmasi** (`crash`) — crashlarning
  aksariyati eski versiyada bo'lgani uchun xatodan keyin yangilash buyrug'i
  ko'zga tashlanadigan panelda ko'rsatiladi.
- npm o'rnatishlari uchun **interaktiv auto-update** — yangi versiya bo'lsa
  so'raydi va tasdiqlansa o'zini yangilab qayta ishga tushadi.

## [1.6.0] — 2026-06-19

### Qo'shildi
- **O'rnatilgan agentlarni avtomatik yangilash** (`maybe_autoupdate_agent`) —
  ishga tushirishdan oldin, throttled (std 3 soat). Eski Gemini CLI
  "client no longer supported" muammosini hal qiladi.
- O'rnatish xatosida **sertifikat/tizim soati** muammosini aniq tushuntirish.

## [1.5.1] — 2026-06-18

### Tuzatildi
- fzf'siz ↑/↓ menyuda ERR-trap crash'i.

## [1.5.0] — 2026-06-16

### Qo'shildi
- **fzf'siz ichki ↑/↓ ko'rsatkichli menyu** (built-in TUI) — alt-screen va
  alternate-scroll bilan; sichqoncha g'ildiragi ham ishlaydi.
- `--top` reyting va menyuda to'liq agent tafsiloti.

## [1.4.1] — 2026-06-16

### O'zgardi
- **🔁 npm yangilanish eslatmasi agressivroq** — npm paketlari o'zini avtomatik
  yangilamagani uchun (ko'pchilik npm orqali o'rnatadi), yangi versiya bo'lsa
  eslatma endi **har ishga tushganda** ko'rsatiladi (ilgari versiya uchun bir
  marta edi) — foydalanuvchi yangilaguncha. Buyruq ishonchliroq `npm i -g
  aidevix@latest` ga o'zgartirildi. O'chirish: `AIDEVIX_NO_AUTOUPDATE=1`.

## [1.4.0] — 2026-06-16

### Qo'shildi
- **🌐 Ilk ishga tushishda til tanlash** — `aidevix` birinchi marta ishga tushganda
  ikki tilda "English / Oʻzbekcha" so'raydi; tanlov saqlanadi (`~/.local/state/ai-cli/lang`)
  va keyingi safar so'ralmaydi. `aidevix --lang [en|uz]` bilan istalgan vaqtda
  o'zgartirish/qayta tanlash mumkin. `choose_language`, `lang_cmd`, `load_saved_lang`,
  `aidevix_set_lang`.
- **🈯 To'liq bir tilli interfeys** — agent **izohlari (desc)** va **login izohlari
  (auth)** ham tanlangan tilga tarjima qilinadi (`parse_agents`'da `t()`), shu tufayli
  menyu/preview/`--list` endi aralash emas, to'liq inglizcha yoki o'zbekcha chiqadi.
  EN katalogga 28 agent izohi + 23 auth qatori qo'shildi.
- **⏳ Ishga tushirish loaderi** — menyu tayyorlanayotganda (agentlar tekshiruvi +
  menyu qurish) fonda aylanuvchi yuklash ko'rsatkichi chiqadi, terminal "muzlab
  qolgandek" tuyulmaydi. `ui_spin_start`/`ui_spin_stop` (`lib/common.sh`).
- **ℹ️ "Aidevix nima — va nima EMAS" tanishtiruvi** — ilk ishga tushishda BIR MARTA:
  Aidevix faqat launcher (uchinchi-tomon CLI'larni o'rnatib/ochib beradi), savollarga
  javob bermaydi va token/kalit bermaydi; ba'zi CLI'lar pullik, ba'zilari bepul.
  `--help` va README'da ham aniq eslatma.
- **📦 npm `postinstall` yo'riqnomasi** — `npm i -g aidevix` dan keyin ikki tilli
  qisqa xabar chiqadi: "ishga tushirish uchun `aidevix` deb yozing" (`bin/postinstall.js`).

### Tuzatildi
- **Windows fzf fork xatosi** — fzf preview har siljishda `bash` qism-jarayonini
  ochib, Git Bash/MSYS'da `cygheap`/`child_copy` (Win32 error 299) xatolarini
  keltirardi. Endi Windows'da preview standart **o'chiq** (`AIDEVIX_FZF_PREVIEW=1`
  bilan yoqiladi); menyu toza ko'rinadi.

## [1.3.0] — 2026-06-16

### Qo'shildi
- **🌐 Ko'p tillilik (i18n) — inglizcha interfeys** — endi Aidevix o'zbekcha
  (standart) va inglizcha ishlaydi. Til `LANG`/locale'dan avtomatik aniqlanadi
  (`en*`/boshqa → en; `uz*`/`C`/bo'sh → uz) yoki `AIDEVIX_LANG=en|uz` bilan
  majburlanadi. Yengil gettext qatlami: `lib/i18n.sh` (`aidevix_detect_lang`,
  `t()`) + `lib/i18n/en.sh` katalog (o'zbekcha manba = kalit; tarjima topilmasa
  o'zbekchaga qaytadi — hech narsa buzilmaydi). Butun CLI interfeysi (yordam,
  menyu, doctor, stats, o'rnatish/xato xabarlari, auth eslatmalari) tarjima
  qilingan. Testlar: `tests/i18n.bats` (15). Agent izohlari (`agents.conf`)
  hozircha o'zbekcha.

## [1.2.0] — 2026-06-15

### Qo'shildi
<!-- ── 2026-06-15 sessiyasi ─────────────────────────────────────────── -->
- **🎬 3D ishga tushirish loaderi** — agent ishga tushirilishidan oldin "AD"
  monogrammasi gradient "sweep" (yorug'lik harakati, 3D his) va to'lib boruvchi
  bar bilan animatsiya qiladi (`loader_3d`). TTY yo'q / `CI` / `NO_COLOR` /
  `AI_NO_ANIM` da — oddiy bir qatorli matn. O'rnatish allaqachon `spin_run` bilan
  animatsiyali edi.
- **📊 Lokal ishlatish statistikasi** — har agent necha marta ishga tushirilgani
  `~/.local/state/ai-cli/usage` da saqlanadi (`record_usage`/`read_usage`). Menyu
  va `--list` eng ko'p ishlatilgan bo'yicha tartiblanadi; har agent yonida `· N×`.
  `--list` ga "MARTA" ustuni. Faqat shu kompyuterda — hech qayoqqa yuborilmaydi.
  Testlar: `tests/usage.bats` (7).
- **🌍 Global statistika (OPT-IN, standart o'CHIQ)** — `aidevix --stats [on|off]`.
  Yoqilganda menyuda `🔥 #reyting · son` ko'rinadi va agent ishga tushganda FAQAT
  agent nomi + hodisa turi (`install`/`launch`) serverga yuboriladi (IP/ID/kalit
  YO'Q). `report_usage_global` (fonda, jim, bloklamaydi), `fetch_global_stats`
  (keshli, throttled), `global_install_tsv`, `maybe_global_hint`, `doctor`da holat.
  Testlar: `tests/global_stats.bats` (9). Klyent↔server e2e jonli tasdiqlandi.
- **🛰️ Global statistika backend (`server/`)** — Fastify 5 + ioredis +
  `@fastify/rate-limit`; Redis sorted-set (`ZINCRBY`/`ZREVRANGE`) bilan atomik
  sanoq va reyting. Endpoint'lar: `POST /v1/events`, `GET /v1/stats`, `GET /health`.
  Dockerfile (non-root, healthcheck) + `railway.json`. Railway'ga deploy qilingan
  (`https://sunnatbeecli-production.up.railway.app`). CI: `.github/workflows/server-ci.yml`.
  Testlar: `node --test` (6, ioredis-mock).
- **🤖 5 yangi agent** — Freebuff, Codebuff, gptme, Shell GPT (sgpt), Mods
  (jami 23 → 28). `--top` ro'yxatiga Codebuff va Freebuff qo'shildi.
- **⌨️ `--stats` completion** (bash/zsh/fish) + man sahifa yozuvi + `SECURITY.md`
  da OPT-IN telemetriya bo'limi (nima yuboriladi/yuborilmaydi).
- **📦 npm yangilanish eslatmasi (notify)** — `npm install -g aidevix` bilan
  o'rnatilganlarda (`.git` yo'q) git auto-update ishlamaydi. Endi `aidevix` npm
  registry'dan eng so'nggi versiyani fonda tekshiradi va yangisi chiqsa
  `npm update -g aidevix` ni har versiya uchun BIR MARTA eslatadi
  (`is_npm_install`, `version_gt`, `fetch_npm_latest`, `maybe_npm_update_hint`).
  Throttled, `AIDEVIX_NO_AUTOUPDATE`/`CI` hurmat qilinadi. Testlar:
  `tests/npm_update.bats` (13).
<!-- ── oldingi sessiyalar ───────────────────────────────────────────── -->
- **🧪 Test to'plami (Bats)** — `tests/` ostida 38 ta avtomatlashtirilgan test:
  config parsing (`parse_agents`, `build_rows`, `trim`, `detect_install_tool`),
  CLI xulq-atvori (`--version`/`--help`/`--list`, noto'g'ri argumentlar,
  `quick_launch` resolutsiyasi) va `lib/common.sh` yordamchilari. CI har push/PR'da
  ishga tushiradi. Lokal: `bats tests/` yoki `make check`.
- **`Makefile`** — `make test` / `lint` / `syntax` / `check` qulayliklari.
- **`SECURITY.md`** — xavfsizlik siyosati, ishonch chegaralari (uchinchi-tomon
  o'rnatuvchilar, `curl | bash`, auto-update) va zaiflik xabari yo'riqnomasi.
- **`CLAUDE.md`** — loyiha xaritasi (fayl/funksiya/konventsiya) — AI yordamchilari
  kodni qaytadan o'qimasdan kontekstni tez tiklashi uchun.
- **🌍 Inglizcha hujjat (`README.en.md`)** + ikkala README tepasida til
  almashtirgich (🇺🇿 / 🇬🇧) — xalqaro auditoriya uchun.
- **📦 Paket menejer manifestlari** — npm (`package.json` + `bin/cli.js`
  cross-platform Node launcher), Homebrew formula (`packaging/homebrew/aidevix.rb`),
  Scoop manifest (`packaging/scoop/aidevix.json`). Endi `npm i -g aidevix`,
  `brew install ...`, `scoop install aidevix` mumkin.
- **⌨️ zsh + fish completion** — `completions/_aidevix` (zsh native) va
  `completions/aidevix.fish`; `completions/README.md` qo'llanmasi.
- **🖥️ man sahifa** — `man/aidevix.1` (`man aidevix`).
- **🧹 Repo gigiyenasi** — `.editorconfig`, `.github/dependabot.yml`
  (Actions versiyalari), `.github/CODEOWNERS`.
- **🎬 Demo** — `assets/demo.svg` (README posteri) + `scripts/demo.sh`
  (deterministik, non-interaktiv demo) va `scripts/record-demo.sh`
  (asciinema → agg → `assets/demo.gif`).
- **Qo'shimcha README badge'lari** — platform, PRs welcome, Conventional Commits,
  GitHub stars (UZ va EN).

### O'zgardi
<!-- ── 2026-06-15 sessiyasi ─────────────────────────────────────────── -->
- **Menyu tartibi** — "oxirgi tanlov tepada" o'rniga "**eng ko'p ishlatilgan
  tepada**" (lokal statistika bo'yicha; teng bo'lsa config tartibi saqlanadi).
- README'da agent soni **23 → 28**; "oxirgi tanlovni eslaydi" xususiyat qatori
  "**lokal statistika**" bilan almashtirildi (uz/en).
- `usage()` config formati hujjati 8-maydonli (`...|AUTH|URL`) qilib to'g'rilandi.
<!-- ── oldingi sessiyalar ───────────────────────────────────────────── -->
- `bin/ai-selector.sh` oxiriga `source`-qorovuli qo'shildi (`BASH_SOURCE` ==
  `$0`) — endi skriptni testda `source` qilganda `main()` ishga tushmaydi;
  xulq-atvor o'zgarmaydi.

### Tuzatildi
<!-- ── 2026-06-15 sessiyasi ─────────────────────────────────────────── -->
- **Tab-completion** endi repo config'dan ham agent nomlarini taklif qiladi.
  Ilgari faqat (o'rnatuvchi bo'sh yaratadigan) foydalanuvchi config'ni o'qib,
  `aidevix <TAB>` hech qanday agent ko'rsatmasdi. Testlar: `tests/completion.bats` (5).
- **server:** Railway private Redis FAQAT IPv6 (AAAA) bergani uchun ioredis
  standart `family:4` bilan ulana olmasdi → `family:0` (dual-stack) qo'shildi.
- **server:** redis `error` hodisasi ishlovchisi qo'shildi (ilgari ulanish
  bo'roni `[ioredis] Unhandled error event` log'ni to'ldirardi) — endi throttled.
- `--stats` status matnidagi kirill harf xatosi (`yoqilганда` → `yoqilganda`).

## [1.1.0] — 2026-06-14

### Qo'shildi
- **🔄 Avtomatik yangilanish** — `main`ga push qilingan o'zgarishlar
  foydalanuvchilarga avtomatik yetadi: `aidevix` ishga tushganda (throttled,
  3 soat) remote'ni tekshiradi, yangi commit bo'lsa jim yuklab oladi, "nima
  yangilangani"ni ko'rsatadi va yangi versiyani qayta ishga tushiradi. Lokal
  o'zgarishlar bo'lsa clobbering qilinmaydi. O'chirish: `AIDEVIX_NO_AUTOUPDATE=1`.
- **Konfiguratsiya birlashtirildi** — agentlar repo'dan (`config/agents.conf`)
  o'qiladi (doimo yangi), foydalanuvchi configi faqat o'zi qo'shgan agentlarni
  saqlaydi. Shu tufayli yangi agentlar/tuzatishlar mavjud foydalanuvchilarga ham
  darrov ko'rinadi (avval foydalanuvchi nusxasi eski qolib ketardi).
- **8 ta yangi agent** (jami 23 ta): Open Interpreter, OpenHands, SWE-agent,
  Cline CLI, Kilo CLI, Grok Build, Antigravity, GitHub CLI.
  Ochiq manbali / bepullar `🆓 bepul` statusi bilan belgilandi va
  `aidevix --free`da chiqadi (endi 11+ bepul agent).

### Tuzatildi
- **Windows curl/git `CRYPT_E_NO_REVOCATION_CHECK` (schannel)** — ichki yuklab
  olishlar `curl --ssl-no-revoke`, git esa `-c http.schannelCheckRevoke=false`
  bilan ishlaydi. Boshlang'ich buyruq uchun README/TROUBLESHOOTING'da yechim.

### Tuzatildi (paket nomlari rasmiy manbalardan tekshirildi)
- Cline CLI: `cline-cli` → **`cline`** (npm).
- Kilo CLI: `kilo-cli` → **`@kilocode/cli`** (npm).
- SWE-agent: `swe-agent` → **`sweagent`** (PyPI).
- Grok Build: `npm grok-build` → rasmiy **xAI installer** (`x.ai/cli/install.sh`,
  buyruq `grok`, SuperGrok/X Premium obunasi).
- Roo Code CLI **olib tashlandi** — rasmiy terminal CLI'si yo'q (faqat VS Code
  kengaytmasi).

### O'zgartirildi
- **CLI o'rnatish animatsiyasi yangilandi** — endi o'rnatish davomida chiroyli,
  gradientli "komet" progress-bar (chap-o'ngга sakraydigan, izli) + spinner va
  o'tgan vaqt ko'rinadi; tugagach to'liq yashil/qizil bar.

## [1.0.0] — 2026-06-14

Birinchi barqaror (production) nashr. 🎉

### Qo'shildi
- **Saralangan 15 ta top AI CLI agenti** — Claude Code, OpenAI Codex, Gemini CLI,
  GitHub Copilot, OpenCode, Crush, Qwen Code, Continue, Cursor Agent, Plandex,
  Aider, Goose, Ollama, llm, AIChat — barchasi `@latest` versiya bilan.
- **Login/auth belgisi** — har bir agent uchun qaysi login yoki API kalit
  kerakligi (🔑/🌐/💳/🆓) menyu preview'sida, `--list`da va menyu qatorida.
- **Login havolasi** — har agentга login/kalit sahifasi linki. Brauzer **faqat
  zarur bo'lganda** ochiladi: agent o'zingiz API kalit (🔑) olishingizni talab
  qilsa va kalit hali muhitda yo'q bo'lsa. Brauzer-login (🌐), obuna (💳), bepul
  (🆓) yoki kalit allaqachon bor bo'lsa — brauzer ochilmaydi, faqat qisqa
  eslatma. (Bir martalik; kalitlar saqlanmaydi.)
- **`aidevix --free`** — faqat bepul agentlar menyusi (Gemini, Qwen, Ollama,
  Continue). **`aidevix --top`** — faqat eng mashhur agentlar.
- **`aidevix --version`** — versiyani ko'rsatadi (`VERSION` faylidan o'qiladi).
- **O'rnatishdan keyin katta, aniq yo'riqnoma** — `source ~/.bashrc && aidevix`
  bilan o'sha oynaning o'zida ishlatish yoki Git Bash'ni qayta ochish.
- **fzf avtomatik o'rnatish** — o'rnatishda fzf GitHub releases'dan yuklab
  olinadi (sudo kerak emas), bo'lmasa paket-menejer.
- **AD logosi + animatsiyali banner** — "Aidevix CLI" brendi.
- **CI (ShellCheck), CHANGELOG, CONTRIBUTING, issue/PR shablonlari va
  release avtomatlashtirish** — open-source standartlari.

### O'zgartirildi
- Buyruq nomi `ai` → **`aidevix`**.
- Brend `AI CLI Pult` → **Aidevix CLI**.

### Tuzatildi
- **Windows/Git Bash'da npm CLI'lar ishga tushmasligi** — PATH'ga Windows-shakl
  (`C:\Users\...`) yo'l tushib, `:` ajratgich uni buzardi va "Cannot find module
  C:\Program Files\Git\Users\..." xatosini berardi. Endi yo'llar POSIX shaklga
  o'tkaziladi va PATH har ishga tushganda tozalanadi (o'z-o'zini davolash).
- **Qo'llab-quvvatlanmaydigan OS** (masalan Cursor Windows'da) — adashtiruvchi
  "internet/sudo" o'rniga halol, aniq xabar ko'rsatiladi.

[Nashr qilinmagan]: https://github.com/SUNNATBEE/sunnatbeeCLI/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/SUNNATBEE/sunnatbeeCLI/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/SUNNATBEE/sunnatbeeCLI/releases/tag/v1.0.0
