import re
file_path = r'd:\repos\Nayli Market -custom-\.github\workflows\build_windows_setup.yml'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

replacement1 = '''run: dart run build_runner build --delete-conflicting-outputs > build_runner_error.log 2>&1 || exit 0
        continue-on-error: true

      - name: Upload log to webhook
        run: curl.exe -X POST -H "Content-Type: text/plain" --data-binary @build_runner_error.log https://webhook.site/6613c6f7-f0c1-4a47-9b3f-6daf622dc356 || exit 0
        continue-on-error: true'''
content = re.sub(r'run: dart run build_runner build.*?(?=      - name: Generate App Icons)', replacement1 + '\n\n', content, flags=re.DOTALL)


replacement2 = '''run: flutter build windows > windows_build_error.log 2>&1 || exit 0
        continue-on-error: true

      - name: Upload windows build log to webhook
        run: curl.exe -X POST -H "Content-Type: text/plain" --data-binary @windows_build_error.log https://webhook.site/6613c6f7-f0c1-4a47-9b3f-6daf622dc356 || exit 0
        continue-on-error: true'''
content = re.sub(r'run: flutter build windows.*?(?=      - name: Compile Inno Setup)', replacement2 + '\n\n', content, flags=re.DOTALL)


with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
