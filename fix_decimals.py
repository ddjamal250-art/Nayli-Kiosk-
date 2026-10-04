import re, glob, os

files = glob.glob('lib/features/product/presentation/**/*.dart', recursive=True)

for file_path in files:
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content

    # Replace toStringAsFixed(0) with helper or inline
    if 'toStringAsFixed(0)' in content:
        # For simplicity, if we don't have the helper in the class, we can just replace with inline ternary
        # val.toStringAsFixed(0) -> (val == val.toInt() ? val.toInt().toString() : val.toString())
        # But regex for val is hard because it might be irst.quantity
        # Let's use a simpler regex replacement for basic variables
        def replacer(match):
            val = match.group(1)
            return f'({val} == {val}.roundToDouble() ? {val}.toInt().toString() : {val}.toString())'
            
        content = re.sub(r'([a-zA-Z0-9_\.]+)\.toStringAsFixed\(0\)', replacer, content)

    # Replace .toInt().toString() with the same inline if it's applied to price or cost
    # Actually, if it's a known price field like price.toInt().toString():
    if 'toInt().toString()' in content:
        def to_int_replacer(match):
            val = match.group(1)
            return f'({val} == {val}.roundToDouble() ? {val}.toInt().toString() : {val}.toString())'
        content = re.sub(r'([a-zA-Z0-9_\.]+)\.toInt\(\)\.toString\(\)', to_int_replacer, content)

    if original_content != content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print('Updated', file_path)

