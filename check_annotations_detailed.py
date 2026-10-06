import urllib.request, json
req = urllib.request.Request('https://api.github.com/repos/ddjamal250-art/Nayli-Kiosk-/check-runs/112515936293/annotations', headers={'Accept': 'application/vnd.github.v3+json'})
res = urllib.request.urlopen(req)
data = json.loads(res.read().decode('utf-8'))
for a in data:
  print(a['path'] + ':' + str(a['start_line']) + ' - ' + a['message'])
