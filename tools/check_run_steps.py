import urllib.request
import json
import re
import subprocess
import time
import sys

rem = subprocess.check_output(['git', 'remote', 'get-url', 'origin']).decode().strip()
m = re.search(r'gho_[a-zA-Z0-9]+', rem)
token = m.group(0) if m else None

run_id = 39875763958

def get_run_status():
    req = urllib.request.Request(f'https://api.github.com/repos/ddjamal250-art/Nayli-Kiosk-/actions/runs/{run_id}/jobs')
    req.add_header('User-Agent', 'Python-urllib')
    req.add_header('Accept', 'application/vnd.github+json')
    if token:
        req.add_header('Authorization', f'Bearer {token}')
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode())
    return data

try:
    data = get_run_status()
    jobs = data.get('jobs', [])
    for j in jobs:
        print(f"Job: {j['name']} | Status: {j['status']} | Conclusion: {j['conclusion']}")
        steps = j.get('steps', [])
        for s in steps:
            print(f"  Step: {s['name']} | Status: {s['status']} | Conclusion: {s['conclusion']}")
except Exception as e:
    print("Error:", e)
