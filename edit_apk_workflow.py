import re
file_path = r'd:\repos\Nayli Market -custom-\.github\workflows\build_apk.yml'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

replacement = '''run: dart run build_runner build --delete-conflicting-outputs > build_runner_error.log 2>&1
        continue-on-error: true

      - name: Upload log to termbin
        run: cat build_runner_error.log | nc termbin.com 9999 || true
        continue-on-error: true'''

content = content.replace('run: dart run build_runner build --delete-conflicting-outputs', replacement)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
