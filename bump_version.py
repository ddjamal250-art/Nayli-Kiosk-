with open(r'd:\repos\Nayli Market -custom-\pubspec.yaml', 'r', encoding='utf-8') as f:
    text = f.read()
print('Before:', [l for l in text.split('\n') if 'version:' in l[:20]])
text = text.replace('2.0.2+11', '2.1.0+12')
with open(r'd:\repos\Nayli Market -custom-\pubspec.yaml', 'w', encoding='utf-8') as f:
    f.write(text)

with open(r'd:\repos\Nayli Market -custom-\.github\installer\installer.iss', 'r', encoding='utf-8') as f:
    iss = f.read()
iss = iss.replace('2.0.2', '2.1.0')
with open(r'd:\repos\Nayli Market -custom-\.github\installer\installer.iss', 'w', encoding='utf-8') as f:
    f.write(iss)

print('Done - version bumped to 2.1.0+12')
