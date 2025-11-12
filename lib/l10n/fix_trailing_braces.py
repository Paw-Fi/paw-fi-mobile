#!/usr/bin/env python3
"""
Script to fix trailing brace issues in ARB files.
"""

import os
import re
from pathlib import Path

def fix_trailing_braces(file_path):
    """Fix entries that have } instead of , at the end."""
    print(f"Processing {file_path}...")
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        
        # Fix pattern: "key": "value"},  -> "key": "value",
        pattern = r'("[^"]*":\s*"[^"}]*)\},'
        content = re.sub(pattern, r'\1,', content)
        
        # Also fix pattern where it's the last entry: "key": "value"}  -> "key": "value"
        pattern = r'("[^"]*":\s*"[^"}]*)\}(?=\s*$)'
        content = re.sub(pattern, r'\1', content)
        
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
        if fix_trailing_braces(arb_file):
            fixed_count += 1
    
    print(f"\nFixed {fixed_count} file(s).")

if __name__ == '__main__':
    main()
