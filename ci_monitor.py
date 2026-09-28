import urllib.request
import json
import time
import sys

REPO = "ddjamal250-art/Nayli-Kiosk-"
HEADERS = {
    "User-Agent": "Nayli-Kiosk-Monitor",
    "Accept": "application/vnd.github+json"
}

def get_latest_runs():
    url = f"https://api.github.com/repos/{REPO}/actions/runs?per_page=5"
    req = urllib.request.Request(url, headers=HEADERS)
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode())
            return data.get("workflow_runs", [])
    except Exception as e:
        print(f"Error fetching runs: {e}")
        return []

def monitor_latest(target_commit_sha=None):
    print("Fetching GitHub Actions build status...")
    runs = get_latest_runs()
    if not runs:
        print("No runs found.")
        return

    latest = runs[0]
    print(f"Latest Run ID: {latest['id']}")
    print(f"Workflow: {latest['name']}")
    print(f"Status: {latest['status']}")
    print(f"Conclusion: {latest['conclusion']}")
    print(f"HTML URL: {latest['html_url']}")
    print(f"Commit: {latest['head_commit']['id'][:7]} - {latest['head_commit']['message'].strip()[:60]}")

if __name__ == "__main__":
    monitor_latest()
