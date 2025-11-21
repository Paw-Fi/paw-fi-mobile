// sync-translations.mjs
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

const translationsRaw = fs.readFileSync(translationsPath, 'utf8');
const translations = JSON.parse(translationsRaw);

function syncLocale(locale) {
  const fileName = localeToFile[locale];
  if (!fileName) {
    console.warn(`No ARB file mapping for locale: ${locale}`);
    return;
  }

  const arbPath = path.join(l10nDir, fileName);
  if (!fs.existsSync(arbPath)) {
    console.warn(`ARB file not found for locale ${locale}: ${arbPath}`);
    return;
  }

  const arbRaw = fs.readFileSync(arbPath, 'utf8');
  let arbJson;
  try {
    arbJson = JSON.parse(arbRaw);
  } catch (err) {
    console.error(`Failed to parse JSON in ${arbPath}:`, err.message);
    return;
  }

  let addedCount = 0;
  let updatedCount = 0;

  // First, collect all existing metadata to preserve it
  const existingMetadata = new Map();
  for (const [key, value] of Object.entries(arbJson)) {
    if (key.startsWith('@')) {
      existingMetadata.set(key, value);
    }
  }

  // Update or add all translations from translations.json
  for (const [key, perLocale] of Object.entries(translations)) {
    if (!perLocale || !(locale in perLocale)) continue;

    const translationValue = perLocale[locale];
    
    if (Object.prototype.hasOwnProperty.call(arbJson, key)) {
      // Key exists, check if value needs updating
      if (arbJson[key] !== translationValue) {
        arbJson[key] = translationValue;
        updatedCount++;
      }
    } else {
      // Key doesn't exist, add it
      arbJson[key] = translationValue;
      addedCount++;
    }
  }

  // Remove any translation keys that are no longer in translations.json
  // (but keep metadata keys for now)
  const keysToRemove = [];
  for (const [key, value] of Object.entries(arbJson)) {
    if (!key.startsWith('@') && (!translations[key] || !translations[key][locale])) {
      keysToRemove.push(key);
      // Also remove associated metadata
      const metadataKey = `@${key}`;
      if (existingMetadata.has(metadataKey)) {
        keysToRemove.push(metadataKey);
      }
    }
  }

  for (const keyToRemove of keysToRemove) {
    delete arbJson[keyToRemove];
  }

  // Write the updated file
  const updated = JSON.stringify(arbJson, null, 2) + '\n';
  fs.writeFileSync(arbPath, updated, 'utf8');
  
  console.log(`Synced ${fileName}: added ${addedCount}, updated ${updatedCount}, removed ${keysToRemove.filter(k => !k.startsWith('@')).length} keys for locale ${locale}.`);
}

function main() {
  console.log('Syncing all translations from translations.json to ARB files...\n');
  
  for (const locale of Object.keys(localeToFile)) {
    syncLocale(locale);
  }
  
  console.log('\nTranslation sync completed for all locales.');
  console.log('Now run: flutter gen-l10n --untranslated-messages-file untranslated_messages.txt');
}

main();
