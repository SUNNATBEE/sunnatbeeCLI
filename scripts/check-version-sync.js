#!/usr/bin/env node
/*
 * scripts/check-version-sync.js — `package.json` versiyasi bilan `VERSION`
 * faylini SOLISHTIRADI va mos kelmasa publish'ni TO'XTATADI (exit 1).
 *
 * NEGA KERAK (haqiqiy hodisa, v1.9.1):
 *   npm'ga chiqarilgan paketda `package.json` = 1.9.1, lekin ichidagi `VERSION`
 *   fayli 1.7.4 bo'lib qolgan edi. Skript o'z versiyasini AYNAN `VERSION`
 *   faylidan o'qiydi (bin/ai-selector.sh), registry esa `package.json`ni
 *   ko'rsatadi — natijada har ishga tushganda "1.7.4 → 1.9.1 yangilaymizmi?"
 *   deb so'rardi, yangilangandan keyin ham. Foydalanuvchi cheksiz halqaga
 *   tushdi. Bir qatorlik nomuvofiqlik — butun tarqatish kanali buzildi.
 *
 * `prepack` orqali chaqiriladi, ya'ni `npm pack` va `npm publish` da AVTOMATIK
 * ishlaydi. CI/qo'lda: `node scripts/check-version-sync.js`.
 */
'use strict';

const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const pkgPath = path.join(root, 'package.json');
const verPath = path.join(root, 'VERSION');

const pkgVersion = JSON.parse(fs.readFileSync(pkgPath, 'utf8')).version;
// CRLF/BOM/bo'sh qatorlar — Windows'da tahrirlanganda paydo bo'ladi.
const fileVersion = fs.readFileSync(verPath, 'utf8').replace(/^﻿/, '').trim();

// Qat'iy SemVer tekshiruvi: faqat raqamlar va nuqtalardan iborat bo'lishi kerak (masalan: 1.9.4)
const semverRegex = /^\d+\.\d+\.\d+$/;

if (!semverRegex.test(pkgVersion) || !semverRegex.test(fileVersion)) {
  console.error(
    '\n[x] VERSIYA FORMATI XATO — publish to\'xtatildi.\n' +
    `      package.json : "${pkgVersion}"\n` +
    `      VERSION      : "${fileVersion}"\n\n` +
    '    Versiyalar qat\'iy "X.Y.Z" formatida bo\'lishi shart (masalan: 1.9.4).\n' +
    '    Oldida "v" harfi yoki boshqa belgilar/bo\'shliqlar qolib ketmasin.\n'
  );
  process.exit(1);
}

if (pkgVersion !== fileVersion) {
  console.error(
    '\n[x] VERSIYALAR MOS KELMAYDI — publish to\'xtatildi.\n' +
    `      package.json : ${pkgVersion}\n` +
    `      VERSION      : ${fileVersion}\n\n` +
    '    Ikkalasi ham BIR XIL bo\'lishi shart: skript o\'z versiyasini VERSION\n' +
    '    faylidan o\'qiydi, npm registry esa package.json\'ni ko\'rsatadi. Mos\n' +
    '    kelmasa foydalanuvchi cheksiz "yangilaymizmi?" halqasiga tushadi.\n'
  );
  process.exit(1);
}

console.log(`[+] Versiya sinxron: ${pkgVersion}`);
