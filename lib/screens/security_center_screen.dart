import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';

class SecurityCenterScreen extends StatefulWidget {
  const SecurityCenterScreen({super.key});

  @override
  State<SecurityCenterScreen> createState() => _SecurityCenterScreenState();
}

class _SecurityCenterScreenState extends State<SecurityCenterScreen> with SingleTickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late TabController _tabController;
  
  List<Map<String, dynamic>> _accessLogs = [];
  List<Map<String, dynamic>> _auditLogs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final access = await _dbHelper.getAccessLogs();
    final audit = await _dbHelper.getAuditLogs(limit: 200);
    setState(() {
      _accessLogs = access;
      _auditLogs = audit;
      _isLoading = false;
    });
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL': return Colors.red;
      case 'HIGH': return Colors.orange;
      case 'WARNING': return Colors.amber;
      case 'INFO': return Colors.blue;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Security Center'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF8E0E00), Color(0xFF1F1C18)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.security), text: 'Audit Log'),
            Tab(icon: Icon(Icons.login), text: 'Accessi Recenti'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
          )
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAuditLogList(),
                _buildAccessLogList(),
              ],
            ),
    );
  }

  Widget _buildAuditLogList() {
    if (_auditLogs.isEmpty) {
      return Center(child: Text("Nessun evento registrato."));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _auditLogs.length,
      itemBuilder: (context, index) {
        final log = _auditLogs[index];
        final String severity = log['severity'] ?? 'INFO';
        final String eventType = log['event_type'] ?? 'UNKNOWN';
        final String description = log['description'] ?? '';
        final String username = log['username'] ?? 'System';
        final String timestampStr = log['timestamp'] ?? '';

        String formattedDate = '';
        if (timestampStr.isNotEmpty) {
          final dt = DateTime.parse(timestampStr);
          formattedDate = DateFormat('HH:mm:ss - dd/MM/yyyy').format(dt);
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 2,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getSeverityColor(severity).withValues(alpha: 0.2),
              child: Icon(
                severity == 'CRITICAL' ? Icons.warning : Icons.info,
                color: _getSeverityColor(severity),
              ),
            ),
            title: Text(
              "[$eventType] $username",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description),
                SizedBox(height: 4),
                Text(
                  formattedDate,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildAccessLogList() {
    if (_accessLogs.isEmpty) {
      return Center(child: Text("Nessun accesso negli ultimi 7 giorni."));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _accessLogs.length,
      itemBuilder: (context, index) {
        final log = _accessLogs[index];
        final String username = log['username'] ?? 'Sconosciuto';
        final String eventType = log['event_type'] ?? 'login_success';
        final String deviceType = log['device_type'] ?? 'Sconosciuto';
        final String timestampStr = log['timestamp'] ?? '';

        String formattedDate = '';
        if (timestampStr.isNotEmpty) {
          final dt = DateTime.parse(timestampStr);
          formattedDate = DateFormat('HH:mm - dd/MM/yyyy').format(dt);
        }

        IconData deviceIcon = Icons.device_unknown;
        if (deviceType.contains('Cellulare')) {
          deviceIcon = Icons.phone_android;
        } else if (deviceType.contains('Computer')) {
          deviceIcon = Icons.computer;
        }

        bool isSuccess = eventType == 'login_success';

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isSuccess ? Colors.green[100] : Colors.red[100],
              child: Icon(
                isSuccess ? Icons.check_circle : Icons.error,
                color: isSuccess ? Colors.green : Colors.red,
              ),
            ),
            title: Text(
              "$username ${isSuccess ? 'entrato' : 'accesso fallito'} alle $formattedDate",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              "Dispositivo: $deviceType",
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
        );
      },
    );
  }
}



