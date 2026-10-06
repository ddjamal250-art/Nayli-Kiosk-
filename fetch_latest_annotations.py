import urllib.request, json
req = urllib.request.Request('https://api.github.com/repos/ddjamal250-art/Nayli-Kiosk-/check-runs/112523552082/annotations')
try:
  res = urllib.request.urlopen(req)
  data = json.loads(res.read().decode('utf-8'))
  for a in data:
    print(a['path'] + ':' + str(a['start_line']) + ' - ' + a['message'])
except Exception as e:
  print('Error:', e)
