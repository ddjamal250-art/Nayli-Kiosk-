
with open(".github/workflows/build_windows_setup.yml", "r", encoding="utf-8") as f:
    text = f.read()

import re
text = re.sub(r"foreach \(\$line in \$err\) \{ .*? \}", "foreach ($line in $err) { Write-Output \"::error::$line\" }", text)

with open(".github/workflows/build_windows_setup.yml", "w", encoding="utf-8") as f:
    f.write(text)

