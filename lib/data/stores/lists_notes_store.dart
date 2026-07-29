import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/lists_notes.dart';
import 'persistence.dart';
import 'id_gen.dart';

/// Owns lists and notes (PRD 6.x).
class ListsNotesStore extends ChangeNotifier {
  ListsNotesStore() {
    _load();
  }

  static const String _key = 'lists_notes';

  final List<TaskList> _lists = <TaskList>[];
  final List<Note> _notes = <Note>[];

  bool _load() {
    final Map<String, dynamic>? j = Persistence.load(_key);
    if (j == null) return false;
    _lists.addAll((j['lists'] as List<dynamic>)
        .map((dynamic l) => TaskList.fromJson(l as Map<String, dynamic>)));
    _notes.addAll((j['notes'] as List<dynamic>)
        .map((dynamic n) => Note.fromJson(n as Map<String, dynamic>)));
    return true;
  }

  void flush() {
    Persistence.save(_key, <String, dynamic>{
      'lists': _lists.map((TaskList l) => l.toJson()).toList(),
      'notes': _notes.map((Note n) => n.toJson()).toList(),
    });
  }

  @override
  void notifyListeners() {
    flush();
    super.notifyListeners();
  }

  /// Item edits must go through the store so listeners actually rebuild.
  void updateItem(ChecklistItem item, {String? text, String? note}) {
    if (text != null) item.text = text;
    if (note != null) item.note = note;
    notifyListeners();
  }

  List<TaskList> get lists => List<TaskList>.unmodifiable(_lists);
  List<Note> get notes => List<Note>.unmodifiable(_notes);

  /// Overall checked-item ratio across every list with at least one item.
  /// Feeds [ScoreEngine] — see `score_engine.dart`.
  double get checklistCompletionRate {
    final int total = _lists.fold<int>(0, (int s, TaskList l) => s + l.total);
    if (total == 0) return 1;
    final int done =
        _lists.fold<int>(0, (int s, TaskList l) => s + l.doneCount);
    return done / total;
  }

  bool get hasChecklistItems =>
      _lists.any((TaskList l) => l.total > 0);

  TaskList? listById(String id) {
    for (final TaskList l in _lists) {
      if (l.id == id) return l;
    }
    return null;
  }

  Note? noteById(String id) {
    for (final Note n in _notes) {
      if (n.id == id) return n;
    }
    return null;
  }

  /// PRD 6.1 FR1 — pinned items ignore the active filter, by design.
  List<TaskList> get pinnedLists =>
      _lists.where((TaskList l) => l.pinned).toList();

  List<TaskList> filteredLists(ListType? type) => type == null
      ? _lists.where((TaskList l) => !l.pinned).toList()
      : _lists.where((TaskList l) => !l.pinned && l.type == type).toList();

  List<Note> get pinnedNotes => _notes.where((Note n) => n.pinned).toList();

  List<Note> filteredNotes(NoteCategory? cat) {
    final List<Note> list = cat == null
        ? _notes.where((Note n) => !n.pinned).toList()
        : _notes.where((Note n) => !n.pinned && n.category == cat).toList();
    list.sort((Note a, Note b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  // ---- list mutations ---------------------------------------------------

  void addList(TaskList l) {
    _lists.add(l);
    notifyListeners();
  }

  void updateList(TaskList l) {
    final int i = _lists.indexWhere((TaskList x) => x.id == l.id);
    if (i >= 0) _lists[i] = l;
    notifyListeners();
  }

  void deleteList(String id) {
    _lists.removeWhere((TaskList l) => l.id == id);
    notifyListeners();
  }

  void togglePinList(TaskList l) {
    l.pinned = !l.pinned;
    notifyListeners();
  }

  void toggleItem(TaskList list, ChecklistItem item) {
    item.done = !item.done;
    notifyListeners();
  }

  void addItem(TaskList list, String text, {int sectionIndex = 0}) {
    if (text.trim().isEmpty) return;
    if (list.sections.isEmpty) list.sections.add(ListSection(name: ''));
    final int idx = sectionIndex.clamp(0, list.sections.length - 1);
    list.sections[idx]
        .items
        .add(ChecklistItem(id: IdGen.next('item'), text: text.trim()));
    notifyListeners();
  }

  /// PRD 6.2 AC2 — deleting the last item keeps a NAMED section (so the user
  /// can keep adding to it) but removes an unnamed placeholder section.
  void deleteItem(TaskList list, ChecklistItem item) {
    for (final ListSection s in list.sections) {
      s.items.removeWhere((ChecklistItem i) => i.id == item.id);
    }
    list.sections.removeWhere(
        (ListSection s) => s.items.isEmpty && s.name.trim().isEmpty && list.sections.length > 1);
    notifyListeners();
  }

  void addSection(TaskList list, String name) {
    list.sections.add(ListSection(name: name));
    notifyListeners();
  }

  // ---- note mutations ---------------------------------------------------

  void addNote(Note n) {
    _notes.add(n);
    notifyListeners();
  }

  void updateNote(Note n) {
    final int i = _notes.indexWhere((Note x) => x.id == n.id);
    if (i >= 0) {
      n.updatedAt = DateTime.now();
      _notes[i] = n;
    }
    notifyListeners();
  }

  void deleteNote(String id) {
    _notes.removeWhere((Note n) => n.id == id);
    notifyListeners();
  }

  void togglePinNote(Note n) {
    n.pinned = !n.pinned;
    notifyListeners();
  }

  void toggleNoteAction(Note n, ChecklistItem item) {
    item.done = !item.done;
    notifyListeners();
  }

  /// Plain-text rendering used by Copy text / Share / Export (PRD 6.5 AC2) —
  /// deliberately includes the action items, not just the body.
  String noteAsPlainText(Note n) {
    final StringBuffer b = StringBuffer()
      ..writeln(n.title)
      ..writeln('')
      ..writeln(n.body);
    if (n.actionItems.isNotEmpty) {
      b..writeln('')..writeln('Action items:');
      for (final ChecklistItem i in n.actionItems) {
        b.writeln('${i.done ? '[x]' : '[ ]'} ${i.text}');
      }
    }
    if (n.calloutTitle != null) {
      b..writeln('')..writeln('${n.calloutTitle}: ${n.calloutBody ?? ''}');
    }
    return b.toString();
  }

  /// Plain-text rendering of a list, for Copy / Share.
  String listAsPlainText(TaskList l) {
    final StringBuffer b = StringBuffer()
      ..writeln(l.name)
      ..writeln('');
    for (final ListSection s in l.sections) {
      if (s.name.isNotEmpty) {
        b..writeln(s.name)..writeln('');
      }
      for (final ChecklistItem i in s.items) {
        b.writeln('${i.done ? '[x]' : '[ ]'} ${i.text}');
      }
      b.writeln('');
    }
    b.writeln('${l.doneCount} of ${l.total} done');
    return b.toString();
  }

  void seed() {
    _lists.addAll(<TaskList>[
      TaskList(
        id: 'list_morning',
        name: 'Morning routine',
        type: ListType.todo,
        colorValue: 0xFF185FA5,
        pinned: true,
        sections: <ListSection>[
          ListSection(name: '', items: <ChecklistItem>[
            ChecklistItem(id: 'i1', text: 'Morning jog', done: true),
            ChecklistItem(id: 'i2', text: 'Take Metformin', done: true),
            ChecklistItem(id: 'i3', text: 'Drink 2 glasses water'),
            ChecklistItem(id: 'i4', text: 'Stretch 5 min'),
            ChecklistItem(id: 'i5', text: 'Plan the day'),
          ]),
        ],
      ),
      TaskList(
        id: 'list_groceries',
        name: 'Weekly groceries',
        type: ListType.shopping,
        colorValue: 0xFF854F0B,
        pinned: true,
        linkedModule: 'Expenses',
        linkedLabel: 'Big Basket',
        sections: <ListSection>[
          ListSection(name: '', items: <ChecklistItem>[
            ChecklistItem(id: 'g1', text: 'Milk 2L', done: true),
            ChecklistItem(id: 'g2', text: 'Spinach'),
            ChecklistItem(id: 'g3', text: 'Eggs', done: true),
            ChecklistItem(id: 'g4', text: 'Atta 5kg'),
            ChecklistItem(id: 'g5', text: 'Olive oil'),
            ChecklistItem(id: 'g6', text: 'Curd'),
            ChecklistItem(id: 'g7', text: 'Bananas'),
            ChecklistItem(id: 'g8', text: 'Coffee beans'),
          ]),
        ],
      ),
      TaskList(
        id: 'list_doctor',
        name: 'Doctor visit checklist',
        type: ListType.checklist,
        colorValue: 0xFF534AB7,
        linkedModule: 'Health',
        linkedLabel: 'Dr. Mehta appointment',
        sections: <ListSection>[
          ListSection(name: 'Before visit', items: <ChecklistItem>[
            ChecklistItem(id: 'd1', text: 'Carry past prescriptions', done: true),
            ChecklistItem(id: 'd2', text: 'Blood report printout', done: true),
            ChecklistItem(id: 'd3', text: 'Insurance card', done: true),
          ]),
          ListSection(name: 'Questions to ask', items: <ChecklistItem>[
            ChecklistItem(
                id: 'd4',
                text: 'Ask about HbA1c results',
                note: 'was 6.8% last report'),
            ChecklistItem(id: 'd5', text: 'Discuss Metformin dosage'),
            ChecklistItem(id: 'd6', text: 'Ask about side effects of Amlodipine'),
            ChecklistItem(id: 'd7', text: 'Next test schedule'),
            ChecklistItem(id: 'd8', text: 'Diet recommendations'),
          ]),
        ],
      ),
      TaskList(
        id: 'list_trip',
        name: 'Trip packing · Delhi',
        type: ListType.custom,
        colorValue: 0xFF0F6E56,
        sections: <ListSection>[
          ListSection(name: '', items: <ChecklistItem>[
            ChecklistItem(id: 'p1', text: 'Passport', done: true),
            ChecklistItem(id: 'p2', text: 'Charger', done: true),
            ChecklistItem(id: 'p3', text: 'Medicines', done: true),
            ChecklistItem(id: 'p4', text: 'Formal shirt', done: true),
            ChecklistItem(id: 'p5', text: 'Laptop', done: true),
            ChecklistItem(id: 'p6', text: 'Umbrella'),
            ChecklistItem(id: 'p7', text: 'Sunglasses'),
          ]),
        ],
      ),
      TaskList(
        id: 'list_medicine',
        name: 'Medicine restock',
        type: ListType.shopping,
        colorValue: 0xFF854F0B,
        linkedModule: 'Reminders',
        linkedLabel: 'Metformin 500mg',
        sections: <ListSection>[
          ListSection(name: '', items: <ChecklistItem>[
            ChecklistItem(id: 'm1', text: 'Metformin 500mg x30'),
            ChecklistItem(id: 'm2', text: 'Vitamin D3'),
            ChecklistItem(id: 'm3', text: 'Eye drops'),
          ]),
        ],
      ),
      TaskList(
        id: 'list_repairs',
        name: 'Home repairs',
        type: ListType.todo,
        colorValue: 0xFFA32D2D,
        sections: <ListSection>[
          ListSection(name: '', items: <ChecklistItem>[
            ChecklistItem(id: 'h1', text: 'Fix kitchen tap', done: true),
            ChecklistItem(id: 'h2', text: 'Paint balcony railing', done: true),
            ChecklistItem(id: 'h3', text: 'Service AC'),
            ChecklistItem(id: 'h4', text: 'Replace door handle'),
            ChecklistItem(id: 'h5', text: 'Seal bathroom grout'),
          ]),
        ],
      ),
    ]);

    final DateTime now = DateTime.now();
    _notes.addAll(<Note>[
      Note(
        id: 'note_mehta',
        title: 'Dr. Mehta visit summary',
        body: 'Discussed HbA1c of 6.8% (rising trend). Dr Mehta advised reducing '
            'sugar and refined carbs. Metformin dose stays at 500mg twice daily.',
        createdAt: now.subtract(const Duration(days: 1)),
        category: NoteCategory.health,
        pinned: true,
        actionItems: <ChecklistItem>[
          ChecklistItem(id: 'a1', text: 'Book blood test before 15 Jul'),
          ChecklistItem(id: 'a2', text: 'Walk 30 min after dinner daily'),
          ChecklistItem(id: 'a3', text: 'Follow-up in 3 months'),
        ],
        links: <NoteLink>[
          NoteLink(module: 'Health', label: 'CBC Panel report', targetId: 'rep_cbc'),
          NoteLink(
              module: 'Planner',
              label: 'Dr. Mehta appointment',
              targetId: 'ev_drmehta'),
        ],
        calloutTitle: 'Prescription',
        calloutBody: 'Metformin 500mg · Vitamin D3 · unchanged',
      ),
      Note(
        id: 'note_budget',
        title: 'Budget planning — next quarter',
        body: 'Rent increases Rs 500 from next month. Need to cut food delivery '
            'spend. Target savings Rs 50,000 by end of quarter.',
        createdAt: now.subtract(const Duration(days: 3)),
        category: NoteCategory.finance,
      ),
      Note(
        id: 'note_reading',
        title: 'Reading list ideas',
        body: 'Atomic Habits, Deep Work, The Psychology of Money. '
            'Also check recommendation on Goodreads.',
        createdAt: now.subtract(const Duration(days: 5)),
        category: NoteCategory.personal,
      ),
      Note(
        id: 'note_side',
        title: 'Side project ideas',
        body: '1. Freelance dashboard tool 2. Local delivery aggregator '
            '3. Study app for competitive exams.',
        createdAt: now.subtract(const Duration(days: 8)),
        category: NoteCategory.work,
      ),
      Note(
        id: 'note_random',
        title: 'Random thoughts',
        body: 'Need to call Mom this weekend. Check if passport is still valid. '
            'Book eye test appointment.',
        createdAt: now.subtract(const Duration(days: 11)),
      ),
    ]);
  }
}
