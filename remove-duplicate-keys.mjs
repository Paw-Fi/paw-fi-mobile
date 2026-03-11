// remove-duplicate-keys.mjs
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
  th: 'app_th.arb',
  uk: 'app_uk.arb',
  zh: 'app_zh.arb',
  zh_TW: 'app_zh_TW.arb',
  vi: 'app_vi.arb'
};

function removeDuplicateKeys(locale) {
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

  // Find duplicates: keys that have the same value
  const valueToKeys = new Map();
  const duplicates = new Set();
  
  // Build a map of values to their keys
  for (const [key, value] of Object.entries(arbJson)) {
    // Skip metadata keys (starting with @)
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
      // Keep the first key with metadata, remove others
      const keyToKeep = keysWithMetadata[0];
      keysToRemove = keys.filter(k => k !== keyToKeep);
    } else {
      // Keep the first key, remove others
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

  if (duplicates.size === 0) {
    console.log(`No duplicate keys found in ${fileName}.`);
    return;
  }

  // Remove duplicate keys and their metadata
  let removedCount = 0;
  for (const duplicateKey of duplicates) {
    delete arbJson[duplicateKey];
    removedCount++;
  }

  // Write the cleaned file
  const updated = JSON.stringify(arbJson, null, 2) + '\n';
  fs.writeFileSync(arbPath, updated, 'utf8');
  
  console.log(`Updated ${fileName}: removed ${removedCount} duplicate key(s) for locale ${locale}.`);
  
  // Show which keys were removed (optional, for debugging)
  if (process.argv.includes('--verbose')) {
    const removedTranslationKeys = Array.from(duplicates).filter(k => !k.startsWith('@'));
    console.log(`  Removed keys: ${removedTranslationKeys.join(', ')}`);
  }
}

function main() {
  console.log('Removing duplicate keys with identical values from ARB files...\n');
  
  for (const locale of Object.keys(localeToFile)) {
    removeDuplicateKeys(locale);
  }
  
  console.log('\nDuplicate key removal completed for all locales.');
}

main();
