import re
import os

file_apk = r'd:\repos\Nayli Market -custom-\.github\workflows\build_apk.yml'
with open(file_apk, 'r', encoding='utf-8') as f:
    content_apk = f.read()

content_apk = content_apk.replace('run: curl -X POST', 'run: |\n          curl -X POST')
with open(file_apk, 'w', encoding='utf-8') as f:
    f.write(content_apk)

file_win = r'd:\repos\Nayli Market -custom-\.github\workflows\build_windows_setup.yml'
with open(file_win, 'r', encoding='utf-8') as f:
    content_win = f.read()

content_win = content_win.replace('run: curl.exe -X POST', 'run: |\n          curl.exe -X POST')
with open(file_win, 'w', encoding='utf-8') as f:
    f.write(content_win)
