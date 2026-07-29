import 'package:flutter/material.dart';
import 'entity_ref.dart';
import 'enums.dart';

class ChecklistItem {
  ChecklistItem({
    required this.id,
    required this.text,
    this.done = false,
    this.note = '',
  });

  final String id;
  String text;
  bool done;
  String note;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'text': text,
        'done': done,
        'note': note,
      };

  factory ChecklistItem.fromJson(Map<String, dynamic> j) => ChecklistItem(
        id: j['id'] as String,
        text: j['text'] as String,
        done: j['done'] as bool? ?? false,
        note: j['note'] as String? ?? '',
      );
}

class ListSection {
  ListSection({required this.name, List<ChecklistItem>? items})
      : items = items ?? <ChecklistItem>[];

  String name;
  final List<ChecklistItem> items;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'items': items.map((ChecklistItem i) => i.toJson()).toList(),
      };

  factory ListSection.fromJson(Map<String, dynamic> j) => ListSection(
        name: j['name'] as String,
        items: (j['items'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic i) => ChecklistItem.fromJson(i as Map<String, dynamic>))
            .toList(),
      );
}

/// A to-do / shopping / checklist / custom list (PRD 6.1-6.3).
class TaskList {
  TaskList({
    required this.id,
    required this.name,
    required this.type,
    this.colorValue = 0xFF185FA5,
    this.pinned = false,
    this.linkedModule,
    this.linkedLabel,
    this.shared = false,
    List<ListSection>? sections,
  }) : sections = sections ?? <ListSection>[ListSection(name: '')];

  final String id;
  String name;
  ListType type;
  int colorValue;
  bool pinned;

  /// PRD G.4 — cross-module link shown as a tappable badge.
  String? linkedModule;
  String? linkedLabel;
  bool shared;
  final List<ListSection> sections;

  Color get color => Color(colorValue);

  List<ChecklistItem> get allItems =>
      sections.expand((ListSection s) => s.items).toList();
  int get total => allItems.length;
  int get doneCount => allItems.where((ChecklistItem i) => i.done).length;
  double get progress => total == 0 ? 0 : doneCount / total;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'type': type.index,
        'colorValue': colorValue,
        'pinned': pinned,
        'linkedModule': linkedModule,
        'linkedLabel': linkedLabel,
        'shared': shared,
        'sections': sections.map((ListSection s) => s.toJson()).toList(),
      };

  factory TaskList.fromJson(Map<String, dynamic> j) => TaskList(
        id: j['id'] as String,
        name: j['name'] as String,
        type: ListType.values[j['type'] as int],
        colorValue: j['colorValue'] as int? ?? 0xFF185FA5,
        pinned: j['pinned'] as bool? ?? false,
        linkedModule: j['linkedModule'] as String?,
        linkedLabel: j['linkedLabel'] as String?,
        shared: j['shared'] as bool? ?? false,
        sections: (j['sections'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic s) => ListSection.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

class NoteLink {
  NoteLink({required this.module, required this.label, this.targetId, EntityRef? ref})
      : ref = ref ?? _inferRef(module, targetId);

  final String module;

  /// Fallback label shown only when [ref] can't resolve (e.g. a link created
  /// before the entity-linking system existed, targeting a module with no
  /// registered [EntityType]). Live links resolve their label from [ref]
  /// instead, so a rename of the target is reflected automatically.
  final String label;
  final String? targetId;

  /// Typed, id-based pointer used for live resolution. Null for links whose
  /// module has no corresponding [EntityType] (nothing to migrate onto).
  final EntityRef? ref;

  static EntityRef? _inferRef(String module, String? targetId) {
    if (targetId == null) return null;
    final EntityType? type = switch (module) {
      'Health' => EntityType.labReport,
      'Planner' => EntityType.plannerEvent,
      'Expenses' => EntityType.expenseTransaction,
      'Reminders' => EntityType.reminder,
      _ => null,
    };
    return type == null ? null : EntityRef(type, targetId);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'module': module,
        'label': label,
        'targetId': targetId,
      };

  factory NoteLink.fromJson(Map<String, dynamic> j) => NoteLink(
        module: j['module'] as String,
        label: j['label'] as String,
        targetId: j['targetId'] as String?,
      );
}

/// A free-form note with optional structured action items (PRD 6.4-6.6).
class Note {
  Note({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    DateTime? updatedAt,
    this.category = NoteCategory.uncategorised,
    this.pinned = false,
    List<ChecklistItem>? actionItems,
    List<NoteLink>? links,
    this.calloutTitle,
    this.calloutBody,
    List<String>? attachmentPaths,
  })  : updatedAt = updatedAt ?? createdAt,
        actionItems = actionItems ?? <ChecklistItem>[],
        links = links ?? <NoteLink>[],
        attachmentPaths = attachmentPaths ?? <String>[];

  final String id;
  String title;
  String body;
  final DateTime createdAt;
  DateTime updatedAt;
  NoteCategory category;
  bool pinned;

  /// PRD 6.5 FR1 — action items are modelled explicitly, not faked in markdown.
  final List<ChecklistItem> actionItems;
  final List<NoteLink> links;
  String? calloutTitle;
  String? calloutBody;
  final List<String> attachmentPaths;

  int get wordCount =>
      body.trim().isEmpty ? 0 : body.trim().split(RegExp(r'\s+')).length;

  String get preview => body.replaceAll('\n', ' ').trim();

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'category': category.index,
        'pinned': pinned,
        'actionItems':
            actionItems.map((ChecklistItem i) => i.toJson()).toList(),
        'links': links.map((NoteLink l) => l.toJson()).toList(),
        'calloutTitle': calloutTitle,
        'calloutBody': calloutBody,
        'attachmentPaths': attachmentPaths,
      };

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['id'] as String,
        title: j['title'] as String,
        body: j['body'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
        category: NoteCategory.values[j['category'] as int? ?? 4],
        pinned: j['pinned'] as bool? ?? false,
        actionItems: (j['actionItems'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic i) => ChecklistItem.fromJson(i as Map<String, dynamic>))
            .toList(),
        links: (j['links'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic l) => NoteLink.fromJson(l as Map<String, dynamic>))
            .toList(),
        calloutTitle: j['calloutTitle'] as String?,
        calloutBody: j['calloutBody'] as String?,
        attachmentPaths: (j['attachmentPaths'] as List<dynamic>? ?? <dynamic>[])
            .cast<String>(),
      );
}
