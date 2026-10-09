with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = '''class _InvoicesScreenState extends State<InvoicesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AttachmentService _attachmentService = AttachmentService();
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;'''

replacement = '''class _InvoicesScreenState extends State<InvoicesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AttachmentService _attachmentService = AttachmentService();
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;
  InvoiceSortType _sortType = InvoiceSortType.number;
  bool _sortAscending = true;'''

content = content.replace(target, replacement)

with open('lib/screens/invoices_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
