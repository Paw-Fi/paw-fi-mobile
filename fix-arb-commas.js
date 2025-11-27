const fs = require('fs');
const path = require('path');

// Function to fix missing commas in ARB file
function fixMissingCommas(filePath) {
  console.log(`Processing ${filePath}...`);
  
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    const lines = content.split('\n');
    let modified = false;
    const changes = [];
    
    const processedLines = lines.map((line, index) => {
      const trimmed = line.trim();
      
      // Skip empty lines, comments, and closing brace
      if (!trimmed || trimmed.startsWith('//') || trimmed === '}' || trimmed.startsWith('@@')) {
        return line;
      }
      
      // Check if line is a key-value pair (ends with quote but no comma)
      const keyValueMatch = trimmed.match(/^"([^"]+)":\s*"([^"]*)"$/);
      if (keyValueMatch) {
        // Look at the next non-empty, non-comment line to determine if we need a comma
        let needsComma = false;
        for (let i = index + 1; i < lines.length; i++) {
          const nextLine = lines[i].trim();
          if (!nextLine || nextLine.startsWith('//')) {
            continue; // Skip empty lines and comments
          }
          if (nextLine === '}') {
            needsComma = false; // Last item before closing brace
          } else {
            needsComma = true; // Not the last item
          }
          break;
        }
        
        if (needsComma && !trimmed.endsWith(',')) {
          modified = true;
          changes.push(`Line ${index + 1}: Added comma to "${keyValueMatch[1]}"`);
          return line + ',';
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

// Function to validate JSON syntax
function validateJson(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    JSON.parse(content);
    console.log(`✓ ${filePath} has valid JSON syntax`);
    return true;
  } catch (error) {
    console.error(`✗ ${filePath} has JSON syntax error:`, error.message);
    return false;
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
  
  // Fix missing commas
  files.forEach(file => {
    fixMissingCommas(file);
    console.log('');
  });
  
  // Validate all files
  console.log('Validating JSON syntax...\n');
  let allValid = true;
  files.forEach(file => {
    if (!validateJson(file)) {
      allValid = false;
    }
  });
  
  if (allValid) {
    console.log('\n✅ All ARB files are valid!');
    console.log('\nPlease run: flutter gen-l10n');
  } else {
    console.log('\n❌ Some ARB files have syntax errors. Please fix them manually.');
  }
}

// Run the script
main();
