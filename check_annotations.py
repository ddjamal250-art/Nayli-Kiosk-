import urllib.request, json
req = urllib.request.Request('https://api.github.com/repos/ddjamal250-art/Nayli-Kiosk-/commits/59e0f52/check-runs', headers={'Accept': 'application/vnd.github.v3+json'})
res = urllib.request.urlopen(req)
print(res.read().decode('utf-8'))
