// update-arb-translations.mjs
import fs from 'node:fs';
import path from 'node:path';

const rootDir = new URL('.', import.meta.url).pathname;
const l10nDir = path.join(rootDir, 'lib', 'l10n');

const localeToFile = {
  de: 'app_de.arb',
  en: 'app_en.arb',
  es: 'app_es.arb',
  fr: 'app_fr.arb',
  it: 'app_it.arb',
  ja: 'app_ja.arb',
  kr: 'app_kr.arb',
  nl: 'app_nl.arb',
  ur: 'app_ur.arb',
  ru: 'app_ru.arb',
  uk: 'app_uk.arb',
  zh: 'app_zh.arb',
  zh_TW: 'app_zh_TW.arb',
  vi: 'app_vi.arb'
};

const translationsPath = path.join(rootDir, 'translations.json');
if (!fs.existsSync(translationsPath)) {
  console.error(`translations.json not found at: ${translationsPath}`);
  process.exit(1);
}

const translations = JSON.parse(fs.readFileSync(translationsPath, 'utf8'));

function updateLocale(locale) {
  const fileName = localeToFile[locale];
  if (!fileName) return;

  const arbPath = path.join(l10nDir, fileName);
  if (!fs.existsSync(arbPath)) return;

  let arbJson;
  try {
    arbJson = JSON.parse(fs.readFileSync(arbPath, 'utf8'));
  } catch (err) {
    console.error(`Failed to parse JSON in ${arbPath}:`, err.message);
    return;
  }

  let addedCount = 0;

  for (const key of Object.keys(translations)) {
    const perLocale = translations[key];
    if (!perLocale || !(locale in perLocale)) continue;

    // skip if the key already exists
    if (key in arbJson) continue;

    arbJson[key] = perLocale[locale];
    addedCount++;
  }

  if (addedCount > 0) {
    fs.writeFileSync(arbPath, JSON.stringify(arbJson, null, 2) + '\n', 'utf8');
    console.log(`Updated ${fileName}: added ${addedCount} key(s).`);
  } else {
    console.log(`No new keys for ${locale}.`);
  }
}

function main() {
  for (const locale of Object.keys(localeToFile)) {
    updateLocale(locale);
  }
}

main();