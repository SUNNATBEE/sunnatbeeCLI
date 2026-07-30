# Packaging — paket menejerlari orqali tarqatish

Aidevix CLI'ni turli paket menejerlari orqali tarqatish uchun manifestlar.

| Menejer | Fayl | Buyruq |
|---------|------|--------|
| **npm** | `../package.json` + `../bin/cli.js` | `npm install -g aidevix` |
| **Homebrew** | `homebrew/aidevix.rb` | `brew install SUNNATBEE/tap/aidevix` |
| **Scoop** | `scoop/aidevix.json` | `scoop install aidevix` |

## npm

Yadro `bin/ai-selector.sh` (bash). `bin/cli.js` bash'ni topib, skriptni ishga
tushiradi (Windows'da Git Bash). Nashr:

```bash
npm publish          # "aidevix" nomi band bo'lsa: @sunnatbee/aidevix
```

### ⛔ `npm publish` FAQAT repo ildizidan

Publish qilishdan oldin **qaysi papkada turganingizni** tekshiring:

```bash
pwd                  # .../sunnatbeeCLI  (repo ildizi) bo'lishi SHART
git status           # toza va to'g'ri teg/commit'da turibmi?
npm run version:check
```

**Nima uchun bu muhim (v1.9.1 hodisasi):** paket bir marta xato papkadan —
`~/AppData/Roaming/npm/node_modules/aidevix` (ya'ni O'RNATILGAN eski nusxadan) —
publish qilingan. Natijada registry'ga `package.json` = 1.9.1, lekin ichidagi
`VERSION` = 1.7.4 va **1.7.5 ning kodi** bo'lgan paket chiqdi. CLI o'z
versiyasini `VERSION` faylidan o'qiydi, shuning uchun yangilangandan keyin ham
o'zini eski deb bilib, foydalanuvchini cheksiz "yangilaymizmi? [Y/n]" halqasiga
tushirdi.

Endi `prepack` (ya'ni `npm publish` va `npm pack`) `scripts/check-version-sync.js`
ni ishga tushiradi va `VERSION` bilan `package.json` mos kelmasa publish'ni
**to'xtatadi**. O'rnatilgan nusxadan publish qilishga urinilsa ham shu bosqich
yiqiladi (u nusxada `scripts/` yo'q) — bu ataylab shunday.

> ⚠️ Chiqarilgan versiyani QAYTA publish qilish mumkin emas (npm ruxsat
> bermaydi) — buzuq reliz chiqsa, keyingi patch versiyani chiqarish va eskisini
> `npm deprecate` bilan belgilash kerak.

> ⚠️ npm orqali ishga tushganda `.git` bo'lmaydi — avtomatik yangilanish jim
> o'tkazib yuboriladi. Yangilash: `npm update -g aidevix`.

## Homebrew

`homebrew/aidevix.rb` ni o'z tap'ingizga joylang:
`SUNNATBEE/homebrew-tap/Formula/aidevix.rb`. Har relizda `url` tegini va
`sha256` ni yangilang:

```bash
curl -fsSL https://github.com/SUNNATBEE/sunnatbeeCLI/archive/refs/tags/vX.Y.Z.tar.gz | shasum -a 256
```

## Scoop

`scoop/aidevix.json` ni bucket repozitoriyasiga joylang. `checkver` + `autoupdate`
yangi relizlarni avtomatik kuzatadi. Foydalanuvchi:

```powershell
scoop bucket add aidevix https://github.com/SUNNATBEE/sunnatbeeCLI
scoop install aidevix
```

> Scoop o'rnatilgandan keyin `aidevix` ishlashi uchun Git Bash kerak
> (`scoop install git`).
