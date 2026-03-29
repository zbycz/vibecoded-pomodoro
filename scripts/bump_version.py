#!/usr/bin/env python3
"""Bump MARKETING_VERSION in project.yml and print the new version."""
import re, sys, os

bump = sys.argv[1] if len(sys.argv) > 1 else "minor"
if bump not in ("major", "minor", "patch"):
    print(f"Unknown bump type: {bump}", file=sys.stderr)
    sys.exit(1)

path = os.path.join(os.path.dirname(__file__), "..", "project.yml")
with open(path) as f:
    content = f.read()

m = re.search(r'MARKETING_VERSION:\s*"(\d+)\.(\d+)\.(\d+)"', content)
if not m:
    print("MARKETING_VERSION not found in project.yml", file=sys.stderr)
    sys.exit(1)

major, minor, patch = int(m.group(1)), int(m.group(2)), int(m.group(3))

if bump == "major":
    major += 1; minor = 0; patch = 0
elif bump == "minor":
    minor += 1; patch = 0
else:
    patch += 1

new_ver = f"{major}.{minor}.{patch}"
new_content = re.sub(
    r'(MARKETING_VERSION:\s*)"[\d.]+"',
    f'\\1"{new_ver}"',
    content
)
with open(path, "w") as f:
    f.write(new_content)

print(new_ver)
