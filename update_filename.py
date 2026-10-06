import sys
f1 = 'lib/core/services/github_update_service.dart'
with open(f1, 'r', encoding='utf-8') as f:
    content = f.read()

old_filename = """      final fileName = widget.releaseInfo.assetName.isNotEmpty
          ? widget.releaseInfo.assetName
          : 'nayli-kiosk-update.exe';"""

new_filename = """      final String cleanVer = widget.releaseInfo.cleanVersion;
      final fileName = widget.releaseInfo.assetName.isNotEmpty
          ? '${cleanVer}-${widget.releaseInfo.assetName}'
          : 'nayli-kiosk-update-${cleanVer}.exe';"""

content = content.replace(old_filename, new_filename)
with open(f1, 'w', encoding='utf-8') as f:
    f.write(content)

print('Done!')
