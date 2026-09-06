import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/portal_service.dart';
import '../services/excel_export_service.dart';

class MarkAttendancePage extends StatefulWidget {
  final int teacherId;
  const MarkAttendancePage({super.key, required this.teacherId});
  @override
  State<MarkAttendancePage> createState() => _MarkAttendancePageState();
}
class _MarkAttendancePageState extends State<MarkAttendancePage> {
  final _service = PortalService();
  final _topic = TextEditingController();
  final Map<int, bool> _marks = {};
  List<Map<String, dynamic>> _students = [];
  bool _loading = true, _saving = false, _existing = false;
  String? _error;
  late DateTime _day;
  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _topic.dispose(); super.dispose(); }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    _day = DateTime.now();
    try {
      final students = await _service.students();
      final records = await _service.records(widget.teacherId, _day);
      final sessions = await _service.sessions(widget.teacherId, _day, _day);
      if (!mounted) return;
      setState(() {
        _students = students;
        _marks.clear();
        for (final student in students) {
          final id = student['student_id'] as int;
          _marks[id] = records.any((record) => record['student_id'] == id && record['status'] == 'Present');
        }
        _existing = sessions.isNotEmpty;
        _topic.text = _existing ? sessions.first['topic'] as String : '';
      });
    } catch (_) { if (mounted) setState(() => _error = 'Could not load attendance. Please retry.'); }
    finally { if (mounted) setState(() => _loading = false); }
  }
  Future<void> _submit() async {
    if (_saving) return;
    if (_topic.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the topic taught in this session.'))); return; }
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: Text(_existing ? 'Update today’s attendance?' : 'Submit attendance?'), content: Text('${_marks.values.where((v) => v).length} present, ${_marks.values.where((v) => !v).length} absent.\n${_existing ? 'This will update today’s saved session.' : 'The session will appear on your dashboard.'}'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm'))]));
    if (confirm != true || !mounted) return;
    setState(() => _saving = true);
    try {
      final id = await _service.submit(widget.teacherId, _topic.text, Map.of(_marks), _day);
      if (!mounted) return;
      setState(() => _existing = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance saved. Dashboard and absence counts are updated.')));
      final export = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Export attendance?'), content: const Text('Would you like an Excel copy of this session?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Export'))]));
      if (export == true) {
        try { await ExcelExportService().exportAttendance(id); }
        catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance is saved, but Excel export failed. Try exporting from history.'))); }
      }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')))); }
    finally { if (mounted) setState(() => _saving = false); }
  }
  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: TextButton(onPressed: _load, child: Text('$_error Retry')));
    final present = _marks.values.where((v) => v).length;
    return AbsorbPointer(absorbing: _saving, child: Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(DateFormat('EEEE, d MMM yyyy').format(_day), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text('${_students.length} students · $present present · ${_students.length - present} absent'),
        if (_existing) const Text('Today’s saved attendance is loaded.', style: TextStyle(color: Colors.teal)),
        const SizedBox(height: 16), TextField(controller: _topic, decoration: const InputDecoration(labelText: 'Topic taught', hintText: 'For example: Quadratic equations', border: OutlineInputBorder())),
      ])),
      Expanded(child: _students.isEmpty ? const Center(child: Text('Add students from Student Info first.')) : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: _students.length, itemBuilder: (context, index) {
        final student = _students[index]; final id = student['student_id'] as int;
        return Card(child: CheckboxListTile(secondary: const CircleAvatar(child: Icon(Icons.person_outline)), title: Text(student['name'] as String), value: _marks[id], onChanged: (value) => setState(() => _marks[id] = value ?? false)));
      })),
      SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _students.isEmpty || _saving ? null : _submit, icon: const Icon(Icons.save_outlined), label: Text(_saving ? 'Saving…' : _existing ? 'Update Attendance' : 'Submit Attendance'))))),
    ]));
  }
}

class AttendanceHistoryPage extends StatefulWidget {
  final int teacherId;
  final DateTime? initialDate;
  const AttendanceHistoryPage({super.key, required this.teacherId, this.initialDate});
  @override
  State<AttendanceHistoryPage> createState() => _AttendanceHistoryPageState();
}
class _AttendanceHistoryPageState extends State<AttendanceHistoryPage> {
  final _service = PortalService();
  late DateTime _day;
  late Future<List<dynamic>> _data;
  bool _exporting = false;
  @override
  void initState() { super.initState(); _day = widget.initialDate ?? DateTime.now(); _load(); }
  void _load() { _data = Future.wait([_service.sessions(widget.teacherId, _day, _day), _service.records(widget.teacherId, _day)]); }
  Future<void> _pick() async {
    final day = await showDatePicker(context: context, initialDate: _day, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (day != null && mounted) setState(() { _day = day; _load(); });
  }
  Future<void> _export(int id) async {
    setState(() => _exporting = true);
    try { await ExcelExportService().exportAttendance(id); }
    catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not export. Please try again.'))); }
    finally { if (mounted) setState(() => _exporting = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Attendance History'), actions: [IconButton(tooltip: 'Pick date', onPressed: _pick, icon: const Icon(Icons.calendar_month))]), body: Column(children: [
    ListTile(title: Text(DateFormat('EEEE, d MMM yyyy').format(_day)), trailing: TextButton(onPressed: _pick, child: const Text('Pick Date'))),
    Expanded(child: FutureBuilder<List<dynamic>>(future: _data, builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: TextButton(onPressed: () => setState(_load), child: const Text('Could not load history. Retry')));
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final sessions = snapshot.data![0] as List<Map<String, dynamic>>;
      final records = snapshot.data![1] as List<Map<String, dynamic>>;
      if (sessions.isEmpty) return const Center(child: Text('No attendance submitted for this date.'));
      final session = sessions.first;
      return ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Topic: ${(session['topic'] as String).isEmpty ? 'Not recorded' : session['topic']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text('${session['present']} present · ${(session['total'] as int) - (session['present'] as int)} absent'),
          TextButton.icon(onPressed: _exporting ? null : () => _export(session['session_id'] as int), icon: const Icon(Icons.download_outlined), label: Text(_exporting ? 'Exporting…' : 'Export to Excel')),
        ]))),
        for (final record in records) Card(child: ListTile(title: Text(record['name'] as String), trailing: Text(record['status'] as String, style: TextStyle(color: record['status'] == 'Present' ? Colors.teal.shade700 : Colors.red.shade700, fontWeight: FontWeight.bold)))),
      ]);
    })),
  ]));
}
