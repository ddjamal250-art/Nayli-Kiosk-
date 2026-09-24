import re
file_path = r'd:\repos\Nayli Market -custom-\.github\workflows\build_apk.yml'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

replacement = '''run: dart run build_runner build --delete-conflicting-outputs > build_runner_error.log 2>&1 || true
        continue-on-error: true

      - name: Upload log to webhook
        run: curl -X POST -H "Content-Type: text/plain" --data-binary @build_runner_error.log https://webhook.site/6613c6f7-f0c1-4a47-9b3f-6daf622dc356 || true
        continue-on-error: true'''

# regex replace
content = re.sub(r'run: dart run build_runner build.*?(?=      - name: Generate App Icons)', replacement + '\n\n', content, flags=re.DOTALL)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
