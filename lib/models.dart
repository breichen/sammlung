import 'package:flutter/material.dart';

const iconOptions = <String, IconData>{
  'album': Icons.album,
  'book': Icons.menu_book,
  'movie': Icons.movie,
  'game': Icons.sports_esports,
  'tv': Icons.tv,
  'list': Icons.list_alt,
  'wine': Icons.wine_bar,
  'plant': Icons.local_florist,
  'photo': Icons.photo_camera,
  'star': Icons.star,
};

IconData iconFor(String key) => iconOptions[key] ?? Icons.folder;

const ratingPalette = <int>[
  0xFFD84343, // rot
  0xFF2B6CB0, // blau
  0xFF2F7D5B, // grün
  0xFFE08A1E, // orange
  0xFF7B4FB3, // violett
  0xFF00897B, // türkis
  0xFFC2417D, // pink
  0xFF5D6D7E, // grau
];

// ── Text-Normalisierung (Sortierung, Suche, Buchstabenleiste) ──
const _diacritics = <String, String>{
  'ä': 'a', 'ö': 'o', 'ü': 'u', 'ß': 'ss', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'å': 'a', 'æ': 'ae', 'ç': 'c', 'í': 'i',
  'ì': 'i', 'î': 'i', 'ï': 'i', 'ñ': 'n', 'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o',
  'ø': 'o', 'ú': 'u', 'ù': 'u', 'û': 'u', 'ý': 'y', 'ÿ': 'y', 'š': 's', 'ž': 'z',
  'č': 'c', 'ł': 'l',
};

String norm(String s) {
  final lower = s.toLowerCase();
  var ascii = true;
  for (final u in lower.codeUnits) {
    if (u > 127) {
      ascii = false;
      break;
    }
  }
  if (ascii) return lower.trim();
  final b = StringBuffer();
  for (final r in lower.runes) {
    final ch = String.fromCharCode(r);
    b.write(_diacritics[ch] ?? ch);
  }
  return b.toString().trim();
}

/// Anfangsbuchstabe für die Leiste: A-Z, alles andere (Ziffern, Symbole) wird '#'.
String letterOf(String normalized) {
  if (normalized.isEmpty) return '#';
  final c = normalized.codeUnitAt(0);
  return (c >= 97 && c <= 122) ? String.fromCharCode(c - 32) : '#';
}

final alphabet = <String>['#', ...List.generate(26, (i) => String.fromCharCode(65 + i))];

int? parseYear(String s) {
  final m = RegExp(r'(\d{4})').firstMatch(s);
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  return (y >= 1000 && y <= 2200) ? y : null;
}

int? parseRating(String s) {
  final d = double.tryParse(s.trim().replaceAll(',', '.'));
  if (d == null) return null;
  final r = d.round();
  return (r >= 1 && r <= 5) ? r : null;
}

String fmtInt(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');

String _p2(int n) => n.toString().padLeft(2, '0');

String fmtDateTime(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${_p2(d.day)}.${_p2(d.month)}.${d.year} ${_p2(d.hour)}:${_p2(d.minute)}';
}

// ── Datenmodell ──
class RatingDef {
  String id, name, letter;
  int color;
  RatingDef(this.id, this.name, this.letter, this.color);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'letter': letter, 'color': color};
  factory RatingDef.fromJson(Map<String, dynamic> j) =>
      RatingDef(j['id'], j['name'], j['letter'], j['color']);
}

class ExtraField {
  final String id;
  String label;
  ExtraField(this.id, this.label);
  Map<String, dynamic> toJson() => {'id': id, 'label': label};
  factory ExtraField.fromJson(Map<String, dynamic> j) => ExtraField(j['id'], j['label']);
}

class Item {
  final String id;
  String group, title;
  int? year;
  Map<String, String> extras;
  Map<String, int> ratings; // Rating-ID -> 1..5
  List<int> listens; // Zeitpunkte (Millisekunden)

  // abgeleitet, wird in refresh() berechnet
  String gk = '', tk = '', search = '', letter = '#';

  Item(this.id,
      {this.group = '',
      required this.title,
      this.year,
      Map<String, String>? extras,
      Map<String, int>? ratings,
      List<int>? listens})
      : extras = extras ?? {},
        ratings = ratings ?? {},
        listens = listens ?? [];

  void refresh(bool hasGroup) {
    final g = norm(group);
    tk = norm(title);
    gk = hasGroup ? g : tk;
    letter = letterOf(gk);
    final ex = extras.isEmpty ? '' : extras.values.map(norm).join(' ');
    search = '$g $tk ${year ?? ''} $ex';
  }

  int? get lastListen {
    if (listens.isEmpty) return null;
    return listens.fold<int>(0, (a, b) => b > a ? b : a);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (group.isNotEmpty) 'g': group,
        't': title,
        if (year != null) 'y': year,
        if (extras.isNotEmpty) 'e': extras,
        if (ratings.isNotEmpty) 'r': ratings,
        if (listens.isNotEmpty) 'l': listens,
      };

  factory Item.fromJson(Map<String, dynamic> j) => Item(
        j['id'],
        group: j['g'] ?? '',
        title: j['t'] ?? '',
        year: j['y'],
        extras: j['e'] == null ? null : Map<String, String>.from(j['e']),
        ratings: j['r'] == null ? null : Map<String, int>.from(j['r']),
        listens: j['l'] == null ? null : List<int>.from(j['l']),
      );
}

class GroupEntry {
  final String name, key, letter;
  final List<Item> items = [];
  GroupEntry(this.name, this.key, this.letter);
}

class Collection {
  final String id;
  String name, icon, titleLabel, usageLabel;
  String? groupLabel, groupPlural, yearLabel;
  bool sortByYear;
  List<ExtraField> extras;
  List<RatingDef> ratings;
  List<Item> items;

  Collection({
    required this.id,
    required this.name,
    this.icon = 'list',
    this.groupLabel,
    this.groupPlural,
    this.titleLabel = 'Titel',
    this.yearLabel,
    this.usageLabel = 'Benutzt',
    this.sortByYear = true,
    List<ExtraField>? extras,
    List<RatingDef>? ratings,
    List<Item>? items,
  })  : extras = extras ?? [],
        ratings = ratings ?? [],
        items = items ?? [];

  bool get hasGroup => groupLabel != null;
  bool get hasYear => yearLabel != null;
  String get groupsName => groupPlural ?? groupLabel ?? '';

  // ── Zwischenspeicher für schnelle Listen (bei Änderung per touch() verworfen) ──
  List<Item>? _sorted;
  List<GroupEntry>? _groups;
  Map<String, GroupEntry>? _groupMap;
  Map<int, int>? _years;

  void touch() {
    _sorted = null;
    _groups = null;
    _groupMap = null;
    _years = null;
  }

  void reindexAll() {
    for (final i in items) {
      i.refresh(hasGroup);
    }
    touch();
  }

  int _cmp(Item a, Item b) {
    var c = a.gk.compareTo(b.gk);
    if (c != 0) return c;
    if (hasGroup && sortByYear && hasYear) {
      c = (a.year ?? 99999).compareTo(b.year ?? 99999);
      if (c != 0) return c;
    }
    return a.tk.compareTo(b.tk);
  }

  List<Item> get sorted => _sorted ??= (List<Item>.of(items)..sort(_cmp));

  void _buildGroups() {
    final list = <GroupEntry>[];
    final map = <String, GroupEntry>{};
    if (hasGroup) {
      for (final it in sorted) {
        var g = map[it.gk];
        if (g == null) {
          g = GroupEntry(it.group.trim().isEmpty ? '(ohne $groupLabel)' : it.group.trim(),
              it.gk, it.letter);
          map[it.gk] = g;
          list.add(g);
        }
        g.items.add(it);
      }
    }
    _groups = list;
    _groupMap = map;
  }

  List<GroupEntry> get groups {
    if (_groups == null) _buildGroups();
    return _groups!;
  }

  GroupEntry? groupByKey(String key) {
    if (_groupMap == null) _buildGroups();
    return _groupMap![key];
  }

  Map<int, int> get yearCounts {
    if (_years != null) return _years!;
    final m = <int, int>{};
    for (final it in items) {
      final y = it.year;
      if (y != null) m[y] = (m[y] ?? 0) + 1;
    }
    return _years = m;
  }

  String dupKey(Item i) => '${hasGroup ? i.gk : ''}|${i.tk}|${i.year ?? ''}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'groupLabel': groupLabel,
        'groupPlural': groupPlural,
        'titleLabel': titleLabel,
        'yearLabel': yearLabel,
        'usageLabel': usageLabel,
        'sortByYear': sortByYear,
        'extras': extras.map((e) => e.toJson()).toList(),
        'ratings': ratings.map((e) => e.toJson()).toList(),
        'items': items.map((e) => e.toJson()).toList(),
      };

  factory Collection.fromJson(Map<String, dynamic> j) {
    final c = Collection(
      id: j['id'],
      name: j['name'],
      icon: j['icon'] ?? 'list',
      groupLabel: j['groupLabel'],
      groupPlural: j['groupPlural'],
      titleLabel: j['titleLabel'] ?? 'Titel',
      yearLabel: j['yearLabel'],
      usageLabel: j['usageLabel'] ?? 'Benutzt',
      sortByYear: j['sortByYear'] ?? true,
      extras: (j['extras'] as List? ?? []).map((e) => ExtraField.fromJson(Map<String, dynamic>.from(e))).toList(),
      ratings: (j['ratings'] as List? ?? []).map((e) => RatingDef.fromJson(Map<String, dynamic>.from(e))).toList(),
      items: (j['items'] as List? ?? []).map((e) => Item.fromJson(Map<String, dynamic>.from(e))).toList(),
    );
    c.reindexAll();
    return c;
  }
}

/// Filter: alle Wörter der Eingabe müssen im Suchtext vorkommen.
List<Item> filterItems(List<Item> src, String query) {
  final tokens = norm(query).split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  if (tokens.isEmpty) return src;
  return src.where((it) {
    for (final t in tokens) {
      if (!it.search.contains(t)) return false;
    }
    return true;
  }).toList();
}

List<GroupEntry> filterGroups(List<GroupEntry> src, String query) {
  final tokens = norm(query).split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  if (tokens.isEmpty) return src;
  return src.where((g) {
    final n = norm(g.name);
    for (final t in tokens) {
      if (!n.contains(t)) return false;
    }
    return true;
  }).toList();
}

// ── Vorlagen ──
class CollectionTemplate {
  final String name, icon, titleLabel, usageLabel;
  final String? groupLabel, groupPlural, yearLabel;
  final List<String> extras;
  const CollectionTemplate({
    required this.name,
    required this.icon,
    this.groupLabel,
    this.groupPlural,
    this.titleLabel = 'Titel',
    this.yearLabel = 'Jahr',
    required this.usageLabel,
    this.extras = const [],
  });
}

const collectionTemplates = <CollectionTemplate>[
  CollectionTemplate(
      name: 'Musikalben', icon: 'album', groupLabel: 'Interpret', groupPlural: 'Interpreten',
      usageLabel: 'Gehört'),
  CollectionTemplate(
      name: 'Bücher', icon: 'book', groupLabel: 'Autor', groupPlural: 'Autoren',
      usageLabel: 'Gelesen', extras: ['Verlag']),
  CollectionTemplate(
      name: 'Filme', icon: 'movie', groupLabel: 'Regisseur', groupPlural: 'Regisseure',
      usageLabel: 'Gesehen', extras: ['Genre']),
  CollectionTemplate(
      name: 'Spiele', icon: 'game', groupLabel: 'Entwickler', groupPlural: 'Entwickler',
      usageLabel: 'Gespielt', extras: ['Plattform']),
];
