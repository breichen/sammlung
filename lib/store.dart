import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'models.dart';

final store = Store();

/// Alle Daten liegen lokal in einer JSON-Datei. Gespeichert wird verzögert,
/// damit schnelle Änderungen (z. B. Sterne tippen) nicht jedes Mal schreiben.
class Store extends ChangeNotifier {
  List<Collection> collections = [];
  late File _file;
  bool loaded = false;
  Timer? _timer;
  bool _writing = false, _pending = false;
  int _n = 0;

  String newId() => '${DateTime.now().microsecondsSinceEpoch}_${_n++}';

  File get dataFile => _file;

  Future<void> load() async {
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/sammlung.json');
    if (await _file.exists()) {
      try {
        _apply(jsonDecode(await _file.readAsString()));
      } catch (_) {
        await _file.rename('${dir.path}/sammlung.defekt.json');
      }
    }
    loaded = true;
    notifyListeners();
  }

  void _apply(dynamic j) {
    collections = (j['collections'] as List)
        .map((e) => Collection.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'collections': collections.map((c) => c.toJson()).toList(),
      };

  void changed({bool save = true}) {
    notifyListeners();
    if (save) {
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 600), _write);
    }
  }

  Future<void> flush() async {
    if (_timer?.isActive ?? false) {
      _timer!.cancel();
      await _write();
    }
  }

  Future<void> _write() async {
    if (_writing) {
      _pending = true;
      return;
    }
    _writing = true;
    try {
      do {
        _pending = false;
        final tmp = File('${_file.path}.tmp');
        await tmp.writeAsString(jsonEncode(toJson()));
        await tmp.rename(_file.path);
      } while (_pending);
    } finally {
      _writing = false;
    }
  }

  // ── Backup ──
  Future<String> backupJson() async {
    await flush();
    return jsonEncode(toJson());
  }

  /// Ersetzt alle Daten. Gibt eine Fehlermeldung zurück oder null.
  String? restoreFromJson(String text) {
    try {
      final j = jsonDecode(text);
      if (j is! Map || j['collections'] is! List) return 'Das ist keine Sammlung-Sicherung.';
      _apply(j);
      changed();
      return null;
    } catch (e) {
      return 'Die Datei konnte nicht gelesen werden.';
    }
  }

  // ── Verzeichnisse ──
  Collection addFromTemplate(CollectionTemplate t) {
    final c = Collection(
      id: newId(),
      name: t.name,
      icon: t.icon,
      groupLabel: t.groupLabel,
      groupPlural: t.groupPlural,
      titleLabel: t.titleLabel,
      yearLabel: t.yearLabel,
      usageLabel: t.usageLabel,
      extras: [for (final e in t.extras) ExtraField(newId(), e)],
    );
    collections.add(c);
    changed();
    return c;
  }

  void addCollection(Collection c) {
    collections.add(c);
    changed();
  }

  void deleteCollection(Collection c) {
    collections.remove(c);
    changed();
  }

  Collection? byId(String id) {
    for (final c in collections) {
      if (c.id == id) return c;
    }
    return null;
  }

  // ── Einträge ──
  void addItem(Collection c, Item it) {
    it.refresh(c.hasGroup);
    c.items.add(it);
    c.touch();
    changed();
  }

  void updateItem(Collection c, Item it) {
    it.refresh(c.hasGroup);
    c.touch();
    changed();
  }

  void deleteItem(Collection c, Item it) {
    c.items.remove(it);
    c.touch();
    changed();
  }

  void setRating(Item it, String ratingId, int value) {
    if (value <= 0) {
      it.ratings.remove(ratingId);
    } else {
      it.ratings[ratingId] = value;
    }
    changed();
  }

  void addListen(Item it, int ms) {
    it.listens.add(ms);
    it.listens.sort();
    changed();
  }

  void removeListen(Item it, int ms) {
    it.listens.remove(ms);
    changed();
  }

  // ── Bewertungen ──
  void addRating(Collection c, String name, String letter, int color) {
    c.ratings.add(RatingDef(newId(), name, letter, color));
    changed();
  }

  void updateRating(RatingDef r, String name, String letter, int color) {
    r.name = name;
    r.letter = letter;
    r.color = color;
    changed();
  }

  void deleteRating(Collection c, RatingDef r) {
    c.ratings.remove(r);
    for (final it in c.items) {
      it.ratings.remove(r.id);
    }
    changed();
  }

  /// Nach Änderungen am Aufbau eines Verzeichnisses (Bezeichnungen, Zusatzfelder, Gruppierung).
  void schemaChanged(Collection c) {
    final ids = c.extras.map((e) => e.id).toSet();
    final ratingIds = c.ratings.map((r) => r.id).toSet();
    for (final it in c.items) {
      it.extras.removeWhere((k, _) => !ids.contains(k));
      it.ratings.removeWhere((k, _) => !ratingIds.contains(k));
    }
    c.reindexAll();
    changed();
  }
}
