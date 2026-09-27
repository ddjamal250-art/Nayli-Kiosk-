file_path = r"d:\repos\Nayli Market -custom-\.github\workflows\build_windows_setup.yml"
with open(file_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if line.startswith("        run: flutter build windows --verbose > windows_build_error.log 2>&1 || exit 0"):
        new_lines.append("        run: |\n          flutter build windows --verbose > windows_build_error.log 2>&1 || exit 0\n")
    else:
        new_lines.append(line)

with open(file_path, "w", encoding="utf-8") as f:
    f.writelines(new_lines)
