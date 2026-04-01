#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script to replace all print() calls with log.d() in Dart files
"""

import os
import re
from pathlib import Path

def add_logger_import(content):
    """Add logger import if not already present"""
    if "import 'package:lidle/core/logger.dart'" in content:
        return content
    
    # Find the position to insert the import (after other imports)
    lines = content.split('\n')
    insert_index = 0
    
    for i, line in enumerate(lines):
        if line.startswith('import '):
            insert_index = i + 1
    
    if insert_index > 0:
        # Insert after last import
        new_lines = lines[:insert_index] + ["import 'package:lidle/core/logger.dart';"] + lines[insert_index:]
        return '\n'.join(new_lines)
    else:
        # Prepend if no imports found
        return "import 'package:lidle/core/logger.dart';\n" + content

def replace_prints(content):
    """Replace all print( with log.d("""
    return re.sub(r'print\(', 'log.d(', content)

def process_dart_files():
    """Process all dart files in lib directory"""
    lib_path = Path('lib')
    dart_files = list(lib_path.rglob('*.dart'))
    
    files_updated = 0
    
    print(f"Found {len(dart_files)} Dart files")
    print("Starting replacement...\n")
    
    for dart_file in dart_files:
        try:
            # Read file
            with open(dart_file, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Check if file contains print(
            if 'print(' not in content:
                continue
            
            original_content = content
            
            # Add logger import
            content = add_logger_import(content)
            
            # Replace print( with log.d(
            content = replace_prints(content)
            
            # Write file back
            with open(dart_file, 'w', encoding='utf-8') as f:
                f.write(content)
            
            files_updated += 1
            print(f"✓ Updated: {dart_file.relative_to(lib_path.parent)}")
            
        except Exception as e:
            print(f"✗ Error processing {dart_file}: {e}")
    
    print(f"\n{'='*50}")
    print(f"Done! Updated {files_updated} files")
    print(f"{'='*50}")

if __name__ == '__main__':
    process_dart_files()
