import urllib.request, json
req = urllib.request.Request('https://api.github.com/repos/ddjamal250-art/Nayli-Kiosk-/actions/runs/37539975492/jobs')
res = urllib.request.urlopen(req)
data = json.loads(res.read().decode('utf-8'))
print('Job ID:', data['jobs'][0]['id'], 'Status:', data['jobs'][0]['status'])
