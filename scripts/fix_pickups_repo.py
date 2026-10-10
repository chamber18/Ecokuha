"""
Fixes two lint issues in pickups_repository.dart:
1. curly_braces_in_flow_control_structures - adds {} to bare if (kDebugMode) bodies
2. avoid_types_as_parameter_names - renames fold parameter `sum` -> `acc`
"""

import re

path = r"c:\Users\Jim\Documents\EcoKuha\ Tracker\EcoKuha\EcoKuha\ecokuha\lib\features\junkshop\data\repositories\pickups_repository.dart"

with open(path, encoding='utf-8') as f:
    lines = f.readlines()

result = []
i = 0
while i < len(lines):
    line = lines[i]

    # Fix curly_braces: if (kDebugMode) <newline> <indent>statement
    stripped = line.rstrip('\n')
    # Match an "if (kDebugMode)" line that does NOT already end with '{'
    if re.search(r'if\s*\(kDebugMode\)\s*$', stripped):
        indent = len(stripped) - len(stripped.lstrip())
        # The if-body is on the next line
        if i + 1 < len(lines):
            body_line = lines[i + 1]
            body_stripped = body_line.rstrip('\n')
            # Make sure this is indeed a single-statement body (not already a block)
            if body_stripped.lstrip() and not body_stripped.lstrip().startswith('{'):
                result.append(stripped + ' {\n')
                result.append(body_line.rstrip('\n') + '\n')
                result.append(' ' * indent + '}\n')
                i += 2
                continue

    # Fix avoid_types_as_parameter_names: rename fold parameter `sum` to `acc`
    # Pattern: (sum, <identifier>) => sum + ...
    if '(sum,' in line and '=>' in line:
        line = line.replace('(sum,', '(acc,').replace('=> sum ', '=> acc ')

    result.append(line)
    i += 1

with open(path, 'w', encoding='utf-8') as f:
    f.writelines(result)

print("Done.")
