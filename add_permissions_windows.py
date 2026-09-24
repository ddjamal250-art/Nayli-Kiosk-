import re
file_path = r'd:\repos\Nayli Market -custom-\.github\workflows\build_windows_setup.yml'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

if 'permissions:\n      contents: write' not in content:
    content = content.replace('runs-on: windows-latest', 'runs-on: windows-latest\n    permissions:\n      contents: write')

# Replace the flutter build windows step to capture log
if 'flutter build windows > windows_build_error.log' not in content:
    content = content.replace('run: flutter build windows', '''run: flutter build windows > windows_build_error.log 2>&1
        continue-on-error: true

      - name: Upload windows build log
        run: |
          git config --global user.name "AI"
          git config --global user.email "ai@ai.com"
          git add windows_build_error.log
          git commit -m "Upload windows log"
          git pull --rebase origin main || exit 0
          git push origin main || exit 0
        continue-on-error: true''')

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
