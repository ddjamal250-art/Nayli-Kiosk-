import re
file_path = r'd:\repos\Nayli Market -custom-\.github\workflows\build_windows_setup.yml'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

replacement = '''run: dart run build_runner build --delete-conflicting-outputs > build_runner_error.log 2>&1
        continue-on-error: true

      - name: Upload log to paste.rs
        run: |
          python -c "import urllib.request; data = open('build_runner_error.log', 'rb').read(); req = urllib.request.Request('https://paste.rs/', data=data, method='POST'); res = urllib.request.urlopen(req); print(res.read().decode())"
        continue-on-error: true'''

content = content.replace('''run: dart run build_runner build --delete-conflicting-outputs > build_runner_error.log 2>&1
        continue-on-error: true

      - name: Upload log if failed
        run: |
          git config --global user.name "AI"
          git config --global user.email "ai@ai.com"
          git add build_runner_error.log
          git commit -m "Upload log"
          git pull --rebase origin main
          git push origin main
        continue-on-error: true''', replacement)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
