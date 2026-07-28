# CLAUDE.md — Aidevix CLI

> Bu fayl Claude Code uchun loyiha xaritasi. Maqsad: kodni qaytadan o'qimasdan
> kontekstni tez tiklash. Yangi sessiyada AVVAL shuni o'qing.

## Loyiha nima qiladi
Aidevix — **terminaldagi AI CLI agentlarini (Claude Code, Codex, Gemini, Aider, ...)
bitta menyudan boshqaradigan launcher**. `config/agents.conf` dan agentlar ro'yxatini
o'qiydi, `fzf` (yoki raqamli) menyu ko'rsatadi, tanlangan agentni ishga tushiradi;
o'rnatilmagan bo'lsa — ruxsat so'rab o'rnatadi. Sof **Bash** loyihasi (build yo'q).

- Til: manba matnlar **o'zbekcha** (standart). **i18n** orqali inglizcha ham qo'llab-quvvatlanadi (`AIDEVIX_LANG=en` yoki `LANG`). Qarang `lib/i18n.sh`.
- Platformalar: Linux, macOS, Windows (Git Bash / MINGW64).
- Buyruq nomi: `aidevix`.

## Fayl xaritasi
| Yo'l | Vazifa |
|------|--------|
| `bin/ai-selector.sh` | **Asosiy skript** (~2850 qator). Barcha mantiq shu yerda: menyu, parsing, o'rnatish, doctor, auto-update. |
| `lib/ui.sh` | **Dizayn tizimi** — butun interfeysning yagona manbai. (1) IKONKALAR: uch pog'ona `nerd`/`unicode`/`ascii`, `ui_icons_detect` avtomatik aniqlaydi (fontconfig · macOS shrift papkasi · Windows reyestri), natija keshlanadi; (2) SEMANTIK RANGLAR: `UI_OK/WARN/ERR/INFO/AI/MUTED/FAINT/TEXT/BRAND` (256 → 16 → rangsiz); (3) LAYOUT: `ui_vislen/ui_pad/ui_trunc` (ANSI'ni hisobga oladi), `ui_rule`, `ui_kv`, `ui_badge`, `ui_notice`, `ui_header`, `ui_footer`, `ui_statusbar`, `ui_bar`, `ui_deemoji_v`. **Har birining `_v` (fork'siz) varianti bor** — tsiklda `$(...)` ISHLATMA. `UI_FD` chiqish oqimini boshqaradi (2 std, `--list`/`--doctor` uchun 1). |
| `lib/common.sh` | Umumiy yordamchilar: `log_*` (+`log_step`), `die`, `require_cmd`, `panel` (→`ui_notice` qobig'i), `banner`/`banner_full`, `spin_run`, `ui_launch`, `tool_hint`, `open_url`. STDERR'ga yozadi. `lib/i18n.sh` va `lib/ui.sh` ni `source` qiladi. |
| `lib/i18n.sh` | **Ko'p tillilik (i18n)** — `aidevix_detect_lang` (AIDEVIX_LANG > LANG/LC_* > uz), `t()` gettext-uslubidagi lookup. Manba o'zbekcha = kalit; tarjima topilmasa o'zbekchaga qaytadi. |
| `lib/i18n/en.sh` | Inglizcha tarjima katalogi (`MSG_EN["uz manba"]="en"`). Faqat "en" rejimida yuklanadi. Yangi `t "..."` qo'shsang — kalitni shu yerga ham qo'sh. |
| `config/agents.conf` | Agentlar ro'yxati. Format: `NAME\|BINARY\|COMMAND\|INSTALL\|DESC\|CATEGORY\|AUTH\|URL` (5–7 ta `\|`). |
| `bin/aidevix.cmd`, `bin/aidevix.ps1` | Windows wrapperlari — Git Bash topib `ai-selector.sh`ni chaqiradi. |
| `bin/cli.js` | npm uchun Node launcher — bash'ni topib `ai-selector.sh`ni `spawnSync` bilan ishga tushiradi (`package.json` `bin`). |
| `completions/` | `aidevix.bash` (bash/zsh), `_aidevix` (zsh native), `aidevix.fish` (fish). |
| `packaging/` | `homebrew/aidevix.rb` (formula), `scoop/aidevix.json` (manifest). Relizda `url`/`sha256`/`version` yangilanadi. |
| `man/aidevix.1` | man sahifa. |
| `scripts/` | `demo.sh` (deterministik, non-interaktiv demo) + `record-demo.sh` (asciinema→agg→`assets/demo.gif`). |
| `assets/demo.svg` | README demo posteri (statik). `log.jpg` — AD logosi. |
| `README.md` / `README.en.md` | O'zbekcha / inglizcha hujjat (til almashtirgich tepada). |
| `install.sh` | Lokal o'rnatish (symlink → `~/.local/bin`, rc zaxira, idempotent, sudosiz). |
| `bootstrap.sh` | `curl \| bash` bitta-buyruqli o'rnatuvchi (repo'ni `~/.ai-cli`ga klonlaydi). |
| `uninstall.sh` | O'chirish. |
| `tests/` | Bats testlari (`*.bats`, `test_helper.bash`, `fixtures/`). Qarang `tests/README.md`. |
| `server/` | **Global statistika backend'i** (alohida Node loyihasi, npm paketiga kirmaydi). Fastify 5 + ioredis + `@fastify/rate-limit`; Redis sorted-set'lari (`ZINCRBY`/`ZREVRANGE`). Endpoint'lar: `POST /v1/events`, `GET /v1/stats`, `GET /health`. Railway'ga Dockerfile + `railway.json` bilan deploy. Testlar: `node --test` (ioredis-mock). CI: `.github/workflows/server-ci.yml` (faqat `server/**`). Klyent (aidevix) integratsiyasi hali ulanmagan — opt-in bo'lib qo'shiladi. |
| `VERSION` | Yagona haqiqat manbai (SemVer). Release teg `vX.Y.Z` shunga mos bo'lishi shart. |
| `.github/workflows/ci.yml` | CI: shellcheck · `bash -n` · agents.conf validatsiya · bats. |
| `.github/workflows/release.yml` | Teg push'da GitHub Release. |

## `ai-selector.sh` — asosiy funksiyalar (qidiruv uchun)
- `main()` — argument dispatch (fayl oxirida). `__preview` subkomandasi, so'ng `augment_tool_path`, `auto_update`, keyin flag'lar.
- `resolve_config` / `build_merged_config` — repo + foydalanuvchi config birlashtirish (repo ustun).
- `parse_agents` — config → TAB-ajratilgan **10 maydon**; `build_rows` → **11 maydon**: `NAME DESC BINARY COMMAND INSTALL CATEGORY STATUS AUTH URL AUTHCLASS PROVIDER`. `STATUS` endi mashina o'qiydigan token — **`installed`/`missing`** (ilgari `"✓ o'rnatilgan"` edi; belgi/rang/tarjima bir satrda aralashgan va tekislashni buzardi). Belgiga aylantirish faqat chizishda.
- **Emoji → semantik maydon:** config va i18n kalitlarida emoji ATAYLAB qoladi (foydalanuvchi configlari va tarjimalar bilan moslik), lekin interfeysga CHIQMAYDI. `classify_auth_v` emoji'ni (🆓/🌐/🔑/💳) HAM, matnni ham `free|browser|key|paid|none` sinfiga aylantiradi; `detect_provider_v` provayderni aniqlaydi (vendor naqshlari umumiy `github.com` dan OLDIN tekshiriladi). `ui_deemoji_v` matndan emoji'ni oladi — `ui_notice` buni sarlavha va har qatorda avtomatik qiladi, shuning uchun 13 ta chaqiruv joyi va butun tarjima katalogi tegilmagan.
- `run_menu` (filter: `free`/`top`), `select_with_fzf`, `select_with_arrows`, `select_with_numbers`, `build_menu`, `preview_agent`. fzf xato bilan to'xtasa (eski versiya flag tanimaydi) — `select_with_fzf` rc=3 qaytaradi, `run_menu` ichki ↑/↓ menyuga fallback qiladi.
- **IKKI USTUNLI menyu (`select_with_arrows`):** chapda qidiriladigan agentlar ro'yxati, o'ngda tanlangan agent tafsiloti, pastda status bar + klavish footer'i. Tor terminalda (< 84 ustun) avtomatik ustma-ust (stacked) maketga tushadi. Tafsilot `detail_lines()` → `DETAIL[]` dan chiziladi — **fzf preview HAM aynan shundan**, ya'ni ikkala interfeys bir xil ko'rinadi. Chap ustun qatorlari (`lrow[]`) va barcha statik matnlar tsikldan OLDIN bir marta quriladi.
- **Status bar (`_as`):** faqat HAQIQIY ma'lumot — provayder (config'dan), model va API-kalit holati (MUHIT o'zgaruvchilaridan: `provider_model_var`/`provider_key_var`), o'rnatilgan/jami, versiya + yangilanish (`status_version_field`), tarmoq latency (`status_latency_field` — `curl -w %{time_total}` o'lchagan haqiqiy qiymat, `LATENCY_FILE`). **Kontekst/token sarfi ATAYLAB YO'Q**: Aidevix LLM API'ga murojaat qilmaydi, ya'ni uni o'lchay olmaydi — to'qib chiqarilgan raqam ko'rsatgandan ko'ra ko'rsatmagan to'g'ri. Testi bor (`tests/ui_layout.bats`).
- **Test seam:** `AIDEVIX_UI_DUMP=1` — menyu interaktiv ochilmasdan BITTA kadrni stdout'ga chizadi (`AIDEVIX_UI_DUMP_QUERY` bilan qidiruv holati ham). Maket testlari (`tests/ui_layout.bats`) TTY/pty talab qilmaydi.
- **Ichki menyu texnikasi (`select_with_arrows`):** ALT-SCREEN (`\033[?1049h`) + alternate-scroll (`\033[?1007h`) — sichqoncha G'ILDIRAGI strelka bo'lib keladi (scroll ishlaydi), scrollback buzilmaydi. Datafile BIR o'qishda `r_*` massivlariga olinadi, statik `t()` matnlar loop'dan oldin bir marta hisoblanadi — klavish tsiklida fork YO'Q (MSYS'da har fork ~50-150ms edi → "scroll ishlamayapti" shikoyati). Birinchi bayt bloklovchi `read -rsn1` (builtin); ESC'dan keyingi baytlar `_rq` orqali UCH QATLAMLI: stty VTIME+dd → `read -t 1` zaxira → ikkalasi ham darhol bo'sh qaytsa (EPOCHREALTIME bilan o'lchanadi) `TIMERS_BROKEN=1` va BLOKLOVCHI o'qish (strelka baytlari birga kelgani uchun darhol qaytadi; yolg'iz ESC u muhitda ikkinchi klavishani kutadi, ESC-ESC = bekor). Shu tufayli strelka HECH QACHON "bekor" deb o'qilmaydi. Notanish CSI (Delete, F-klavish, Ctrl+strelka) — `action=skip` bilan yutiladi, menyu YOPILMAYDI; faqat yolg'iz ESC/q bekor qiladi. Testlar: `tests/menu_errtrap.bats`.
- `quick_launch` (nomdan agent topish) → `launch_selected` → `ensure_installed` → `maybe_autoupdate_agent` → `maybe_show_auth_note` → `launch_agent` (`exec`).
- **O'rnatilganini aniqlash (reinstall-aylanasiga qarshi):** `locate_binary <binary>` — PATH'da ko'rinmagan binarni ma'lum joylardan (`~/.local/bin`, `~/.<binary>/bin`, Windows pip `%APPDATA%\Python\Python3XX\Scripts`, ...) qidiradi; topsa PATH'ga qo'shadi va `record_bin_dir` bilan `BIN_DIR_CACHE` (`$STATE_DIR/bin_dirs`)ga yozadi. `augment_tool_path` keyingi sessiyalarda keshdagi papkalarni avtomatik qo'shadi. `ensure_installed` o'rnatishdan OLDIN ham, KEYIN ham locate bilan qutqaradi. `resolve_install_cmd` — Windows'da `python3` Store-stub bo'lsa buyruqni `python`ga moslaydi (`-c 'import sys'` bilan tekshiradi). Testlar: `tests/install_detect.bats`.
- **Agentni avtomatik yangilash:** `maybe_autoupdate_agent` — ALLAQACHON o'rnatilgan agentni ishga tushirishdan oldin, throttled (`AIDEVIX_UPDATE_INTERVAL`, std 3 soat) BIR MARTA eng so'nggi versiyaga yangilaydi. Faqat qayta `install` qilganda haqiqatan yangilaydiganlar uchun (`@latest`/`--upgrade`); curl/wget ATAYLAB chiqarilgan (butun installer'ni qayta yuklab, "yana o'rnatyapti" taassurotini berardi), brew/cargo ham o'tkazib yuboriladi. Per-agent stamp: `AGENT_UPDATE_DIR` (`touch_agent_update_stamp`). Eski Gemini CLI "client no longer supported" muammosini hal qiladi. Xato — bloklamaydi. O'chirish: `AIDEVIX_NO_AUTOUPDATE=1`/`CI`. `ensure_installed` ham fresh o'rnatishdan keyin stamp yozadi (darhol qayta yangilamaslik uchun).
- **Sertifikat/soat xatosi:** `ensure_installed` o'rnatish xatosida "certificate is not yet valid / expired" naqshini tutib, internet emas — tizim SOATI noto'g'ri ekanini aniq panelda tushuntiradi (freebuff'dagi muammo).
- **Til (i18n) UX:** `load_saved_lang` (main'da, preview'dan oldin), `choose_language` (ilk run picker, `LANG_FILE`), `lang_cmd` (`--lang [en|uz]`), `aidevix_set_lang` (i18n.sh). Agent `desc`/`auth` `parse_agents`'da `t()` bilan tarjima qilinadi → menyu/preview/--list to'liq bir tilda. `maybe_show_intro` (BIR MARTA "Aidevix nima/emas" paneli). `ui_spin_start/stop` (common.sh) — menyu tayyorlanayotgandagi fon loaderi. `bin/postinstall.js` — npm'dan keyin "aidevix yozing" yo'riqnomasi.
- `ensure_installed` — yo'q bo'lsa ruxsat so'rab o'rnatadi; OS-qo'llab-quvvatlamaslik / xato uchun aniq `panel` xabarlari.
- `should_open_login_link` — 🔑 kalit kerak VA muhitda yo'q bo'lsagina login sahifa ochadi.
- `doctor`, `update_agents`, `add_agent`, `auto_update` (git `fetch`+`reset --hard`, throttled).
- **npm yangilanish eslatmasi (notify):** `is_npm_install` (PROJECT_ROOT `node_modules` ichidami), `version_gt` (semver taqqoslash, tashqi dastursiz), `fetch_npm_latest` (registry `dist-tags`'dan eng so'nggi versiyani FONDA keshlaydi, throttled), `maybe_npm_update_hint` (yangisi chiqsa eslatadi). **Interaktiv auto-update:** `npm_autoupdate_apply` — yangi versiya bor + interaktiv sessiya (`[[ -t 0 ]]` + `/dev/tty` + `npm`) bo'lsa "Hozir yangilaymizmi? [Y/n]" so'raydi; tasdiqlasa `npm i -g pkg@latest` qilib `exec "$0" "$@"` bilan qayta ishga tushiradi. Nointeraktiv (quvur/CI/bats) — gate o'tmaydi, passiv eslatma qoladi. Git o'rnatishlar uchun `auto_update` ishlaydi; npm uchun esa bu — chunki `.git` yo'q. `AIDEVIX_NO_AUTOUPDATE`/`CI` hurmat qilinadi.
- **Kutilmagan xato → KATTA yangilash eslatmasi:** `crash <buyruq> <qator>` — ERR-tutqich endi `die` o'rniga SHUNI chaqiradi (10 ta trap). Crashlarning aksariyati eski versiyada bo'lgani uchun xatodan keyin yangilash buyrug'ini ko'zga tashlanadigan `panel` bilan ko'rsatadi: npm o'rnatishda `npm i -g aidevix@latest`, git checkout'da `aidevix --update` (`is_npm_install` + `.git` bo'yicha tanlaydi). Testlar: `tests/menu_errtrap.bats`.
- **Banner animatsiyasi:** `banner_full` (common.sh) — logo qatorma-qator + gradient (`ui_gradient_line`, `ui_anim_wait` lib/ui.sh da). Faqat `AI_ANIM=1` VA `UI_DEPTH=256` bo'lganda; aks holda darhol chiziladi. `ui_anim_wait` ATAYLAB `sleep` ishlatadi: fork'siz `exec {fd}<> <(:)` MSYS'da redirect xatosi berardi va noninteraktiv bash `exec` barbod bo'lsa BUTUN SKRIPTNI to'xtatadi (banner birinchi qatordan keyin jim uzilardi). Bu tsikl klavish tsikli emas — butun o'rnatishda 6 kadr.
- **Lokal statistika:** `record_usage`/`read_usage` (`STATS_FILE`); `build_menu`/`list_agents` lokal sanoq bo'yicha saralaydi. `build_menu` 4-argument sifatida OXIRGI ishlatilgan agent nomini (`read_last`) oladi — u "↩ oxirgi" belgisi bilan eng tepada chiqadi (agent yopilib qolsa bitta ENTER bilan qayta ochiladi).
- **Global statistika (opt-in):** `global_stats_enabled`, `set_global_stats`, `stats_cmd` (`--stats on|off`), `report_usage_global` (fonda POST), `fetch_global_stats` (fonda kesh, throttled), `global_install_tsv` (JSON→TSV reyting), `maybe_global_hint`. Backend: `server/`.

## Konventsiyalar (PRga ta'sir qiladi)
- Har skript boshida `set -Eeuo pipefail`. ERR tutqich `crash` qiladi (xato + KATTA yangilash eslatmasi); TTY o'qishdan oldin tutqich vaqtincha o'chiriladi.
- Har funksiya ustida qisqa **o'zbekcha** izoh. Foydalanuvchiga ko'rinadigan yangi matnni **`t "..."`** bilan o'rab yoz (manba o'zbekcha) va o'sha kalitni **`lib/i18n/en.sh`** ga inglizcha tarjimasi bilan qo'sh. `%s` joy egalari `t`ga argument sifatida beriladi.
- `lib/common.sh` log/UI'lari **STDERR**'ga yozadi — stdout faqat qaytariladigan qiymat uchun.
- Ranglar `UI_TTY`ga bog'liq; `NO_COLOR` hurmat qilinadi.
- Commit: Conventional Commits (`feat:`, `fix:`, `docs:`, ...). Release qo'lda emas — teg orqali.
- Test: yangi funksiya/xulq qo'shsang → `tests/` ga test ham qo'sh.

## Muhim env o'zgaruvchilar
| O'zgaruvchi | Ta'siri |
|-------------|---------|
| `AI_PULT_CONFIG` | Aniq config yo'li (test/maxsus). Berilsa — faqat o'sha. |
| `AIDEVIX_LANG` | Interfeys tili: `uz` yoki `en`. Berilmasa saqlangan tanlov (`--lang`), so'ng `LANG`/`LC_*` locale'idan aniqlanadi; ilk ishga tushishda interaktiv so'raladi. |
| `AIDEVIX_ICONS` | Ikonka pog'onasi: `nerd`/`unicode`/`ascii`/`auto`. Avtomatik aniqlash va saqlangan tanlovdan (`--icons`) ustun. |
| `AIDEVIX_UI_DUMP` | `1` — menyuning BITTA kadrini stdout'ga chizib qaytadi (test seam, TTY kerak emas). `AIDEVIX_UI_DUMP_QUERY` — qidiruv holati. |
| `AIDEVIX_USE_FZF` | `1` — menyuni fzf bilan ochadi. **Standart — ichki `select_with_arrows`**: ikki ustunli maket, status bar va footer FAQAT unda bor (fzf'da `--footer` yo'q, Windows'da preview ham std o'chiq — natijada fzf o'rnatilganlar tekis ro'yxat ko'rardi). `AIDEVIX_NO_FZF` — fzf'ni butunlay o'chiradi. |
| `AIDEVIX_FZF_PREVIEW` | `1` — fzf preview'ni majburan yoqadi (Windows/MSYS'da std o'chiq, cygwin fork xatosi uchun). |
| `AIDEVIX_NO_AUTOUPDATE=1` | Avtomatik yangilanish (git), npm eslatmasi **va** agentni avtomatik yangilash (`maybe_autoupdate_agent`)ni o'chiradi. |
| `AIDEVIX_UPDATE_INTERVAL` | Tekshirish oralig'i (sekund, std 10800) — aidevix git auto-update, npm tekshiruvi **va** agentni avtomatik yangilash throttle'i. |
| `CI=1` | Animatsiya + auto_update **+ global statistika** o'chiq. |
| `NO_COLOR` / `AI_NO_ANIM` | Rang / animatsiyani o'chiradi. |
| `AIDEVIX_GLOBAL_STATS` | Global statistika opt-in (`1`/`0`) — `GLOBAL_OPTIN_FILE`dan ustun. |
| `AIDEVIX_STATS_URL` | Global statistika backend URL'i (std: Railway server, `server/`). |
| `AIDEVIX_STATS_TTL` | Global kesh yangilash oralig'i (sekund, std 10800). |

## Buyruqlar
```bash
make test          # bats tests/        — testlar
make lint          # shellcheck
make syntax        # bash -n barcha skript
make check         # syntax + lint + test (CI bilan bir xil)
bats tests/foo.bats   # bitta fayl
```

## Tez-tez uchraydigan tuzoqlar (gotchas)
- **`declare -A X` YETARLI EMAS — `declare -gA X=()` yoz.** Ikki xil tuzoq bir joyda:
  (1) **`-g`** — bu fayllar funksiya ichidan ham `source` qilinadi (testlarda
  `load_selector`, ishlab chiqarishda `aidevix_set_lang`). `-g` bo'lmasa massiv
  o'sha funksiyaga LOKAL bo'lib qoladi va chiqishda yo'qoladi; keyin
  `${MSG_EN[$kalit]}` assotsiativ emas, INDEKSLI massiv sifatida o'qilib kalitni
  ARIFMETIK hisoblashga urinadi ("syntax error: operand expected") — tarjima jim
  ishlamay qo'yadi. (2) **`=()`** — e'lon qilib qiymat bermaslik `set -u` ostida
  `${#X[@]}` ni "unbound variable" qiladi va skript JIMGINA 1 kod bilan
  to'xtaydi (aynan shu sabab `aidevix --lang en` hech narsa chiqarmasdi).
- **Nom orqali qaytaruvchi funksiyalarda ichki lokal `__` bilan boshlanadi.**
  `printf -v "$__v"` chaqiruvchi bergan NOMGA yozadi; ichki `local s` chaqiruvchi
  ham `s` deb atagan bo'lsa, natija unga YETIB BORMAYDI. Shu sabab `trim()` jim
  ishlamay turgan edi (`trim_v s "$s"`, `trim_v` ichida ham `local s`) va
  `aidevix --add` foydalanuvchi kiritgan bo'shliqlarni kesmasdi.
- **Testlar YIQILA OLISHINI vaqti-vaqti bilan tekshir.** `tests/test_helper.bash`
  bats'ning ERR/EXIT tutqichlarini saqlab-tiklaydi
  (`_save_bats_traps`/`_restore_bats_traps`). Ilgari u ularni shunchaki
  `trap -` bilan olib tashlardi va bats yiqilishni UMUMAN ko'rmasdi — 207 test
  "yashil" edi, aslida 21 tasi yiqilardi. Yangi helper yozsang: `@test { false; }`
  chindan ham `not ok` berishini tekshir.
- **Ikkilangan mantiq: `clip()` (awk, build_menu) vs `ui_trunc_v` (bash).** Ikkalasi
  ham qisqartiradi, lekin ELLIPSIS uzunligi ascii pog'onada 2 belgi (".."). awk
  nusxasi `n-1` deb hisoblab, tor terminalda qatorni bir belgi uzun chiqarardi.
  Birini o'zgartirsang — ikkinchisini ham tekshir.
- **`$(...)` = FORK. Bu loyihada bu asosiy tezlik muammosi.** MSYS/Windows'da har fork ~50-150 ms. Ilgari `trim()` `sed` orqali ishlardi va `parse_agents` uni har agent uchun 8 marta chaqirardi → 28 agentda ~450 fork; `--list` shu mashinada **60 s dan oshib ketardi**. Endi `trim_v`, `t_v`, `classify_auth_v`, `detect_provider_v`, `ui_*_v` — hammasi `printf -v` bilan, fork'siz. **Yangi kod yozganda:** konfiguratsiyani o'qish, menyu chizish va klavish tsiklida `$(...)`, quvur (`|`), `$(cmd)` ISHLATMA — `_v` variantidan foydalan yoki yangisini qo'sh.
- **Sekin tashqi buyruqlar keshlanadi:** `npm config get prefix` (~2.5 s, node'ni ko'taradi) va `python -m site --user-base` (~1 s) HAR ishga tushishda chaqirilardi. Endi `NPM_PREFIX_CACHE`/`PY_USERBASE_CACHE` da saqlanadi va papka yo'qolsagina qayta so'raladi (`--version`: 7.4 s → 2.0 s).
- **awk dasturi `'...'` bloki ichida — izohlarda APOSTROF ISHLATMA.** `# bo'yicha` deb yozsang blok uziladi va `build_menu` jim buziladi (menyu bo'sh chiqadi). Apostrofsiz yoz: `boyicha`.
- **Windows PATH buzilishi:** Git Bash'da `npm config get prefix` `C:\...` qaytaradi; `augment_tool_path` PATH'ni tozalaydi va `cygpath -u` bilan POSIX shaklga o'tkazadi. Bunga tegishda ehtiyot bo'l.
- **TAB vs bo'sh maydon:** `build_rows` ichida TAB o'rniga `\037` (US) ishlatiladi — bo'sh maydonlar "yutilmasligi" uchun.
- **fzf stdin'ni band qiladi:** TTY o'qishlar `/dev/tty`dan, bo'lmasa `&2`/stdin'dan (qarang `ensure_installed`, `prompt_tty`).
- **`source`-qorovuli:** `ai-selector.sh` oxiri `[[ "${BASH_SOURCE[0]}" == "${0}" ]]` bilan himoyalangan — testda `source` qilsa `main` ishlamaydi. BUNI O'CHIRMA.
- **Repo nomi:** GitHub'da `SUNNATBEE/sunnatbeeCLI`, buyruq nomi esa `aidevix`.

## Reliz vaqtidagi qo'lda yangilanadigan joylar (versiya bump)
`VERSION` + `package.json:version` + `packaging/homebrew/aidevix.rb` (`url` teg + `sha256`) + `packaging/scoop/aidevix.json` (`version` + `extract_dir`) + `man/aidevix.1` (`.TH` qatori). Release teg `vX.Y.Z` `VERSION`ga mos bo'lishi shart (CI tekshiradi).
