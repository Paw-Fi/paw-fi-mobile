// update-arb-translations.mjs
import fs from 'node:fs';
import path from 'node:path';

const rootDir = new URL('.', import.meta.url).pathname;
const l10nDir = path.join(rootDir, 'lib', 'l10n');

// Configuration: Set to true to replace existing keys, false to skip them
const REPLACE_EXISTING_KEYS = false;

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
  th: 'app_th.arb',
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
  let replacedCount = 0;

  for (const key of Object.keys(translations)) {
    const perLocale = translations[key];
    if (!perLocale || !(locale in perLocale)) continue;

    // Handle existing keys based on configuration
    if (key in arbJson) {
      if (REPLACE_EXISTING_KEYS) {
        arbJson[key] = perLocale[locale];
        replacedCount++;
      } else {
        continue; // Skip existing keys
      }
    } else {
      arbJson[key] = perLocale[locale];
      addedCount++;
    }
  }

  if (addedCount > 0 || replacedCount > 0) {
    fs.writeFileSync(arbPath, JSON.stringify(arbJson, null, 2) + '\n', 'utf8');
    let message = `Updated ${fileName}:`;
    if (addedCount > 0) message += ` added ${addedCount} key(s).`;
    if (replacedCount > 0) message += ` replaced ${replacedCount} key(s).`;
    console.log(message);
  } else {
    console.log(`No changes for ${fileName}.`);
  }
}

function main() {
  for (const locale of Object.keys(localeToFile)) {
    updateLocale(locale);
  }
}

main();
