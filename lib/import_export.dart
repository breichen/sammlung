import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'models.dart';
import 'store.dart';
import 'table_io.dart';
import 'widgets.dart';

// ───────────────────────── Import-Plan ─────────────────────────
class ColMap {
  final int index;
  final RatingDef? rating;
  final bool isNew;
  final String? extraId;
  ColMap(this.index, {this.rating, this.isNew = false, this.extraId});
}

class ImportPlan {
  final Collection c;
  final List<List<String>> rows;
  final bool hasHeader;
  final List<ColMap> cols;
  final List<RatingDef> newDefs;
  ImportPlan(this.c, this.rows, this.hasHeader, this.cols, this.newDefs);
  int get dataCount => rows.length - (hasHeader ? 1 : 0);
}

class ImportResult {
  int added = 0, updated = 0, unchanged = 0, invalid = 0, ratingsCreated = 0;
}

bool _detectHeader(Collection c, List<String> r) {
  String cell(int i) => i < r.length ? r[i].trim() : '';
  if (c.hasYear) {
    final yi = c.hasGroup ? 2 : 1;
    final y = cell(yi);
    if (y.isNotEmpty && parseYear(y) == null) return true;
  }
  final first = norm(cell(0));
  return first == norm(c.groupLabel ?? c.titleLabel) || first == norm(c.titleLabel);
}

String _freeLetter(String preferred, Set<String> used) {
  for (final u in preferred.toUpperCase().runes) {
    final ch = String.fromCharCode(u);
    if (RegExp(r'[A-Z0-9]').hasMatch(ch) && !used.contains(ch)) return ch;
  }
  for (final l in alphabet.skip(1)) {
    if (!used.contains(l)) return l;
  }
  return '?';
}

/// Legt fest, wie die Spalten zugeordnet werden. Verändert nichts.
/// Reihenfolge der festen Spalten: [Gruppe], Titel, [Jahr]. Alles danach ist
/// ein Zusatzfeld (wenn die Kopfzeile so heißt) oder eine Bewertung.
ImportPlan planImport(Collection c, List<List<String>> raw) {
  final rows = raw.where((r) => r.any((x) => x.trim().isNotEmpty)).toList();
  if (rows.isEmpty) return ImportPlan(c, rows, false, [], []);
  final hasHeader = _detectHeader(c, rows.first);
  final nFixed = (c.hasGroup ? 1 : 0) + 1 + (c.hasYear ? 1 : 0);
  final maxCols = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
  final head = hasHeader ? rows.first : const <String>[];
  final data = rows.skip(hasHeader ? 1 : 0);

  final cols = <ColMap>[];
  final newDefs = <RatingDef>[];
  final used = c.ratings.map((r) => r.letter.toUpperCase()).toSet();
  var positional = 0;

  for (var j = nFixed; j < maxCols; j++) {
    final h = j < head.length ? head[j].trim() : '';
    if (h.isEmpty && !data.any((r) => j < r.length && r[j].trim().isNotEmpty)) continue;

    if (h.isNotEmpty) {
      final ex = c.extras.where((e) => norm(e.label) == norm(h));
      if (ex.isNotEmpty) {
        cols.add(ColMap(j, extraId: ex.first.id));
        continue;
      }
    }

    RatingDef? def;
    var isNew = false;
    if (h.isNotEmpty) {
      final m = RegExp(r'^(.*?)\s*\((.)\)$').firstMatch(h);
      final name = (m != null ? m.group(1)! : h).trim();
      final hint = m?.group(2)?.toUpperCase();
      def = c.ratings.where((r) => norm(r.name) == norm(name)).firstOrNull ??
          (hint == null ? null : c.ratings.where((r) => r.letter.toUpperCase() == hint).firstOrNull) ??
          newDefs.where((r) => norm(r.name) == norm(name)).firstOrNull;
      if (def == null) {
        final letter = _freeLetter(hint ?? name, used);
        used.add(letter);
        def = RatingDef('new$j', name, letter,
            ratingPalette[(c.ratings.length + newDefs.length) % ratingPalette.length]);
        newDefs.add(def);
        isNew = true;
      }
    } else {
      if (positional < c.ratings.length) {
        def = c.ratings[positional];
      } else {
        final letter = _freeLetter('', used);
        used.add(letter);
        def = RatingDef('new$j', 'Bewertung ${positional + 1}', letter,
            ratingPalette[(c.ratings.length + newDefs.length) % ratingPalette.length]);
        newDefs.add(def);
        isNew = true;
      }
      positional++;
    }
    cols.add(ColMap(j, rating: def, isNew: isNew));
  }
  return ImportPlan(c, rows, hasHeader, cols, newDefs);
}

/// Führt den Import aus. Gleiche Einträge (Gruppe + Titel + Jahr) werden zusammengeführt.
ImportResult applyImport(ImportPlan p) {
  final c = p.c;
  final res = ImportResult();
  for (final d in p.newDefs) {
    d.id = store.newId();
    c.ratings.add(d);
  }
  res.ratingsCreated = p.newDefs.length;

  final index = <String, Item>{for (final it in c.items) c.dupKey(it): it};
  String cell(List<String> row, int i) => i >= 0 && i < row.length ? row[i].trim() : '';
  final gi = c.hasGroup ? 0 : -1;
  final ti = c.hasGroup ? 1 : 0;
  final yi = c.hasYear ? ti + 1 : -1;

  for (var r = p.hasHeader ? 1 : 0; r < p.rows.length; r++) {
    final row = p.rows[r];
    final title = cell(row, ti);
    if (title.isEmpty) {
      res.invalid++;
      continue;
    }
    final ratings = <String, int>{};
    final extras = <String, String>{};
    for (final col in p.cols) {
      final v = cell(row, col.index);
      if (v.isEmpty) continue;
      if (col.extraId != null) {
        extras[col.extraId!] = v;
      } else {
        final n = parseRating(v);
        if (n != null) ratings[col.rating!.id] = n;
      }
    }
    final probe = Item(store.newId(),
        group: cell(row, gi),
        title: title,
        year: yi >= 0 ? parseYear(cell(row, yi)) : null,
        extras: extras,
        ratings: ratings)
      ..refresh(c.hasGroup);
    final key = c.dupKey(probe);
    final existing = index[key];
    if (existing == null) {
      c.items.add(probe);
      index[key] = probe;
      res.added++;
    } else {
      var changed = false;
      ratings.forEach((k, v) {
        if (existing.ratings[k] != v) {
          existing.ratings[k] = v;
          changed = true;
        }
      });
      extras.forEach((k, v) {
        if (existing.extras[k] != v) {
          existing.extras[k] = v;
          changed = true;
        }
      });
      if (changed) {
        existing.refresh(c.hasGroup);
        res.updated++;
      } else {
        res.unchanged++;
      }
    }
  }
  c.touch();
  store.changed();
  return res;
}

// ───────────────────────── Export ─────────────────────────
List<List<Object?>> buildExportRows(Collection c) {
  final rows = <List<Object?>>[
    [
      if (c.hasGroup) c.groupLabel,
      c.titleLabel,
      if (c.hasYear) c.yearLabel,
      for (final r in c.ratings) '${r.name} (${r.letter})',
      for (final e in c.extras) e.label,
    ],
  ];
  for (final it in c.sorted) {
    rows.add([
      if (c.hasGroup) it.group,
      it.title,
      if (c.hasYear) it.year,
      for (final r in c.ratings) it.ratings[r.id],
      for (final e in c.extras) it.extras[e.id],
    ]);
  }
  return rows;
}

String _safeName(String s) {
  final t = s.replaceAll(RegExp(r'[^A-Za-z0-9äöüÄÖÜß _-]'), '').trim();
  return t.isEmpty ? 'Sammlung' : t;
}

Future<T> withProgress<T>(BuildContext context, Future<T> f) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  try {
    return await f;
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}

Future<void> exportExcel(BuildContext context, Collection c) async {
  try {
    final rows = buildExportRows(c);
    final bytes = await withProgress(context, compute(writeXlsx, rows));
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_safeName(c.name)}.xlsx');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([
      XFile(file.path,
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
    ]);
  } catch (e) {
    if (context.mounted) snack(context, 'Export fehlgeschlagen: $e');
  }
}

Future<void> copyAsText(BuildContext context, Collection c) async {
  final rows = buildExportRows(c);
  final text = rows
      .map((r) => r.map((v) => (v ?? '').toString().replaceAll(RegExp(r'[\t\r\n]+'), ' ')).join('\t'))
      .join('\n');
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) snack(context, '${rows.length - 1} Einträge kopiert (Tab-getrennt, passt in Excel)');
}

// ───────────────────────── Import-Ablauf ─────────────────────────
Future<List<List<String>>?> _readFile() async {
  final res = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['xlsx', 'xls', 'csv', 'tsv', 'txt'],
    withData: true,
  );
  if (res == null || res.files.isEmpty) return null;
  final f = res.files.first;
  final bytes = f.bytes;
  if (bytes == null) throw 'Die Datei konnte nicht gelesen werden.';
  final ext = (f.extension ?? '').toLowerCase();
  if (ext == 'xls') throw 'Das alte .xls-Format wird nicht unterstützt. Bitte in Excel als .xlsx speichern.';
  if (ext == 'xlsx') return compute(readXlsx, bytes);
  String text;
  try {
    text = utf8.decode(bytes);
  } on FormatException {
    text = latin1.decode(bytes);
  }
  return parseTextTable(text);
}

Future<List<List<String>>?> _readClipboard() async {
  final d = await Clipboard.getData(Clipboard.kTextPlain);
  final t = d?.text ?? '';
  if (t.trim().isEmpty) throw 'Die Zwischenablage ist leer.';
  return parseTextTable(t);
}

Future<void> importFlow(BuildContext context, Collection c) async {
  final src = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.table_chart),
          title: const Text('Excel- oder CSV-Datei wählen'),
          subtitle: const Text('.xlsx, .csv, .tsv, .txt'),
          onTap: () => Navigator.pop(ctx, 'file'),
        ),
        ListTile(
          leading: const Icon(Icons.content_paste),
          title: const Text('Aus der Zwischenablage einfügen'),
          subtitle: const Text('In Excel Zellen kopieren, hier einfügen'),
          onTap: () => Navigator.pop(ctx, 'clip'),
        ),
      ]),
    ),
  );
  if (src == null || !context.mounted) return;

  List<List<String>>? rows;
  try {
    rows = src == 'file' ? await _readFile() : await _readClipboard();
  } catch (e) {
    if (context.mounted) snack(context, '$e');
    return;
  }
  if (rows == null || !context.mounted) return;

  final plan = planImport(c, rows);
  if (plan.dataCount <= 0) {
    snack(context, 'Keine Daten gefunden.');
    return;
  }

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Import prüfen'),
      content: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${fmtInt(plan.dataCount)} Zeilen'),
          Text(plan.hasHeader ? 'Kopfzeile erkannt' : 'Keine Kopfzeile erkannt'),
          const SizedBox(height: 10),
          Text([
            if (c.hasGroup) c.groupLabel!,
            c.titleLabel,
            if (c.hasYear) c.yearLabel!,
          ].join(' · '), style: const TextStyle(fontWeight: FontWeight.bold)),
          if (plan.cols.isEmpty)
            const Text('Keine weiteren Spalten.')
          else
            for (final col in plan.cols)
              Text(col.extraId != null
                  ? 'Spalte ${col.index + 1} → ${c.extras.firstWhere((e) => e.id == col.extraId).label}'
                  : 'Spalte ${col.index + 1} → ${col.rating!.letter} ${col.rating!.name}'
                      '${col.isNew ? ' (neue Bewertung)' : ''}'),
          const SizedBox(height: 10),
          const Text('Gleiche Einträge (Name, Titel, Jahr) werden nicht doppelt angelegt, '
              'sondern um die Bewertungen ergänzt.',
              style: TextStyle(fontSize: 12)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Importieren')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;

  final res = applyImport(plan);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Import fertig'),
      content: Text('${fmtInt(res.added)} neu\n'
          '${fmtInt(res.updated)} aktualisiert\n'
          '${fmtInt(res.unchanged)} unverändert\n'
          '${fmtInt(res.invalid)} ohne Titel übersprungen'
          '${res.ratingsCreated > 0 ? '\n${res.ratingsCreated} Bewertung(en) angelegt' : ''}'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
    ),
  );
}
