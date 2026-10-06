import urllib.request, json
req = urllib.request.Request('https://api.github.com/repos/ddjamal250-art/Nayli-Kiosk-/actions/jobs/112523552082/logs')
try:
  res = urllib.request.urlopen(req)
  print(res.read().decode('utf-8'))
except Exception as e:
  print('Error:', e)
