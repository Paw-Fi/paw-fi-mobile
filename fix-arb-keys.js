const fs = require('fs');
const path = require('path');

// Function to convert a string to camelCase
function toCamelCase(str) {
  return str
    .replace(/[^a-zA-Z0-9\s]/g, ' ') // Replace special chars with space
    .replace(/\s+/g, ' ') // Replace multiple spaces with single space
    .trim()
    .split(' ')
    .map((word, index) => {
      if (index === 0) {
        return word.toLowerCase();
      }
      return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase();
    })
    .join('');
}

// Function to check if a key needs conversion
function needsConversion(key) {
  return !/^[a-z][a-zA-Z0-9]*$/.test(key);
}

// Function to process an ARB file
function processArbFile(filePath) {
  console.log(`Processing ${filePath}...`);
  
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    const lines = content.split('\n');
    let modified = false;
    const changes = [];
    
    const processedLines = lines.map(line => {
      // Match key-value pairs (ignoring comments and empty lines)
      const match = line.match(/^(\s*)"([^"]+)":\s*"([^"]*)"/);
      if (match) {
        const [, indent, key, value] = match;
        
        if (needsConversion(key)) {
          const newKey = toCamelCase(key);
          if (newKey !== key) {
            modified = true;
            changes.push(`"${key}" → "${newKey}"`);
            return `${indent}"${newKey}": "${value}"`;
          }
        }
      }
      return line;
    });
    
    if (modified) {
      fs.writeFileSync(filePath, processedLines.join('\n'), 'utf8');
      console.log(`✓ Updated ${filePath}`);
      console.log('  Changes:');
      changes.forEach(change => console.log(`    ${change}`));
    } else {
      console.log(`- No changes needed for ${filePath}`);
    }
    
  } catch (error) {
    console.error(`Error processing ${filePath}:`, error.message);
  }
}

// Main function
function main() {
  const l10nDir = path.join(__dirname, 'lib', 'l10n');
  
  if (!fs.existsSync(l10nDir)) {
    console.error(`Directory not found: ${l10nDir}`);
    process.exit(1);
  }
  
  console.log('Scanning for ARB files...\n');
  
  const files = fs.readdirSync(l10nDir)
    .filter(file => file.endsWith('.arb'))
    .map(file => path.join(l10nDir, file));
  
  if (files.length === 0) {
    console.log('No ARB files found.');
    return;
  }
  
  console.log(`Found ${files.length} ARB file(s):\n`);
  
  files.forEach(file => {
    processArbFile(file);
    console.log('');
  });
  
  console.log('Done! ✨');
  console.log('\nPlease run: flutter gen-l10n');
}

// Run the script
main();
