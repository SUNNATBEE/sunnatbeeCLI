#!/usr/bin/env node
/*
 * bin/cli.js — npm orqali o'rnatilganda `aidevix` buyrug'i uchun
 * cross-platform Node.js launcher.
 *
 * Aidevix yadrosi — `bin/ai-selector.sh` (bash skripti). Bu fayl shunchaki
 * bash'ni topib, skriptni o'sha bash bilan ishga tushiradi va argumentlar +
 * stdio + exit-kodni uzatadi. Windows'da bash Git for Windows bilan keladi.
 */
'use strict';

const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const SCRIPT = path.join(__dirname, 'ai-selector.sh');

// WSL bashmi? Windows'da `where bash` KO'PINCHA C:\Windows\System32\bash.exe
// ni birinchi qaytaradi — bu WSL launcher'i, Git Bash EMAS. Uni ishga tushirsak
// Linux fayl tizimiga tushib qolamiz va `C:\...\ai-selector.sh` yo'li topilmaydi
// → CLI jim yopiladi. Shuning uchun System32 dagi bash'ni ATAYLAB rad etamiz.
function isWslBash(p) {
  const sysRoot = process.env['SystemRoot'] || 'C:\\Windows';
  const norm = path.resolve(p).toLowerCase();
  return (
    norm.startsWith(path.join(sysRoot, 'System32').toLowerCase()) ||
    norm.startsWith(path.join(sysRoot, 'Sysnative').toLowerCase())
  );
}

// bash'ni topish. Windows'da AVVAL Git for Windows joylari (WSL bilan
// adashmaslik uchun), so'ng PATH. Unix'da avval PATH.
function findBash() {
  const win = process.platform === 'win32';

  const gitCandidates = win
    ? [
        path.join(process.env['ProgramFiles'] || 'C:\\Program Files', 'Git', 'bin', 'bash.exe'),
        path.join(process.env['ProgramFiles(x86)'] || 'C:\\Program Files (x86)', 'Git', 'bin', 'bash.exe'),
        path.join(process.env['LOCALAPPDATA'] || '', 'Programs', 'Git', 'bin', 'bash.exe'),
      ]
    : [];

  // Windows: Git Bash birinchi navbatda.
  for (const c of gitCandidates) {
    if (c && fs.existsSync(c)) return c;
  }

  // PATH'da bash bormi? (which/where o'rniga spawnSync bilan tekshiramiz)
  const probe = spawnSync(win ? 'where' : 'which', ['bash'], { encoding: 'utf8' });
  if (probe.status === 0 && probe.stdout) {
    for (const line of probe.stdout.split(/\r?\n/)) {
      const p = line.trim();
      if (!p || !fs.existsSync(p)) continue;
      if (win && isWslBash(p)) continue;      // WSL launcher — o'tkazib yuboramiz
      return p;
    }
  }

  if (win) return null;

  // Unix: oxirgi chora.
  for (const c of ['/bin/bash', '/usr/bin/bash', '/usr/local/bin/bash']) {
    if (fs.existsSync(c)) return c;
  }
  return 'bash';
}

function main() {
  const bash = findBash();
  if (!bash) {
    process.stderr.write(
      '[x] bash topilmadi. Aidevix bash talab qiladi.\n' +
        '    Windows: Git for Windows o\'rnating — https://git-scm.com/download/win\n'
    );
    process.exit(127);
  }

  // Yo'lni oldinga-slash shaklida beramiz: `C:\...\ai-selector.sh` dagi teskari
  // slashlar bash uchun ekranlash belgisi bo'lib ko'rinishi mumkin. MSYS
  // `C:/...` ni muammosiz tushunadi.
  const script = SCRIPT.replace(/\\/g, '/');
  const args = [script, ...process.argv.slice(2)];

  if (process.env.AIDEVIX_DEBUG) {
    process.stderr.write('[debug] bash   = ' + bash + '\n');
    process.stderr.write('[debug] script = ' + script + '\n');
    process.stderr.write('[debug] tty    = stdin:' + Boolean(process.stdin.isTTY) +
      ' stdout:' + Boolean(process.stdout.isTTY) + '\n');
  }

  const res = spawnSync(bash, args, { stdio: 'inherit' });

  if (res.error) {
    process.stderr.write('[x] Ishga tushirib bo\'lmadi: ' + res.error.message + '\n' +
      '    bash: ' + bash + '\n' +
      '    skript: ' + script + '\n');
    process.exit(1);
  }
  // Signal bilan to'xtaganda JIM chiqmaymiz — sababini aytamiz (aks holda
  // "hech narsa ko'rsatmasdan yopildi" bo'lib qoladi).
  if (res.status === null) {
    process.stderr.write('[x] Aidevix kutilmaganda to\'xtadi' +
      (res.signal ? ' (signal: ' + res.signal + ')' : '') + '.\n' +
      '    Batafsil: AIDEVIX_DEBUG=1 aidevix\n');
    process.exit(1);
  }
  process.exit(res.status);
}

// Jim o'lim yo'q: kutilmagan istisno/rad etishni ko'rsatamiz.
process.on('uncaughtException', (err) => {
  process.stderr.write('[x] Kutilmagan xato (aidevix launcher): ' + (err && err.stack || err) + '\n');
  process.exit(1);
});
process.on('unhandledRejection', (err) => {
  process.stderr.write('[x] Kutilmagan rad etish (aidevix launcher): ' + (err && err.stack || err) + '\n');
  process.exit(1);
});

main();
