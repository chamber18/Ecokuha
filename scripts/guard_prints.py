"""
guard_prints.py
Wraps bare print() calls in Dart files with if (kDebugMode) guards.
Adds the kDebugMode import from flutter/foundation.dart where needed.
"""
import os
import re

BASE_DIR = r"c:\Users\Jim\Documents\EcoKuha\ Tracker\EcoKuha\EcoKuha\ecokuha\lib"
KDEBUG_IMPORT = "import 'package:flutter/foundation.dart' show kDebugMode;"
# Pattern: line starts with whitespace then print(
# We require the full print statement to be on one line (ends with );)
PRINT_PATTERN = re.compile(r'^(\s+)(print\(.*\);)\s*$')


def is_guarded(lines, i):
    """Return True if the print at line i is already inside an if (kDebugMode) guard."""
    line = lines[i]
    # Same line guard: if (kDebugMode) print(...)
    if 'kDebugMode' in line:
        return True
    # Check the previous non-empty line for a kDebugMode guard
    for j in range(i - 1, max(-1, i - 5), -1):
        prev = lines[j].rstrip()
        if prev:  # skip blank lines
            if 'kDebugMode' in prev:
                return True
            break
    return False


def is_in_comment(line):
    """Return True if the line is a comment."""
    stripped = line.lstrip()
    return stripped.startswith('//') or stripped.startswith('*') or stripped.startswith('/*')


def bracket_depth(text):
    """Count unmatched open parens in text (excluding string contents, best-effort)."""
    depth = 0
    in_single = False
    in_double = False
    i = 0
    while i < len(text):
        c = text[i]
        if c == "'" and not in_double:
            in_single = not in_single
        elif c == '"' and not in_single:
            in_double = not in_double
        elif not in_single and not in_double:
            if c == '(':
                depth += 1
            elif c == ')':
                depth -= 1
        i += 1
    return depth


def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
        original = f.read()

    if 'print(' not in original:
        return False

    lines = original.splitlines(keepends=True)
    new_lines = []
    i = 0
    modified = False
    has_foundation = 'foundation.dart' in original

    while i < len(lines):
        line = lines[i]
        stripped = line.rstrip('\n\r')

        # Skip comment lines
        if is_in_comment(stripped):
            new_lines.append(line)
            i += 1
            continue

        # Check for a single-line print( call
        m = PRINT_PATTERN.match(stripped)
        if m:
            indent = m.group(1)
            print_stmt = m.group(2)

            # Verify the print statement has balanced brackets (truly single-line)
            if bracket_depth(print_stmt) == 0:
                if not is_guarded(lines, i):
                    eol = line[len(stripped):]  # preserve \n
                    new_lines.append(indent + 'if (kDebugMode) ' + print_stmt + eol)
                    modified = True
                    i += 1
                    continue

        # Check for multi-line print( — line starts with print( but doesn't close on same line
        m2 = re.match(r'^(\s+)(print\()', stripped)
        if m2 and not is_in_comment(stripped):
            indent = m2.group(1)
            # Collect until the print statement closes
            depth = bracket_depth(stripped)
            block = [line]
            j = i + 1
            while depth > 0 and j < len(lines):
                block.append(lines[j])
                depth += bracket_depth(lines[j].rstrip('\n\r'))
                j += 1

            # Check if this whole block is already guarded
            if not is_guarded(lines, i):
                eol = '\n'
                new_lines.append(indent + 'if (kDebugMode) {\n')
                for bl in block:
                    # Add 2 spaces of extra indentation
                    if bl.strip():
                        new_lines.append('  ' + bl)
                    else:
                        new_lines.append(bl)
                new_lines.append(indent + '}\n')
                modified = True
                i = j
                continue

        new_lines.append(line)
        i += 1

    if not modified:
        return False

    # Add kDebugMode import if foundation.dart not already imported
    if not has_foundation:
        # Find the last import line and insert after it
        last_import_idx = -1
        for j, l in enumerate(new_lines):
            if l.lstrip().startswith('import '):
                last_import_idx = j
        if last_import_idx >= 0:
            new_lines.insert(last_import_idx + 1, KDEBUG_IMPORT + '\n')
    elif 'kDebugMode' not in original and 'foundation.dart' in original:
        # foundation.dart is imported but kDebugMode not in the show clause — add it
        for j, l in enumerate(new_lines):
            if 'foundation.dart' in l and 'show' in l:
                # Add kDebugMode to existing show clause
                new_lines[j] = new_lines[j].rstrip('\n\r').rstrip(';') + ', kDebugMode;\n'
                break
            elif 'foundation.dart' in l and 'show' not in l:
                # Plain import — leave it, kDebugMode is exported from it anyway
                break

    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)

    return True


def main():
    modified = []
    skipped = []

    for root, dirs, files in os.walk(BASE_DIR):
        # Skip build/generated directories
        dirs[:] = [d for d in dirs if d not in ('build', '.dart_tool', 'generated')]
        for filename in sorted(files):
            if filename.endswith('.dart'):
                filepath = os.path.join(root, filename)
                try:
                    if process_file(filepath):
                        rel = os.path.relpath(filepath, BASE_DIR)
                        modified.append(rel)
                except Exception as e:
                    skipped.append((filepath, str(e)))

    print(f"\n✓ Modified {len(modified)} files:")
    for f in modified:
        print(f"  {f}")

    if skipped:
        print(f"\n✗ Errors in {len(skipped)} files:")
        for f, e in skipped:
            print(f"  {f}: {e}")


if __name__ == '__main__':
    main()
