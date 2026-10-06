import urllib.request, json
req = urllib.request.Request('https://api.github.com/repos/ddjamal250-art/Nayli-Kiosk-/actions/runs?per_page=1')
res = urllib.request.urlopen(req)
data = json.loads(res.read().decode('utf-8'))
run = data['workflow_runs'][0]
print('Status:', run['status'], 'Conclusion:', run['conclusion'], 'URL:', run['html_url'], 'ID:', run['id'])
