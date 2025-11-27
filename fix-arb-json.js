const fs = require('fs');
const path = require('path');

// Function to fix JSON syntax in ARB file
function fixArbJson(filePath) {
  console.log(`Processing ${filePath}...`);
  
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    
    // First, try to parse as JSON to see what the actual error is
    try {
      JSON.parse(content);
      console.log(`- ${filePath} already has valid JSON syntax`);
      return;
    } catch (parseError) {
      console.log(`- ${filePath} has JSON syntax issues, fixing...`);
    }
    
    // Fix common JSON syntax issues
    let fixed = content
      // Fix trailing commas before closing braces/brackets
      .replace(/,(\s*[}\]])/g, '$1')
      // Fix missing commas between object properties
      .replace(/"\s*\n\s*"/g, '",\n  "')
      // Fix missing commas between array items
      .replace(/"\s*\n\s*"/g, '",\n  "')
      // Fix missing commas in key-value pairs
      .replace(/":\s*"[^"]*"\s*\n\s*"/g, '",\n  "')
      // Fix missing comma after locale
      .replace(/"@@locale":\s*"[^"]*"\s*\n\s*"/g, '",\n  "');
    
    // More sophisticated fix for missing commas
    const lines = fixed.split('\n');
    const result = [];
    
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const trimmed = line.trim();
      
      result.push(line);
      
      // Check if this line needs a comma and the next line is a property
      if (trimmed.match(/^"[^"]+":\s*"[^"]*"\s*$/) || 
          trimmed.match(/^"[^"]+":\s*\{?\s*$/) ||
          trimmed.match(/^"[^"]+":\s*\d+\s*$/)) {
        
        // Look ahead to see if next non-empty line is another property
        for (let j = i + 1; j < lines.length; j++) {
          const nextLine = lines[j].trim();
          if (!nextLine || nextLine.startsWith('//')) {
            continue; // Skip empty lines and comments
          }
          
          // If next line is a property and current line doesn't end with comma, add one
          if (nextLine.startsWith('"') && !trimmed.endsWith(',') && !trimmed.endsWith('}') && !trimmed.endsWith(']')) {
            result[result.length - 1] = line + ',';
            break;
          } else {
            break; // No comma needed
          }
        }
      }
    }
    
    const finalContent = result.join('\n');
    
    // Validate the fixed content
    try {
      JSON.parse(finalContent);
      fs.writeFileSync(filePath, finalContent, 'utf8');
      console.log(`✓ Fixed ${filePath}`);
    } catch (error) {
      console.error(`✗ Could not fix ${filePath}: ${error.message}`);
      console.log('  Attempting manual fix...');
      
      // Try a more aggressive fix
      let aggressive = content
        .replace(/("@@locale":\s*"[^"]+")(\s*\n\s*")/g, '$1,$2')
        .replace(/("appTitle":\s*"[^"]+")(\s*\n\s*")/g, '$1,$2')
        .replace(/("[^"]+":\s*"[^"]+")(\s*\n\s*"[^"]+":)/g, '$1,$2');
      
      try {
        JSON.parse(aggressive);
        fs.writeFileSync(filePath, aggressive, 'utf8');
        console.log(`✓ Aggressively fixed ${filePath}`);
      } catch (finalError) {
        console.error(`✗ Still broken: ${finalError.message}`);
      }
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
  
  // Fix JSON syntax
  files.forEach(file => {
    fixArbJson(file);
    console.log('');
  });
  
  // Validate all files
  console.log('Validating all files...\n');
  let allValid = true;
  files.forEach(file => {
    try {
      const content = fs.readFileSync(file, 'utf8');
      JSON.parse(content);
      console.log(`✓ ${file} is valid`);
    } catch (error) {
      console.error(`✗ ${file} has errors: ${error.message}`);
      allValid = false;
    }
  });
  
  if (allValid) {
    console.log('\n✅ All ARB files are now valid!');
    console.log('\nPlease run: flutter gen-l10n');
  } else {
    console.log('\n❌ Some files still have issues. Manual review needed.');
  }
}

// Run the script
main();
