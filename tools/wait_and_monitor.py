import urllib.request
import json
import re
import subprocess
import time
import sys

# Ensure UTF-8 output on Windows
if sys.platform == 'win32':
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

rem = subprocess.check_output(['git', 'remote', 'get-url', 'origin']).decode().strip()
m = re.search(r'gho_[a-zA-Z0-9]+', rem)
token = m.group(0) if m else None

run_id = 39877437306
print(f"Monitoring workflow run {run_id} (https://github.com/ddjamal250-art/Nayli-Kiosk-/actions/runs/{run_id})...", flush=True)

def get_job_info():
    req = urllib.request.Request(f'https://api.github.com/repos/ddjamal250-art/Nayli-Kiosk-/actions/runs/{run_id}/jobs')
    req.add_header('User-Agent', 'Python-urllib')
    req.add_header('Accept', 'application/vnd.github+json')
    if token:
        req.add_header('Authorization', f'Bearer {token}')
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode())
        jobs = data.get('jobs', [])
        if not jobs:
            return None, None, []
        j = jobs[0]
        return j.get('status'), j.get('conclusion'), j.get('steps', [])
    except Exception as e:
        print(f"API request error: {e}", flush=True)
        return 'in_progress', None, []

last_active = ""
completed_steps = set()

while True:
    status, conclusion, steps = get_job_info()

    for s in steps:
        s_name = s.get('name')
        s_status = s.get('status')
        s_conclusion = s.get('conclusion')
        
        if s_status == 'completed' and s_name not in completed_steps:
            completed_steps.add(s_name)
            tag = "[OK]" if s_conclusion == 'success' else ("[SKIP]" if s_conclusion == 'skipped' else "[FAIL]")
            print(f"{tag} Step: {s_name} ({s_conclusion})", flush=True)

        if s_status == 'in_progress' and s_name != last_active:
            last_active = s_name
            print(f"[IN_PROGRESS] Step: {s_name}", flush=True)

    if status == 'completed':
        print(f"\n==========================================", flush=True)
        print(f"RUN FINISHED with conclusion: {conclusion}", flush=True)
        print(f"==========================================", flush=True)
        if conclusion == 'success':
            print(">>> ALL STEPS COMPLETED SUCCESSFULLY! Release is built and available! <<<", flush=True)
        else:
            print("Build failed. Checking annotations...", flush=True)
            head_commit = 'fc2e2cf'
            areq = urllib.request.Request(f'https://api.github.com/repos/ddjamal250-art/Nayli-Kiosk-/commits/{head_commit}/check-runs')
            areq.add_header('User-Agent', 'Python-urllib')
            areq.add_header('Accept', 'application/vnd.github+json')
            if token:
                areq.add_header('Authorization', f'Bearer {token}')
            try:
                with urllib.request.urlopen(areq) as aresp:
                    adata = json.loads(aresp.read().decode())
                for cr in adata.get('check_runs', []):
                    aurl = cr.get('output', {}).get('annotations_url')
                    if aurl:
                        ann_req = urllib.request.Request(aurl)
                        ann_req.add_header('User-Agent', 'Python-urllib')
                        if token:
                            ann_req.add_header('Authorization', f'Bearer {token}')
                        with urllib.request.urlopen(ann_req) as ann_resp:
                            for a in json.loads(ann_resp.read().decode()):
                                print(f"[{a.get('annotation_level')}] {a.get('message')}")
            except Exception as e:
                print(f"Error fetching annotations: {e}")
        break

    time.sleep(15)
