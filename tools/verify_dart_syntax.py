import sys

files = [
    'lib/core/data/sync_message_protocol.dart',
    'lib/core/data/local_sync_server.dart',
    'lib/core/data/smart_sync_client.dart',
    'lib/features/billing/presentation/bloc/billing_bloc.dart',
    'lib/features/billing/presentation/pages/desktop_pos_page.dart',
    'lib/core/utils/security_pin_helper.dart',
    'lib/features/billing/presentation/pages/cashier_shifts_page.dart',
    'lib/features/billing/presentation/pages/checkout_page.dart',
    'lib/features/billing/presentation/widgets/session_lock_overlay.dart',
    'lib/features/billing/presentation/widgets/universal_unit_selector_dialog.dart',
    'lib/features/product/data/product_integrity_service.dart',
    'lib/features/product/data/repositories/product_repository_impl.dart',
    'lib/features/product/domain/entities/product.dart',
    'lib/features/product/presentation/pages/add_product_page.dart',
    'lib/features/product/presentation/pages/edit_product_page.dart',
    'lib/features/product/presentation/pages/stock_in_page.dart',
    'lib/features/product/presentation/widgets/product_units_editor_widget.dart',
    'lib/features/product/presentation/widgets/quick_receive_modal.dart',
    'lib/features/shifts/data/shift_service.dart',
    'lib/features/shifts/data/staff_member_model.dart',
    'lib/features/shifts/data/staff_service.dart',
    'lib/features/shifts/presentation/pages/cashier_login_page.dart',
    'lib/features/shifts/presentation/pages/shifts_page.dart'
]

for f in files:
    with open(f, 'r', encoding='utf-8') as fp:
        content = fp.read()
    stack = []
    pairs = {')': '(', '}': '{', ']': '['}
    in_str = False
    str_char = ''
    is_raw_or_triple = False
    in_line_comment = False
    in_block_comment = False
    i = 0
    lines = 1
    err = None
    while i < len(content):
        c = content[i]
        if c == '\n':
            lines += 1
            in_line_comment = False
            i += 1
            continue
        if in_line_comment:
            i += 1
            continue
        if in_block_comment:
            if c == '*' and i + 1 < len(content) and content[i+1] == '/':
                in_block_comment = False
                i += 2
                continue
            i += 1
            continue
        if in_str:
            if c == '\\':
                i += 2
                continue
            if c == str_char:
                in_str = False
            i += 1
            continue
        if c == '/' and i + 1 < len(content):
            if content[i+1] == '/':
                in_line_comment = True
                i += 2
                continue
            elif content[i+1] == '*':
                in_block_comment = True
                i += 2
                continue
        if c in ("'", '"'):
            in_str = True
            str_char = c
            i += 1
            continue
        if c in ('(', '{', '['):
            stack.append((c, lines))
        elif c in (')', '}', ']'):
            if not stack:
                err = f'Unmatched closing {c} at line {lines}'
                break
            top, line_num = stack.pop()
            if top != pairs[c]:
                err = f'Mismatched {c} at line {lines}, expected {top} opened at {line_num}'
                break
        i += 1
    if not err and stack:
        err = f'Unclosed {stack[-1][0]} opened at line {stack[-1][1]}'
    if err:
        print(f'FAIL: {f} -> {err}')
    else:
        print(f'PASS: {f} (Lines: {lines})')
