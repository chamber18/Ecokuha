"""
fix_with_opacity.py
Replaces .withOpacity(x) with .withValues(alpha: x) in all Dart files.
Handles both simple literals and expressions as arguments.
"""
import os
import re

BASE_DIR = r"c:\Users\Jim\Documents\EcoKuha\ Tracker\EcoKuha\EcoKuha\ecokuha\lib"


def replace_with_opacity(text):
    """Replace .withOpacity(expr) with .withValues(alpha: expr), handling nested parens."""
    result = []
    i = 0
    pattern = '.withOpacity('
    plen = len(pattern)

    while i < len(text):
        idx = text.find(pattern, i)
        if idx == -1:
            result.append(text[i:])
            break

        # Check it's not inside a comment (best-effort: skip if preceded by //)
        line_start = text.rfind('\n', 0, idx) + 1
        line_prefix = text[line_start:idx]
        if '//' in line_prefix:
            result.append(text[i:idx + plen])
            i = idx + plen
            continue

        result.append(text[i:idx])
        result.append('.withValues(alpha: ')

        # Find the matching closing paren
        depth = 1
        j = idx + plen
        while j < len(text) and depth > 0:
            if text[j] == '(':
                depth += 1
            elif text[j] == ')':
                depth -= 1
            j += 1

        # text[idx+plen : j-1] is the argument expression
        arg = text[idx + plen:j - 1]
        result.append(arg)
        result.append(')')
        i = j

    return ''.join(result)


def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
        original = f.read()

    if '.withOpacity(' not in original:
        return False

    updated = replace_with_opacity(original)

    if updated == original:
        return False

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(updated)

    return True


def main():
    modified = []
    errors = []

    for root, dirs, files in os.walk(BASE_DIR):
        dirs[:] = [d for d in dirs if d not in ('build', '.dart_tool', 'generated')]
        for filename in sorted(files):
            if filename.endswith('.dart'):
                filepath = os.path.join(root, filename)
                try:
                    if process_file(filepath):
                        modified.append(os.path.relpath(filepath, BASE_DIR))
                except Exception as e:
                    errors.append((filepath, str(e)))

    print(f"\n✓ Modified {len(modified)} files:")
    for f in modified:
        print(f"  {f}")

    if errors:
        print(f"\n✗ Errors in {len(errors)} files:")
        for f, e in errors:
            print(f"  {f}: {e}")


if __name__ == '__main__':
    main()
