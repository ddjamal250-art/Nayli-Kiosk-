import urllib.request
import json
import time
import sys

REPO = "ddjamal250-art/Nayli-Kiosk-"
HEADERS = {
    "User-Agent": "Nayli-Kiosk-Monitor",
    "Accept": "application/vnd.github+json"
}

def get_latest_run_id():
    url = f"https://api.github.com/repos/{REPO}/actions/runs?per_page=1"
    req = urllib.request.Request(url, headers=HEADERS)
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode())
            runs = data.get("workflow_runs", [])
            if runs:
                return str(runs[0]["id"])
    except Exception as e:
        print(f"Error fetching latest run id: {e}")
    return None

def get_run_details(run_id):
    url = f"https://api.github.com/repos/{REPO}/actions/runs/{run_id}"
    req = urllib.request.Request(url, headers=HEADERS)
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode())
    except Exception as e:
        print(f"Error fetching run: {e}")
        return None

def get_job_steps(run_id):
    url = f"https://api.github.com/repos/{REPO}/actions/runs/{run_id}/jobs"
    req = urllib.request.Request(url, headers=HEADERS)
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode())
            jobs = data.get("jobs", [])
            if not jobs:
                return []
            return jobs[0].get("steps", [])
    except Exception as e:
        print(f"Error fetching job steps: {e}")
        return []

def print_status(run_id):
    run = get_run_details(run_id)
    if not run:
        return None
    print(f"\n[{time.strftime('%H:%M:%S')}] Build Run {run_id} | Status: {run['status']} | Conclusion: {run['conclusion']}")
    
    steps = get_job_steps(run_id)
    for s in steps:
        st = s['status']
        con = s['conclusion'] or "running..."
        icon = "[OK]" if con == "success" else ("[-]" if st == "in_progress" else "[  ]")
        if con == "failure":
            icon = "[FAIL]"
        safe_name = s['name'].encode('ascii', 'replace').decode('ascii')
        if st != "pending" or con == "failure":
            print(f"  {icon} {safe_name} -> {st} ({con})")
    sys.stdout.flush()
    return run

def watch(run_id=None, max_wait_sec=900, interval=25):
    # Wait for run_id if not provided
    if not run_id:
        print("Waiting for GitHub Actions run to register...")
        for _ in range(10):
            run_id = get_latest_run_id()
            if run_id:
                break
            time.sleep(3)
            
    print(f"Tracking run ID: {run_id}")
    start = time.time()
    while time.time() - start < max_wait_sec:
        run = print_status(run_id)
        if run and run.get("status") == "completed":
            print(f"\nFinal Result: {run.get('conclusion')}")
            if run.get("conclusion") == "success":
                print("SUCCESS: Build completed and setup installer generated successfully!")
            else:
                print("FAILURE: Build failed. Check the logs on GitHub Actions.")
            return run.get("conclusion") == "success"
        time.sleep(interval)
    print("\nTimeout waiting for build to complete.")
    return False

if __name__ == "__main__":
    run_id = None
    if len(sys.argv) > 1 and not sys.argv[1].startswith("--"):
        run_id = sys.argv[1]
    watch(run_id)
