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

const translationsRaw = fs.readFileSync(translationsPath, 'utf8');
const translations = JSON.parse(translationsRaw);

function updateLocale(locale, options = {}) {
  const { sync = false, removeDuplicates = false } = options;
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
  let removedCount = 0;

  // Remove duplicates first if requested
  if (removeDuplicates) {
    const valueToKeys = new Map();
    const duplicates = new Set();
    
    // Build a map of values to their keys (skip metadata)
    for (const [key, value] of Object.entries(arbJson)) {
      if (key.startsWith('@')) continue;
      
      const valueStr = JSON.stringify(value);
      
      if (valueToKeys.has(valueStr)) {
        const existingKeys = valueToKeys.get(valueStr);
        existingKeys.push(key);
      } else {
        valueToKeys.set(valueStr, [key]);
      }
    }

    // Determine which keys to remove by checking for metadata
    for (const [valueStr, keys] of valueToKeys.entries()) {
      if (keys.length <= 1) continue; // No duplicates
      
      // Find keys that have associated metadata (preferred to keep)
      const keysWithMetadata = [];
      const keysWithoutMetadata = [];
      
      for (const key of keys) {
        const metadataKey = `@${key}`;
        if (Object.prototype.hasOwnProperty.call(arbJson, metadataKey)) {
          keysWithMetadata.push(key);
        } else {
          keysWithoutMetadata.push(key);
        }
      }
      
      // If we have keys with metadata, keep the first one with metadata
      // Otherwise, keep the first key overall
      let keysToRemove;
      if (keysWithMetadata.length > 0) {
        const keyToKeep = keysWithMetadata[0];
        keysToRemove = keys.filter(k => k !== keyToKeep);
      } else {
        const keyToKeep = keys[0];
        keysToRemove = keys.slice(1);
      }
      
      // Also remove the metadata for any removed keys
      for (const keyToRemove of keysToRemove) {
        duplicates.add(keyToRemove);
        const metadataKey = `@${keyToRemove}`;
        if (Object.prototype.hasOwnProperty.call(arbJson, metadataKey)) {
          duplicates.add(metadataKey);
        }
      }
    }

    // Remove duplicate keys and their metadata
    for (const duplicateKey of duplicates) {
      delete arbJson[duplicateKey];
      removedCount++;
    }
  }

  // Sync mode: remove obsolete keys and update existing ones
  if (sync) {
    // Remove any translation keys that are no longer in translations.json
    const keysToRemove = [];
    for (const [key, value] of Object.entries(arbJson)) {
      if (!key.startsWith('@') && (!translations[key] || !translations[key][locale])) {
        keysToRemove.push(key);
        // Also remove associated metadata
        const metadataKey = `@${key}`;
        if (Object.prototype.hasOwnProperty.call(arbJson, metadataKey)) {
          keysToRemove.push(metadataKey);
        }
      }
    }

    for (const keyToRemove of keysToRemove) {
      delete arbJson[keyToRemove];
      removedCount++;
    }
  }

  // Add/update translations from translations.json
  for (const key of Object.keys(translations)) {
    const perLocale = translations[key];
    if (!perLocale || !(locale in perLocale)) continue;

    const translationValue = perLocale[locale];
    
    if (Object.prototype.hasOwnProperty.call(arbJson, key)) {
      // Key exists, update if in sync mode and value is different
      if (sync && arbJson[key] !== translationValue) {
        arbJson[key] = translationValue;
        updatedCount++;
      }
    } else {
      // Key doesn't exist, add it
      arbJson[key] = perLocale[locale];
      addedCount++;
    }
  }

  if (addedCount === 0 && updatedCount === 0 && removedCount === 0) {
    console.log(`No changes needed for ${fileName}.`);
    return;
  }

  const updated = JSON.stringify(arbJson, null, 2) + '\n';
  fs.writeFileSync(arbPath, updated, 'utf8');
  
  let message = `Updated ${fileName}:`;
  if (addedCount > 0) message += ` added ${addedCount}`;
  if (updatedCount > 0) message += ` updated ${updatedCount}`;
  if (removedCount > 0) message += ` removed ${removedCount}`;
  message += ` key(s) for locale ${locale}.`;
  
  console.log(message);
  
  // Show which keys were removed (optional, for debugging)
  if (process.argv.includes('--verbose') && removedCount > 0) {
    console.log(`  Run with --verbose to see details of removed keys.`);
  }
}

function main() {
  const args = process.argv.slice(2);
  const sync = args.includes('--sync') || args.includes('--all');
  const removeDuplicates = args.includes('--remove-duplicates') || args.includes('--all');
  const addOnly = args.includes('--add-only');
  
  // Default to full sync mode unless explicitly add-only
  const defaultSync = !addOnly;
  
  console.log(`Updating ARB translations${(addOnly ? ' (add-only mode)' : (sync || defaultSync) ? ' (sync mode)' : '')}${(removeDuplicates || defaultSync) ? ' (removing duplicates)' : ''}...\n`);
  
  for (const locale of Object.keys(localeToFile)) {
    if (locale === 'en' && addOnly) continue; // Skip English only in add-only mode
    updateLocale(locale, { 
      sync: sync || defaultSync, 
      removeDuplicates: removeDuplicates || defaultSync 
    });
  }
  
  console.log('\nTranslation update completed.');
  console.log('Now run: flutter gen-l10n --untranslated-messages-file untranslated_messages.txt');
}

main();