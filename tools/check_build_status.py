import urllib.request
import json
import re
import subprocess
import sys

rem = subprocess.check_output(['git', 'remote', 'get-url', 'origin']).decode().strip()
m = re.search(r'gho_[a-zA-Z0-9]+', rem)
token = m.group(0) if m else None

req = urllib.request.Request('https://api.github.com/repos/ddjamal250-art/Nayli-Kiosk-/actions/runs?per_page=5')
req.add_header('User-Agent', 'Python-urllib')
req.add_header('Accept', 'application/vnd.github+json')
if token:
    req.add_header('Authorization', f'Bearer {token}')

try:
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode())
    for run in data.get('workflow_runs', []):
        r_id = run['id']
        name = run['name']
        status = run['status']
        conclusion = run['conclusion']
        sha = run['head_sha'][:7]
        msg = run.get('head_commit', {}).get('message', '').split('\n')[0][:50]
        html_url = run.get('html_url')
        print(f"Run {r_id} ({name}): status={status}, conclusion={conclusion}, sha={sha}, url={html_url}, commit={msg}")
except Exception as e:
    print("Error querying actions:", e)
