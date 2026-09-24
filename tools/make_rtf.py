import os

with open("windows/License.txt", "r", encoding="utf-8-sig") as f:
    text = f.read()

rtf_header = r"""{\rtf1\fbidis\ansi\deff0{\fonttbl{\f0\fnil\fcharset178 Segoe UI;}{\f1\fnil\fcharset0 Segoe UI;}}
{\colortbl ;\red10\green80\blue140;\red30\green30\blue30;}
\viewkind4\uc1
"""

rtf_body = []
for line in text.splitlines():
    line = line.strip()
    if not line:
        rtf_body.append(r"\pard\rtlpar\qr\f0\fs20\par")
        continue

    is_main_title = "اتفاقية ترخيص" in line or "Nayli Market POS" in line
    is_section_header = any(line.startswith(f"{i}.") for i in range(1, 10))

    escaped_line = []
    for ch in line:
        code = ord(ch)
        if code > 127:
            escaped_line.append(f"\\u{code}?")
        elif ch in ["\\", "{", "}"]:
            escaped_line.append("\\" + ch)
        else:
            escaped_line.append(ch)
    
    escaped_str = "".join(escaped_line)

    if is_main_title:
        rtf_body.append(rf"\pard\rtlpar\qr\lang1025\b\cf1\f0\fs24 {escaped_str}\b0\cf2\par")
    elif is_section_header:
        rtf_body.append(rf"\pard\rtlpar\qr\lang1025\b\cf1\f0\fs22 {escaped_str}\b0\cf2\par")
    else:
        rtf_body.append(rf"\pard\rtlpar\qr\lang1025\cf2\f0\fs20 {escaped_str}\par")

full_rtf = rtf_header + "\n".join(rtf_body) + "\n}"

with open("windows/License.rtf", "w", encoding="ascii") as f:
    f.write(full_rtf)

print(f"Generated windows/License.rtf successfully ({len(full_rtf)} bytes)")
