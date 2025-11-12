#!/usr/bin/env python3
"""
Script to fix common ARB formatting issues:
1. Remove dangling placeholders blocks (missing key names)
2. Fix malformed placeholder definitions (missing placeholder names)
3. Remove trailing commas from last entries
4. Fix duplicate closing braces
"""

import json
import os
import re
from pathlib import Path

def fix_arb_file(file_path):
    """Fix formatting issues in an ARB file."""
    print(f"Processing {file_path}...")
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        
        # Fix 1: Remove dangling placeholders blocks
        # Pattern: optional whitespace, "placeholders": { ... }, optional whitespace, }
        dangling_pattern = r'\s*"placeholders":\s*\{[^}]*\}\s*,?\s*\}'
        content = re.sub(dangling_pattern, '', content, flags=re.DOTALL)
        
        # Fix 2: Fix malformed placeholder definitions (missing placeholder names)
        # Pattern: "type": "String" without a key name in placeholders
        malformed_placeholder_pattern = r'("placeholders":\s*\{[^}]*)"type":\s*"String"[^}]*}'
        def fix_placeholder(match):
            placeholders_start = match.group(1)
            # Try to infer the placeholder name from context or add a generic one
            return placeholders_start + '"placeholder": {\n        "type": "String"\n      }\n    }'
        
        content = re.sub(malformed_placeholder_pattern, fix_placeholder, content, flags=re.DOTALL)
        
        # Fix 3: Remove trailing comma from last entry before closing brace
        # Pattern: comma followed by optional whitespace and closing brace
        content = re.sub(r',\s*}', '}', content)
        
        # Fix 4: Remove duplicate closing braces
        # Pattern: },} becomes }
        content = re.sub(r'\},\s*\}', '}', content)
        
        # Fix 5: Remove invalid "plural" property
        content = re.sub(r',\s*"plural":\s*"[^"]*"', '', content)
        
        # Fix 6: Remove invalid "example" property in @metadata
        content = re.sub(r',\s*"example":\s*"[^"]*"', '', content)
        
        # Only write if content changed
        if content != original_content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"  ✓ Fixed {file_path}")
            return True
        else:
            print(f"  - No changes needed for {file_path}")
            return False
            
    except Exception as e:
        print(f"  ✗ Error processing {file_path}: {e}")
        return False

def validate_arb_file(file_path):
    """Validate that the ARB file can be parsed as JSON."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            json.load(f)
        return True
    except json.JSONDecodeError as e:
        print(f"  ✗ JSON validation failed for {file_path}: {e}")
        return False
    except Exception as e:
        print(f"  ✗ Validation error for {file_path}: {e}")
        return False

def main():
    """Process all ARB files in the l10n directory."""
    l10n_dir = Path(__file__).parent
    arb_files = list(l10n_dir.glob('app_*.arb'))
    
    if not arb_files:
        print("No ARB files found!")
        return
    
    print(f"Found {len(arb_files)} ARB files to process...")
    
    fixed_count = 0
    for arb_file in arb_files:
        if fix_arb_file(arb_file):
            fixed_count += 1
    
    print(f"\nFixed {fixed_count} file(s).")
    
    # Validate all files after fixing
    print("\nValidating all ARB files...")
    valid_count = 0
    for arb_file in arb_files:
        if validate_arb_file(arb_file):
            valid_count += 1
    
    print(f"Validation complete: {valid_count}/{len(arb_files)} files are valid JSON.")
    
    if valid_count == len(arb_files):
        print("✓ All ARB files are now valid!")
    else:
        print("✗ Some files still have issues. Manual review may be needed.")

if __name__ == '__main__':
    main()
