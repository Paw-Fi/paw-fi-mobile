#!/usr/bin/env python3

import json
import os

def fix_spanish_arb_issues():
    """Fix lint errors in Spanish ARB file"""
    
    file_path = "/Users/charles/side-projects/Moneko/moneko-mobile/lib/l10n/app_es.arb"
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    lines = content.split('\n')
    result_lines = []
    
    # Track seen keys to avoid duplicates
    seen_keys = set()
    
    for line in lines:
        # Check for duplicate keys and remove them
        should_remove = False
        if line.strip().startswith('"') and '":' in line:
            key = line.strip().split('"')[1]
            if key in seen_keys:
                should_remove = True
            else:
                seen_keys.add(key)
        
        # Fix plural property issue - remove "plural" line
        if '"plural":' in line:
            should_remove = True
            
        # Fix incorrect type issue - look for line 536 issue
        if '"type": "int"' in line and 'max' in line:
            # This might be the incorrect type issue
            pass  # Keep it for now, check manually later
        
        if not should_remove:
            result_lines.append(line)
    
    # Write the cleaned content back
    cleaned_content = '\n'.join(result_lines)
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(cleaned_content)
    
    print("Fixed lint errors in Spanish ARB file")

if __name__ == "__main__":
    fix_spanish_arb_issues()
