import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/alarm.dart';
import '../../data/models/commitments.dart';
import '../../data/models/enums.dart';
import '../../data/models/habit.dart';
import '../../data/models/reminder.dart';
import '../../data/stores/alarm_store.dart';
import '../../data/stores/commitments_store.dart';
import '../../data/stores/planner_store.dart';
import '../../data/stores/reminder_store.dart';
import '../../data/stores/settings_store.dart';

/// Routing target parsed from a notification payload, consumed by the app
/// shell to deep-link when a notification is tapped.
class NotificationRoute {
  const NotificationRoute(this.kind, this.id);
  final String kind; // reminder | habit | event | alarm | bill | membership | document
  final String id;
}

/// Schedules real device notifications for the three-tier alert system
/// (PRD 2.3 / G.2): notification, alarm, force-confirm.
class NotificationService {
  const NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// Emits a route whenever a notification is tapped. The app shell listens.
  static final ValueNotifier<NotificationRoute?> tapped =
      ValueNotifier<NotificationRoute?>(null);

  /// Set by main() so notification actions can mutate app state directly.
  static ReminderStore? _reminders;
  static AlarmStore? _alarms;
  static SettingsStore? _settings;

  // Channel ids are versioned: Android freezes a channel's sound at creation,
  // so changing the sound requires a new id.
  static const AndroidNotificationDetails _silent = AndroidNotificationDetails(
    'lifeos_notification_v2',
    'Notifications',
    channelDescription: 'Silent banner reminders',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  static const AndroidNotificationDetails _alarm = AndroidNotificationDetails(
    'lifeos_alarm_v2',
    'Alarms',
    channelDescription: 'Sound + vibration reminders',
    importance: Importance.max,
    priority: Priority.high,
    category: AndroidNotificationCategory.alarm,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('alarm_sound'),
    audioAttributesUsage: AudioAttributesUsage.alarm,
    enableVibration: true,
    actions: <AndroidNotificationAction>[
      AndroidNotificationAction('done', 'Done', showsUserInterface: false),
      AndroidNotificationAction('snooze', 'Snooze', showsUserInterface: false),
    ],
  );

  static const AndroidNotificationDetails _force = AndroidNotificationDetails(
    'lifeos_force_v2',
    'Force confirm',
    channelDescription: 'Repeats until you confirm',
    importance: Importance.max,
    priority: Priority.high,
    category: AndroidNotificationCategory.alarm,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('alarm_sound'),
    audioAttributesUsage: AudioAttributesUsage.alarm,
    enableVibration: true,
    fullScreenIntent: true,
    autoCancel: false,
    ongoing: true,
    actions: <AndroidNotificationAction>[
      AndroidNotificationAction('confirm', 'Confirm', showsUserInterface: false),
    ],
  );

  static NotificationDetails _detailsFor(AlertType t, {String? style}) {
    final AndroidNotificationDetails base = switch (t) {
      AlertType.notification => _silent,
      AlertType.alarm => _alarm,
      AlertType.forceConfirm => _force,
    };
    // 'Sound' | 'Vibrate' | 'Silent' from the add-reminder sheet.
    if (style == null || style == 'Sound') {
      return NotificationDetails(android: base);
    }
    final bool vibrate = style == 'Vibrate';
    return NotificationDetails(
      android: AndroidNotificationDetails(
        // Distinct channel per presentation — Android freezes these settings.
        '${base.channelId}_${style.toLowerCase()}',
        '${base.channelName} ($style)',
        channelDescription: base.channelDescription,
        importance: base.importance,
        priority: base.priority,
        category: base.category,
        playSound: false,
        enableVibration: vibrate,
        fullScreenIntent: base.fullScreenIntent,
        autoCancel: base.autoCancel,
        ongoing: base.ongoing,
        actions: base.actions,
      ),
    );
  }

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final TimezoneInfo zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // Fall back to UTC — scheduling still works, times may shift.
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: _onResponse,
    );
    final AndroidFlutterLocalNotificationsPlugin? android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
    _ready = true;
  }

  /// Gives the service direct store access so notification action buttons can
  /// mark things done without the UI being alive.
  static void bindStores(ReminderStore reminders, AlarmStore alarms,
      [SettingsStore? settings]) {
    _reminders = reminders;
    _alarms = alarms;
    _settings = settings;
  }

  /// Handles taps and action buttons.
  static void _onResponse(NotificationResponse r) {
    final String payload = r.payload ?? '';
    final int sep = payload.indexOf(':');
    if (sep <= 0) return;
    final String kind = payload.substring(0, sep);
    final String id = payload.substring(sep + 1);

    switch (r.actionId) {
      case 'done':
      case 'confirm':
        if (kind == 'reminder') {
          final Reminder? rem = _reminders?.byId(id);
          if (rem != null) _reminders!.markDone(rem, DateTime.now());
        } else if (kind == 'alarm') {
          final Alarm? a = _alarms?.byId(id);
          // A one-off alarm switches itself off once acknowledged.
          if (a != null && !a.repeats) _alarms!.setEnabled(a, false);
        }
        return;
      case 'snooze':
        if (kind == 'reminder') {
          final Reminder? rem = _reminders?.byId(id);
          if (rem != null) {
            _reminders!.snooze(rem, _settings?.defaultSnoozeMinutes ?? 10);
          }
        } else if (kind == 'alarm') {
          final Alarm? a = _alarms?.byId(id);
          if (a != null) _alarms!.snooze(a);
        }
        return;
      default:
        tapped.value = NotificationRoute(kind, id);
    }
  }

  /// Stable int id per logical slot. Bit 30 kept clear; slot spreads
  /// multiple occurrences of the same source (weekday, repeat index).
  static int _id(String source, int slot) =>
      (source.hashCode & 0x03FFFFFF) | (slot << 26);

  static tz.TZDateTime _nextInstance(TimeOfDay t, {int? weekday}) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime d = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, t.hour, t.minute);
    while (d.isBefore(now) || (weekday != null && d.weekday != weekday)) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  /// PRD 10.1 — Do Not Disturb silences the notification tier only; alarms and
  /// force-confirm deliberately break through, matching the UI's promise.
  static bool _inDnd(SettingsStore s, TimeOfDay at) {
    final int start = s.dndStart.hour * 60 + s.dndStart.minute;
    final int end = s.dndEnd.hour * 60 + s.dndEnd.minute;
    final int m = at.hour * 60 + at.minute;
    if (start == end) return false;
    // Window wraps past midnight (e.g. 23:00 → 06:00).
    return start > end ? (m >= start || m < end) : (m >= start && m < end);
  }

  static bool _suppressed(SettingsStore? s, AlertType t, TimeOfDay at) =>
      s != null && t == AlertType.notification && _inDnd(s, at);

  static Future<void> _zoned(
    int id,
    String title,
    String body,
    tz.TZDateTime when,
    NotificationDetails details, {
    DateTimeComponents? repeat,
    String? payload,
    bool exact = false,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: when,
        notificationDetails: details,
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: repeat,
        payload: payload,
      );
    } catch (_) {
      // Exact alarms can be denied by the OS — fall back rather than crash.
      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: when,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: repeat,
          payload: payload,
        );
      } catch (_) {/* never let scheduling take the app down */}
    }
  }

  /// Re-derives the entire schedule from current store state.
  /// Called on startup and after every mutation in any scheduling store.
  static Future<void> syncAll(
    ReminderStore reminders,
    PlannerStore planner, {
    AlarmStore? alarms,
    CommitmentsStore? commitments,
    SettingsStore? settings,
  }) async {
    if (!_ready) return;
    await _plugin.cancelAll();

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    // ---- reminders ------------------------------------------------------
    for (final Reminder r in reminders.all) {
      if (!r.enabled) continue;
      // A fixed course ("7 days") stops firing once it has run its length.
      if (r.hasExpired(DateTime.now())) continue;
      final bool exact = r.alertType != AlertType.notification;
      final NotificationDetails details =
          _detailsFor(r.alertType, style: r.notifStyle);
      final String body =
          r.subtitle.isEmpty ? 'Reminder from LifeOS' : r.subtitle;
      final String payload = 'reminder:${r.id}';

      // A snoozed reminder fires once at the snooze target instead.
      if (r.snoozedUntil != null && r.snoozedUntil!.isAfter(now)) {
        await _zoned(_id(r.id, 20), r.title, body,
            tz.TZDateTime.from(r.snoozedUntil!, tz.local), details,
            payload: payload, exact: exact);
      }

      if (_suppressed(settings, r.alertType, r.time)) continue;

      switch (r.repeat) {
        case RepeatPattern.daily:
          await _zoned(_id(r.id, 0), r.title, body, _nextInstance(r.time),
              details,
              repeat: DateTimeComponents.time, payload: payload, exact: exact);
        case RepeatPattern.specificDays:
          for (final int wd in r.specificDays) {
            await _zoned(_id(r.id, wd), r.title, body,
                _nextInstance(r.time, weekday: wd), details,
                repeat: DateTimeComponents.dayOfWeekAndTime,
                payload: payload,
                exact: exact);
          }
        case RepeatPattern.weekly:
          await _zoned(
              _id(r.id, 0),
              r.title,
              body,
              _nextInstance(r.time, weekday: DateTime.monday),
              details,
              repeat: DateTimeComponents.dayOfWeekAndTime,
              payload: payload,
              exact: exact);
        case RepeatPattern.monthly:
          tz.TZDateTime d = tz.TZDateTime(
              tz.local, now.year, now.month, 1, r.time.hour, r.time.minute);
          if (d.isBefore(now)) {
            d = tz.TZDateTime(tz.local, now.year, now.month + 1, 1,
                r.time.hour, r.time.minute);
          }
          await _zoned(_id(r.id, 0), r.title, body, d, details,
              repeat: DateTimeComponents.dayOfMonthAndTime,
              payload: payload,
              exact: exact);
        case RepeatPattern.everyXHours:
          final int step = r.everyXHours < 1 ? 2 : r.everyXHours;
          // Water reminders have an explicit "active hours" window; other
          // every-X-hours reminders (e.g. medicine) fall back to a day-end
          // cutoff so they don't fire overnight.
          final int endHour =
              r.type == ReminderType.water ? reminders.water.untilHour : 22;
          int slot = 0;
          for (int h = r.time.hour;
              h <= endHour && slot < 12;
              h += step, slot++) {
            final TimeOfDay t = TimeOfDay(hour: h, minute: r.time.minute);
            if (_suppressed(settings, r.alertType, t)) continue;
            await _zoned(_id(r.id, slot), r.title, body, _nextInstance(t),
                details,
                repeat: DateTimeComponents.time,
                payload: payload,
                exact: exact);
          }
        case RepeatPattern.sos:
          break; // On-demand only, never scheduled.
      }
    }

    // ---- habits (PRD 3.1 — a habit with a preferred time should alert) ----
    for (final Habit h in planner.habits) {
      final TimeOfDay? t = h.preferredTime;
      if (t == null) continue;
      if (_suppressed(settings, AlertType.notification, t)) continue;
      final NotificationDetails details = _detailsFor(AlertType.notification);
      const String body = 'Habit due today';
      final String payload = 'habit:${h.id}';
      switch (h.repeat) {
        case RepeatPattern.specificDays:
          for (final int wd in h.days) {
            await _zoned(_id('hab_${h.id}', wd), h.name, body,
                _nextInstance(t, weekday: wd), details,
                repeat: DateTimeComponents.dayOfWeekAndTime, payload: payload);
          }
        case RepeatPattern.weekly:
          final int wd = h.days.isEmpty ? DateTime.monday : h.days.first;
          await _zoned(_id('hab_${h.id}', 0), h.name, body,
              _nextInstance(t, weekday: wd), details,
              repeat: DateTimeComponents.dayOfWeekAndTime, payload: payload);
        case RepeatPattern.monthly:
          tz.TZDateTime d = tz.TZDateTime(
              tz.local, now.year, now.month, 1, t.hour, t.minute);
          final int target = h.startedOn?.day ?? 1;
          final int lastDay = DateTime(d.year, d.month + 1, 0).day;
          d = tz.TZDateTime(tz.local, d.year, d.month,
              target > lastDay ? lastDay : target, t.hour, t.minute);
          if (d.isBefore(now)) {
            final int nextMonth = now.month + 1;
            final int lastDayNext = DateTime(now.year, nextMonth + 1, 0).day;
            d = tz.TZDateTime(tz.local, now.year, nextMonth,
                target > lastDayNext ? lastDayNext : target, t.hour, t.minute);
          }
          await _zoned(_id('hab_${h.id}', 0), h.name, body, d, details,
              repeat: DateTimeComponents.dayOfMonthAndTime, payload: payload);
        case RepeatPattern.daily:
        case RepeatPattern.everyXHours:
          await _zoned(_id('hab_${h.id}', 0), h.name, body, _nextInstance(t),
              details,
              repeat: DateTimeComponents.time, payload: payload);
        case RepeatPattern.sos:
          break; // On-demand only, never scheduled.
      }
    }

    // ---- planner events & appointments -----------------------------------
    for (final PlannerEvent e in planner.events) {
      if (e.done) continue;
      final int lead = e.reminderLeadMinutes ?? 30;
      final tz.TZDateTime at = tz.TZDateTime.from(
          e.start.subtract(Duration(minutes: lead)), tz.local);
      if (at.isBefore(now)) continue;
      await _zoned(
        _id(e.id, 0),
        e.title,
        '${e.badgeLabel} at ${_hhmm(TimeOfDay.fromDateTime(e.start))}'
        '${e.location.isEmpty ? '' : ' · ${e.location}'}',
        at,
        _detailsFor(e.alertType),
        payload: 'event:${e.id}',
        exact: e.alertType != AlertType.notification,
      );
    }

    // ---- clock alarms ----------------------------------------------------
    for (final Alarm a in alarms?.all ?? const <Alarm>[]) {
      if (!a.enabled) continue;
      final tz.TZDateTime at =
          tz.TZDateTime.from(a.nextOccurrence(DateTime.now()), tz.local);
      await _zoned(
        _id('alm_${a.id}', 0),
        a.label.isEmpty ? 'Alarm' : a.label,
        a.repeatLabel,
        at,
        // A silent alarm still vibrates unless the user turned that off too.
        _detailsFor(a.alertType, style: a.vibrate ? null : 'Silent'),
        payload: 'alarm:${a.id}',
        exact: true,
      );
    }

    // ---- bills, memberships, documents -----------------------------------
    if (commitments != null) {
      for (final Bill b in commitments.activeBills) {
        final DateTime fire = b.dueDate
            .subtract(Duration(days: b.reminderLeadDays))
            .add(const Duration(hours: 9));
        if (fire.isBefore(DateTime.now())) continue;
        await _zoned(
          _id('bill_${b.id}', 0),
          '${b.name} due',
          '₹${b.amount.toStringAsFixed(0)} due on ${_ddmm(b.dueDate)}',
          tz.TZDateTime.from(fire, tz.local),
          _detailsFor(b.alertType),
          payload: 'bill:${b.id}',
          exact: b.alertType != AlertType.notification,
        );
      }
      for (final Membership m in commitments.activeMemberships) {
        if (!m.reminderEnabled) continue;
        final DateTime fire = m.expiryDate
            .subtract(Duration(days: m.reminderLeadDays))
            .add(const Duration(hours: 9));
        if (fire.isBefore(DateTime.now())) continue;
        await _zoned(
          _id('mem_${m.id}', 0),
          '${m.name} expires soon',
          'Renew before ${_ddmm(m.expiryDate)}',
          tz.TZDateTime.from(fire, tz.local),
          _detailsFor(m.alertType),
          payload: 'membership:${m.id}',
        );
      }
      for (final StoredDocument d in commitments.documents) {
        final DateTime? exp = d.expiryDate;
        if (exp == null) continue;
        final DateTime fire =
            DateTime(exp.year, exp.month - d.reminderLeadMonths, exp.day, 9);
        if (fire.isBefore(DateTime.now())) continue;
        await _zoned(
          _id('doc_${d.id}', 0),
          '${d.name} expires soon',
          'Expires on ${_ddmm(exp)}',
          tz.TZDateTime.from(fire, tz.local),
          _detailsFor(d.alertType),
          payload: 'document:${d.id}',
        );
      }
    }
  }

  /// Force-confirm keeps re-firing at its interval until the user confirms
  /// (PRD 2.3). Called by the ringing screen while it stays unconfirmed.
  static Future<void> scheduleForceConfirmRepeat(
      String payload, String title, String body, int intervalMinutes) async {
    if (!_ready) return;
    final tz.TZDateTime when = tz.TZDateTime.now(tz.local)
        .add(Duration(minutes: intervalMinutes < 1 ? 1 : intervalMinutes));
    await _zoned(_id('fc_$payload', 0), title, body, when,
        _detailsFor(AlertType.forceConfirm),
        payload: payload, exact: true);
  }

  static Future<void> cancelForceConfirmRepeat(String payload) async {
    try {
      await _plugin.cancel(id: _id('fc_$payload', 0));
    } catch (_) {/* nothing scheduled */}
  }

  /// Immediate notification — used for the weekly digest and testing.
  static Future<void> showNow(String title, String body, AlertType t,
      {String? payload}) async {
    if (!_ready) return;
    await _plugin.show(
        id: _id('now_$title', 0),
        title: title,
        body: body,
        notificationDetails: _detailsFor(t),
        payload: payload);
  }

  static Future<void> cancelFor(String sourceId) async {
    for (int slot = 0; slot < 21; slot++) {
      try {
        await _plugin.cancel(id: _id(sourceId, slot));
      } catch (_) {/* not scheduled */}
    }
  }

  static String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static String _ddmm(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}
