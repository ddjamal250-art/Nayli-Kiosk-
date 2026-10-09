import urllib.request
import json
import subprocess
import zipfile
import io

class NoAuthRedirectHandler(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        new_req = super().redirect_request(req, fp, code, msg, headers, newurl)
        if 'Authorization' in new_req.headers:
            del new_req.headers['Authorization']
        return new_req

def get_auth_token():
    try:
        out = subprocess.check_output(["git", "config", "--get", "remote.origin.url"], text=True)
        if "@github.com" in out and "://" in out:
            user_part = out.split("://")[1].split("@github.com")[0]
            if ":" in user_part:
                return user_part.split(":")[1].strip()
    except Exception:
        pass
    return None

tok = get_auth_token()
opener = urllib.request.build_opener(NoAuthRedirectHandler())

req = urllib.request.Request("https://api.github.com/repos/ddjamal250-art/Nayli-Kiosk-/actions/artifacts/11640406982/zip")
req.add_header("Authorization", f"Bearer {tok}")
try:
    with opener.open(req) as r:
        z = zipfile.ZipFile(io.BytesIO(r.read()))
        z.extractall("error_logs")
        print("Extracted to error_logs/")
except Exception as e:
    print(e)
