import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/portal_service.dart';
import 'login_screen.dart';
import 'student_info_screen.dart';
import 'mark_attendance_screen.dart';

class DashboardScreen extends StatefulWidget {
  final int teacherId;
  const DashboardScreen({super.key, required this.teacherId});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _page = 0;
  final _titles = ['Dashboard', 'Student Info', 'Mark Attendance'];
  void _select(int page) {
    Navigator.pop(context);
    setState(() => _page = page);
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_titles[_page]), actions: [
      if (_page == 2) IconButton(tooltip: 'Attendance history', icon: const Icon(Icons.calendar_month), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceHistoryPage(teacherId: widget.teacherId)))),
    ]),
    drawer: Drawer(child: SafeArea(child: Column(children: [
      const ListTile(contentPadding: EdgeInsets.all(24), leading: Icon(Icons.school, color: Colors.teal), title: Text('Attendance Portal', style: TextStyle(fontWeight: FontWeight.bold))),
      const Divider(),
      for (var i = 0; i < _titles.length; i++) ListTile(selected: _page == i, leading: Icon([Icons.dashboard_outlined, Icons.people_outline, Icons.fact_check_outlined][i]), title: Text(_titles[i]), onTap: () => _select(i)),
      const Spacer(), const Divider(),
      ListTile(leading: const Icon(Icons.logout), title: const Text('Logout'), onTap: () {
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
      }),
    ]))),
    body: switch (_page) {
      1 => StudentInfoPage(teacherId: widget.teacherId),
      2 => MarkAttendancePage(teacherId: widget.teacherId),
      _ => WeeklyDashboard(teacherId: widget.teacherId),
    },
  );
}

class WeeklyDashboard extends StatefulWidget {
  final int teacherId;
  const WeeklyDashboard({super.key, required this.teacherId});
  @override
  State<WeeklyDashboard> createState() => _WeeklyDashboardState();
}
class _WeeklyDashboardState extends State<WeeklyDashboard> {
  final _service = PortalService();
  late DateTime _week;
  late Future<List<dynamic>> _data;
  @override
  void initState() { super.initState(); _week = _service.monday(DateTime.now()); _load(); }
  void _load() {
    _data = Future.wait([_service.teacher(widget.teacherId), _service.sessions(widget.teacherId, _week, _week.add(const Duration(days: 6)))]);
  }
  void _move(int days) { setState(() { _week = _week.add(Duration(days: days)); _load(); }); }
  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: TextButton(onPressed: () => setState(_load), child: const Text('Could not load dashboard. Retry')));
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final teacher = snapshot.data![0] as Map<String, dynamic>;
      final sessions = snapshot.data![1] as List<Map<String, dynamic>>;
      final currentWeek = _service.monday(DateTime.now());
      return RefreshIndicator(onRefresh: () async { setState(_load); await _data; }, child: ListView(padding: const EdgeInsets.all(16), physics: const AlwaysScrollableScrollPhysics(), children: [
        Text('Hello, ${teacher['name']}', style: Theme.of(context).textTheme.headlineSmall),
        Text('${teacher['subject_name']}', style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 16),
        Row(children: [IconButton(tooltip: 'Previous week', onPressed: () => _move(-7), icon: const Icon(Icons.chevron_left)), Expanded(child: Text('${DateFormat('d MMM').format(_week)} – ${DateFormat('d MMM yyyy').format(_week.add(const Duration(days: 6)))}', textAlign: TextAlign.center)), IconButton(tooltip: 'Next week', onPressed: _week.isBefore(currentWeek) ? () => _move(7) : null, icon: const Icon(Icons.chevron_right))]),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${sessions.length} classes taken this week', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8), const Text('Attendance percentage'), const SizedBox(height: 16),
          WeeklyBars(week: _week, sessions: sessions),
          const SizedBox(height: 12), const Text('— = No session. 0% = A saved session with everyone absent.', style: TextStyle(fontSize: 12, color: Colors.black54)),
        ]))),
        const SizedBox(height: 20), const Text('Topics & sessions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
        if (sessions.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('No sessions this week. Submit attendance to add your first session.')),
        for (final session in sessions) Card(child: ListTile(isThreeLine: true,
          title: Text(DateFormat('EEEE, d MMM').format(DateTime.parse(session['session_date'] as String))),
          subtitle: Text('Topic: ${(session['topic'] as String).isEmpty ? 'Not recorded' : session['topic']}\n${session['present']} present · ${(session['total'] as int) - (session['present'] as int)} absent'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceHistoryPage(teacherId: widget.teacherId, initialDate: DateTime.parse(session['session_date'] as String)))),
        )),
      ]));
    },
  );
}

class WeeklyBars extends StatelessWidget {
  final DateTime week;
  final List<Map<String, dynamic>> sessions;
  const WeeklyBars({super.key, required this.week, required this.sessions});
  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 206, child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(top: 20), child: SizedBox(width: 38, height: 150, child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [for (final label in ['100%', '75%', '50%', '25%', '0%']) Text(label, style: const TextStyle(fontSize: 10))]))),
      Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: List.generate(7, (index) {
        final day = week.add(Duration(days: index));
        final rows = sessions.where((s) => s['session_date'] == DateFormat('yyyy-MM-dd').format(day));
        final row = rows.isEmpty ? null : rows.first;
        final total = row == null ? 0 : row['total'] as int;
        final percent = total == 0 ? 0.0 : (row!['present'] as int) * 100.0 / total;
        final label = row == null ? '—' : '${percent.round()}%';
        return Expanded(child: Semantics(label: '${DateFormat('EEEE').format(day)}: ${row == null ? 'No session' : label}', child: Column(children: [
          Text(label, style: const TextStyle(fontSize: 10)),
          const SizedBox(height: 6),
          SizedBox(height: 150, child: Stack(alignment: Alignment.bottomCenter, children: [
            Container(margin: const EdgeInsets.symmetric(horizontal: 7), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(5))),
            Container(height: percent * 1.5, margin: const EdgeInsets.symmetric(horizontal: 7), decoration: BoxDecoration(color: Colors.teal.shade400, borderRadius: BorderRadius.circular(5))),
          ])),
          const SizedBox(height: 8), Text(DateFormat('E').format(day), style: const TextStyle(fontSize: 11)),
        ])));
      }))),
    ]));
  }
}
