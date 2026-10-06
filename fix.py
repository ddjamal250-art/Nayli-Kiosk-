import sys

# 1. Update pubspec.yaml
with open('pubspec.yaml', 'r', encoding='utf-8') as f:
    content = f.read()
content = content.replace('version: 2.4.6+22', 'version: 2.4.7+23')
with open('pubspec.yaml', 'w', encoding='utf-8') as f:
    f.write(content)

# 2. Update build_windows_setup.yml to use dynamic version
yml_file = '.github/workflows/build_windows_setup.yml'
with open(yml_file, 'r', encoding='utf-8') as f:
    yml = f.read()

old_release = """      - name: Publish Direct Download GitHub Release
        uses: softprops/action-gh-release@v2.0.9
        if: github.ref == 'refs/heads/main' || github.ref == 'refs/heads/master'
        with:
          tag_name: v2.4.6
          name: "Nayli Kiosk Desktop POS v2.4.6 (Official Release)"
          draft: false
          prerelease: false
          generate_release_notes: false
          body: |"""

new_release = """      - name: Determine Tag Name
        id: tag_info
        shell: bash
        run: |
          VERSION=$(grep '^version:' pubspec.yaml | head -n1 | cut -d' ' -f2 | cut -d'+' -f1)
          echo "tag=v${VERSION}" >> $GITHUB_OUTPUT

      - name: Publish Direct Download GitHub Release
        uses: softprops/action-gh-release@v2.0.9
        if: github.ref == 'refs/heads/main' || github.ref == 'refs/heads/master'
        with:
          tag_name: ${{ steps.tag_info.outputs.tag }}
          name: "Nayli Kiosk Desktop POS ${{ steps.tag_info.outputs.tag }} (Official Release)"
          draft: false
          prerelease: false
          generate_release_notes: false
          body: |"""

yml = yml.replace(old_release, new_release)

# Replace all hardcoded v2.4.6 inside the body as well!
yml = yml.replace('Nayli Kiosk Desktop POS v2.4.6 - ', 'Nayli Kiosk Desktop POS ${{ steps.tag_info.outputs.tag }} - ')
yml = yml.replace('download/v2.4.6/Nayli-Kiosk-Desktop-Setup', 'download/${{ steps.tag_info.outputs.tag }}/Nayli-Kiosk-Desktop-Setup')
yml = yml.replace('download/v2.4.6/Nayli-Kiosk-Desktop-Portable', 'download/${{ steps.tag_info.outputs.tag }}/Nayli-Kiosk-Desktop-Portable')
yml = yml.replace('(v2.4.6):', '(${{ steps.tag_info.outputs.tag }}):')

with open(yml_file, 'w', encoding='utf-8') as f:
    f.write(yml)

print('Done!')
