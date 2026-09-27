file_path = r"d:\repos\Nayli Market -custom-\.github\workflows\build_windows_setup.yml"
with open(file_path, "r", encoding="utf-8") as f:
    text = f.read()

import re
replacement = """jobs:
  build-windows:
    runs-on: windows-2022
    permissions:
      contents: write"""

text = re.sub(
    r'jobs:\s+build-windows:\s+runs-on: windows-2022',
    replacement,
    text
)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(text)
