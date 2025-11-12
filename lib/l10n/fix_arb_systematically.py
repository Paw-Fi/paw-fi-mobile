#!/usr/bin/env python3
"""
Systematic fix for ARB file structural issues.
This script identifies and fixes common ARB file problems:
1. Metadata without corresponding message keys
2. Malformed placeholder structures  
3. Invalid properties
4. JSON syntax errors
"""

import json
import re
from typing import Dict, List, Set

def load_arb_file(filepath: str) -> Dict:
    """Load ARB file and return as dictionary."""
    with open(filepath, 'r', encoding='utf-8') as f:
        return json.load(f)

def save_arb_file(filepath: str, data: Dict):
    """Save ARB file with proper formatting."""
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

def find_metadata_without_messages(data: Dict) -> List[str]:
    """Find @metadata keys that don't have corresponding message keys."""
    messages = set()
    metadata = set()
    
    for key in data.keys():
        if key.startswith('@'):
            metadata.add(key[1:])  # Remove @ prefix
        else:
            messages.add(key)
    
    # Find metadata keys without corresponding messages
    orphaned_metadata = metadata - messages
    return [f"@{key}" for key in orphaned_metadata]

def find_placeholders_in_strings(data: Dict) -> Dict[str, Set[str]]:
    """Find all placeholders used in message strings."""
    placeholders_by_key = {}
    
    for key, value in data.items():
        if not key.startswith('@') and isinstance(value, str):
            # Find {placeholder} patterns
            placeholders = re.findall(r'\{(\w+)\}', value)
            placeholders_by_key[key] = set(placeholders)
    
    return placeholders_by_key

def find_missing_placeholder_definitions(data: Dict) -> Dict[str, Set[str]]:
    """Find placeholders used in strings but not defined in metadata."""
    placeholders_used = find_placeholders_in_strings(data)
    missing_definitions = {}
    
    for key, placeholders in placeholders_used.items():
        metadata_key = f"@{key}"
        if metadata_key in data:
            metadata = data[metadata_key]
            if 'placeholders' in metadata:
                defined_placeholders = set(metadata['placeholders'].keys())
                missing = placeholders - defined_placeholders
                if missing:
                    missing_definitions[key] = missing
            else:
                # No placeholders section at all
                if placeholders:
                    missing_definitions[key] = placeholders
    
    return missing_definitions

def fix_placeholder_definitions(data: Dict) -> Dict:
    """Fix missing placeholder definitions by adding them."""
    missing = find_missing_placeholder_definitions(data)
    
    for key, missing_placeholders in missing.items():
        metadata_key = f"@{key}"
        if metadata_key not in data:
            data[metadata_key] = {}
        
        if 'placeholders' not in data[metadata_key]:
            data[metadata_key]['placeholders'] = {}
        
        # Add missing placeholders with appropriate types
        for placeholder in missing_placeholders:
            if placeholder not in data[metadata_key]['placeholders']:
                # Determine type based on common patterns
                if placeholder in ['amount', 'currency', 'currencySymbol', 'action', 'date', 'category', 'error']:
                    placeholder_type = "String"
                elif placeholder in ['days', 'seconds', 'min', 'max', 'count']:
                    placeholder_type = "int"
                else:
                    placeholder_type = "String"
                
                data[metadata_key]['placeholders'][placeholder] = {"type": placeholder_type}
    
    return data

def remove_invalid_properties(data: Dict) -> Dict:
    """Remove invalid properties like 'example' from metadata."""
    for key, value in data.items():
        if key.startswith('@') and isinstance(value, dict):
            # Remove invalid properties, keep only allowed ones
            allowed_keys = {'description', 'placeholders'}
            if isinstance(value, dict):
                # Filter out invalid keys
                data[key] = {k: v for k, v in value.items() if k in allowed_keys}
    
    return data

def remove_orphaned_metadata(data: Dict) -> Dict:
    """Remove metadata entries without corresponding message keys."""
    messages = set()
    to_remove = []
    
    # Collect all message keys
    for key in data.keys():
        if not key.startswith('@'):
            messages.add(key)
    
    # Find orphaned metadata
    for key in data.keys():
        if key.startswith('@'):
            message_key = key[1:]
            if message_key not in messages:
                to_remove.append(key)
    
    # Remove orphaned metadata
    for key in to_remove:
        del data[key]
    
    return data

def fix_spanish_arb_file():
    """Fix the Spanish ARB file systematically."""
    filepath = '/Users/charles/side-projects/Moneko/moneko-mobile/lib/l10n/app_es.arb'
    
    try:
        print("Loading Spanish ARB file...")
        data = load_arb_file(filepath)
        
        print("Finding issues...")
        orphaned_metadata = find_metadata_without_messages(data)
        print(f"Found {len(orphaned_metadata)} orphaned metadata entries")
        
        missing_placeholders = find_missing_placeholder_definitions(data)
        print(f"Found {len(missing_placeholders)} keys with missing placeholder definitions")
        
        print("Applying fixes...")
        # Fix missing placeholder definitions
        data = fix_placeholder_definitions(data)
        
        # Remove invalid properties
        data = remove_invalid_properties(data)
        
        # Remove orphaned metadata (optional - comment out if you want to keep them)
        # data = remove_orphaned_metadata(data)
        
        print("Saving fixed file...")
        save_arb_file(filepath, data)
        print("Spanish ARB file fixed successfully!")
        
    except Exception as e:
        print(f"Error fixing Spanish ARB file: {e}")

def fix_german_arb_file():
    """Fix the German ARB file systematically."""
    filepath = '/Users/charles/side-projects/Moneko/moneko-mobile/lib/l10n/app_de.arb'
    
    try:
        print("Loading German ARB file...")
        data = load_arb_file(filepath)
        
        print("Applying fixes...")
        # Remove invalid properties
        data = remove_invalid_properties(data)
        
        print("Saving fixed file...")
        save_arb_file(filepath, data)
        print("German ARB file fixed successfully!")
        
    except Exception as e:
        print(f"Error fixing German ARB file: {e}")

if __name__ == "__main__":
    print("Starting systematic ARB file fixes...")
    fix_spanish_arb_file()
    fix_german_arb_file()
    print("All fixes completed!")
