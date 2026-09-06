import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/portal_service.dart';

class StudentInfoPage extends StatefulWidget {
  final int teacherId;
  const StudentInfoPage({super.key, required this.teacherId});
  @override
  State<StudentInfoPage> createState() => _StudentInfoPageState();
}
class _StudentInfoPageState extends State<StudentInfoPage> {
  final _service = PortalService();
  late Future<List<Map<String, dynamic>>> _students;
  @override
  void initState() { super.initState(); _reload(); }
  void _reload() { _students = _service.students(); }
  Future<void> _remove(Map<String, dynamic> student) async {
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Remove student?'), content: Text('Remove ${student['name']} from the active list? Past attendance will be retained.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove'))]));
    if (confirm != true) return;
    try {
      await _service.removeStudent(student['student_id'] as int);
      if (mounted) setState(_reload);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not remove student. Please try again.')));
    }
  }
  Future<void> _open(Map<String, dynamic>? student) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => StudentProfilePage(teacherId: widget.teacherId, student: student)));
    if (mounted) setState(_reload);
  }
  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.all(16), child: Row(children: [const Expanded(child: Text('Students', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))), FilledButton.icon(onPressed: () => _open(null), icon: const Icon(Icons.add), label: const Text('Add Student'))])),
    Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(future: _students, builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: TextButton(onPressed: () => setState(_reload), child: const Text('Could not load students. Retry')));
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      if (snapshot.data!.isEmpty) return const Center(child: Text('Add your first student to get started.'));
      return ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: snapshot.data!.length, itemBuilder: (context, index) {
        final student = snapshot.data![index];
        return Card(child: ListTile(onTap: () => _open(student), leading: IconButton(tooltip: 'View student profile', icon: const CircleAvatar(child: Icon(Icons.person_outline)), onPressed: () => _open(student)), title: Text(student['name'] as String), trailing: IconButton(tooltip: 'Remove student', icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _remove(student))));
      });
    })),
  ]);
}

class StudentProfilePage extends StatefulWidget {
  final int teacherId;
  final Map<String, dynamic>? student;
  const StudentProfilePage({super.key, required this.teacherId, this.student});
  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
}
class _StudentProfilePageState extends State<StudentProfilePage> {
  final _service = PortalService();
  final _form = GlobalKey<FormState>();
  final Map<String, TextEditingController> _fields = {};
  bool _saving = false;
  bool _openingDialer = false;
  late Future<List<Map<String, dynamic>>> _absences;
  bool get _new => widget.student == null;
  @override
  void initState() {
    super.initState();
    for (final key in ['name', 'course', 'academic_year', 'contact']) {
      _fields[key] = TextEditingController(text: widget.student?[key] as String? ?? '');
    }
    _absences = _new ? Future.value(<Map<String, dynamic>>[]) : _service.absences(widget.teacherId, widget.student!['student_id'] as int);
  }
  @override
  void dispose() { for (final controller in _fields.values) { controller.dispose(); } super.dispose(); }
  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (_new) {
        await _service.addStudent(_fields.map((key, value) => MapEntry(key, value.text.trim())));
      } else {
        await _service.editStudent(widget.student!['student_id'] as int, _fields['contact']!.text.trim(), _fields['academic_year']!.text.trim());
      }
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_new ? 'Student added' : 'Profile updated'))); Navigator.pop(context); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally { if (mounted) setState(() => _saving = false); }
  }
  Future<void> _openDialer() async {
    if (_openingDialer || _saving) return;
    final number = _fields['contact']!.text.trim().replaceAll(RegExp(r'[\s().-]'), '');
    if (!RegExp(r'^\+?[0-9]+$').hasMatch(number)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a phone number with digits and an optional + country code.')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _openingDialer = true);
    try {
      final opened = await launchUrl(
        Uri(scheme: 'tel', path: number),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the phone app on this device.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the phone app. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _openingDialer = false);
    }
  }

  Widget _field(String key, String label, {bool fixed = false}) => Padding(padding: const EdgeInsets.only(bottom: 16), child: TextFormField(
    controller: _fields[key], enabled: !_saving && !(!_new && fixed),
    keyboardType: key == 'contact' ? TextInputType.phone : TextInputType.text,
    decoration: InputDecoration(labelText: label, hintText: 'Not provided', border: const OutlineInputBorder(), filled: !_new && fixed, fillColor: Colors.grey.shade100,
      suffixIcon: key == 'contact'
          ? ValueListenableBuilder<TextEditingValue>(
              valueListenable: _fields['contact']!,
              builder: (context, value, child) => IconButton(
                tooltip: 'Open phone keypad',
                icon: const Icon(Icons.phone_outlined),
                color: Colors.teal.shade700,
                onPressed: _saving || _openingDialer || value.text.trim().isEmpty
                    ? null
                    : _openDialer,
              ),
            )
          : null,
    ),
    validator: (value) { if ((value ?? '').trim().isEmpty && (_new || !fixed) && key != 'contact') return 'Please enter ${label.toLowerCase()}'; return null; },
  ));
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(_new ? 'Add Student' : 'Student Profile')), body: Form(key: _form, child: ListView(padding: const EdgeInsets.all(20), children: [
    const Center(child: CircleAvatar(radius: 34, child: Icon(Icons.person_outline, size: 36))), const SizedBox(height: 24),
    _field('name', 'Name', fixed: true), _field('course', 'Course', fixed: true), _field('academic_year', 'Academic year'), _field('contact', 'Contact (optional)'),
    if (!_new) FutureBuilder<List<Map<String, dynamic>>>(future: _absences, builder: (context, snapshot) {
      if (snapshot.hasError) return TextButton(onPressed: () => setState(() => _absences = _service.absences(widget.teacherId, widget.student!['student_id'] as int)), child: const Text('Could not load absences. Retry'));
      if (!snapshot.hasData) return const LinearProgressIndicator();
      final all = snapshot.data!;
      final monday = _service.monday(DateTime.now());
      final sunday = monday.add(const Duration(days: 7));
      final weekly = all.where((row) { final day = DateTime.parse(row['session_date'] as String); return !day.isBefore(monday) && day.isBefore(sunday); }).toList();
      return Card(color: Colors.grey.shade100, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${weekly.length} absences this week', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Text('Calculated from your submitted attendance', style: TextStyle(color: Colors.black54, fontSize: 12)), const SizedBox(height: 12),
        if (weekly.isEmpty) const Text('No recorded absences this week.'),
        for (final row in weekly) Text(DateFormat('EEEE, d MMM yyyy').format(DateTime.parse(row['session_date'] as String))),
        TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('All Absent Days')), body: all.isEmpty ? const Center(child: Text('No recorded absences.')) : ListView(children: [for (final row in all) ListTile(leading: const Icon(Icons.event_busy, color: Colors.red), title: Text(DateFormat('EEEE, d MMM yyyy').format(DateTime.parse(row['session_date'] as String))), subtitle: Text((row['topic'] as String).isEmpty ? 'Topic not recorded' : row['topic'] as String))])))), child: const Text('View all')),
      ])));
    }),
    const SizedBox(height: 16), FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : _new ? 'Add Student' : 'Save Changes')),
  ])));
}
