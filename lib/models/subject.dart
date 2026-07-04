// This file represents ONE Subject (like "Maths" or "Physics")
// Think of it as a simple container that holds subject info

class Subject {
  // subjectId is null when we're creating a NEW subject (SQLite gives it an ID automatically)
  final int? subjectId;

  // subjectName is required - every subject must have a name
  final String subjectName;

  // Constructor - this is how we create a new Subject object
  // Example: Subject(subjectName: "Maths")
  const Subject({this.subjectId, required this.subjectName});

  // Converts this Subject into a Map so SQLite can save it
  // SQLite doesn't understand Dart objects, only Maps (key-value pairs)
  Map<String, dynamic> toMap() {
    return {'subject_id': subjectId, 'subject_name': subjectName};
  }

  // Converts data coming FROM SQLite back into a Subject object
  // "factory" just means: this creates and returns a new Subject
  factory Subject.fromMap(Map<String, dynamic> map) {
    return Subject(
      subjectId: map['subject_id'] as int?,
      subjectName: map['subject_name'] as String,
    );
  }

  // Just so we can print a Subject nicely for debugging (optional but helpful)
  @override
  String toString() => 'Subject(id: $subjectId, name: $subjectName)';
}
