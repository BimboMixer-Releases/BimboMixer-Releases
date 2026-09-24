import re

def add_open_dialog(file_path, class_name, state_class, dialog_method):
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    # 1. Update constructor
    old_constructor = f"class {class_name} extends StatefulWidget {{\n  const {class_name}({{super.key}});"
    new_constructor = f"class {class_name} extends StatefulWidget {{\n  final bool openDialog;\n  const {class_name}({{super.key, this.openDialog = false}});"
    
    if "openDialog" not in content:
        content = content.replace(old_constructor, new_constructor)
        
        # 2. Update initState
        init_state_pattern = r"(void initState\(\)\s*\{\s*super\.initState\(\);)"
        
        if class_name == "DeadlinesScreen":
            dialog_call = f"        if (widget.openDialog) {dialog_method}();"
        else:
            dialog_call = f"        if (widget.openDialog) {dialog_method}();"

        init_state_replacement = rf"\1\n    WidgetsBinding.instance.addPostFrameCallback((_) {{\n{dialog_call}\n    }});"
        
        content = re.sub(init_state_pattern, init_state_replacement, content)
        
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"Updated {file_path}")
    else:
        print(f"Already updated {file_path}")

add_open_dialog("lib/screens/invoices_screen.dart", "InvoicesScreen", "_InvoicesScreenState", "_showInvoiceDialog")
add_open_dialog("lib/screens/deadlines_screen.dart", "DeadlinesScreen", "_DeadlinesScreenState", "_showDeadlineDialog")
add_open_dialog("lib/screens/quotes_screen.dart", "QuotesScreen", "_QuotesScreenState", "_showQuoteDialog")
