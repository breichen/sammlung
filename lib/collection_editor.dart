import 'package:flutter/material.dart';
import 'models.dart';
import 'ratings_page.dart';
import 'store.dart';
import 'widgets.dart';

class _ExtraRow {
  final String? id;
  final TextEditingController ctl;
  _ExtraRow(this.id, String label) : ctl = TextEditingController(text: label);
}

/// Verzeichnis anlegen (eigener Typ) oder bearbeiten: Bezeichnungen, Jahr, Gruppierung, Zusatzfelder.
class CollectionEditor extends StatefulWidget {
  final Collection? existing;
  const CollectionEditor({super.key, this.existing});
  @override
  State<CollectionEditor> createState() => _CollectionEditorState();
}

class _CollectionEditorState extends State<CollectionEditor> {
  late final Collection? c = widget.existing;
  late final name = TextEditingController(text: c?.name ?? '');
  late String icon = c?.icon ?? 'list';
  late bool hasGroup = c == null ? false : c!.hasGroup;
  late final groupLabel = TextEditingController(text: c?.groupLabel ?? '');
  late final groupPlural = TextEditingController(text: c?.groupPlural ?? '');
  late final titleLabel = TextEditingController(text: c?.titleLabel ?? 'Titel');
  late bool hasYear = c == null ? true : c!.hasYear;
  late final yearLabel = TextEditingController(text: c?.yearLabel ?? 'Jahr');
  late final usageLabel = TextEditingController(text: c?.usageLabel ?? 'Benutzt');
  late final List<_ExtraRow> extraRows = [
    for (final e in c?.extras ?? <ExtraField>[]) _ExtraRow(e.id, e.label),
  ];
  // Arbeitskopien: Änderungen gelten erst mit "Speichern"
  late final List<RatingDef> ratingRows = [
    for (final r in c?.ratings ?? <RatingDef>[]) RatingDef(r.id, r.name, r.letter, r.color),
  ];

  Future<void> editRating(RatingDef? r) async {
    final used = {for (final x in ratingRows) if (x != r) x.letter.toUpperCase()};
    final res = await showDialog<(String, String, int)>(
      context: context,
      builder: (_) => RatingDialog(
        existing: r,
        used: used,
        defaultColor: ratingPalette[ratingRows.length % ratingPalette.length],
      ),
    );
    if (res == null) return;
    setState(() {
      if (r == null) {
        ratingRows.add(RatingDef(store.newId(), res.$1, res.$2, res.$3));
      } else {
        r.name = res.$1;
        r.letter = res.$2;
        r.color = res.$3;
      }
    });
  }

  @override
  void dispose() {
    for (final t in [name, groupLabel, groupPlural, titleLabel, yearLabel, usageLabel]) {
      t.dispose();
    }
    for (final r in extraRows) {
      r.ctl.dispose();
    }
    super.dispose();
  }

  void save() {
    final n = name.text.trim();
    if (n.isEmpty) {
      snack(context, 'Bitte einen Namen eingeben');
      return;
    }
    if (hasGroup && groupLabel.text.trim().isEmpty) {
      snack(context, 'Bitte die Bezeichnung der Gruppierung eingeben');
      return;
    }
    final gl = hasGroup ? groupLabel.text.trim() : null;
    final gp = hasGroup ? (groupPlural.text.trim().isEmpty ? gl : groupPlural.text.trim()) : null;
    final tl = titleLabel.text.trim().isEmpty ? 'Titel' : titleLabel.text.trim();
    final yl = hasYear ? (yearLabel.text.trim().isEmpty ? 'Jahr' : yearLabel.text.trim()) : null;
    final ul = usageLabel.text.trim().isEmpty ? 'Benutzt' : usageLabel.text.trim();
    final extras = [
      for (final r in extraRows)
        if (r.ctl.text.trim().isNotEmpty) ExtraField(r.id ?? store.newId(), r.ctl.text.trim()),
    ];

    if (c == null) {
      final nc = Collection(
        id: store.newId(),
        name: n,
        icon: icon,
        groupLabel: gl,
        groupPlural: gp,
        titleLabel: tl,
        yearLabel: yl,
        usageLabel: ul,
        extras: extras,
        ratings: ratingRows,
      );
      store.addCollection(nc);
      Navigator.pop(context, nc.id);
    } else {
      c!
        ..name = n
        ..icon = icon
        ..groupLabel = gl
        ..groupPlural = gp
        ..titleLabel = tl
        ..yearLabel = yl
        ..usageLabel = ul
        ..extras = extras
        ..ratings = ratingRows;
      store.schemaChanged(c!);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const gap = SizedBox(height: 14);
    InputDecoration dec(String l) => InputDecoration(labelText: l, border: const OutlineInputBorder());

    return Scaffold(
      appBar: AppBar(
        title: Text(c == null ? 'Eigenes Verzeichnis' : 'Verzeichnis bearbeiten'),
        actions: [IconButton(icon: const Icon(Icons.check), onPressed: save)],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: name, decoration: dec('Name (z. B. Weine)')),
        gap,
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in iconOptions.entries)
            InkWell(
              customBorder: const CircleBorder(),
              onTap: () => setState(() => icon = e.key),
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: icon == e.key ? scheme.primaryContainer : null,
                  border: Border.all(color: icon == e.key ? scheme.primary : Colors.black12, width: 1.5),
                ),
                child: Icon(e.value, size: 22),
              ),
            ),
        ]),
        const Divider(height: 32),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mit Gruppierung'),
          subtitle: const Text('z. B. Interpret bei Alben, Autor bei Büchern. Ergibt Buchstabenleiste und eigene Liste.'),
          value: hasGroup,
          onChanged: (v) => setState(() => hasGroup = v),
        ),
        if (hasGroup) ...[
          TextField(controller: groupLabel, decoration: dec('Bezeichnung (z. B. Interpret)')),
          gap,
          TextField(controller: groupPlural, decoration: dec('Mehrzahl (z. B. Interpreten)')),
        ],
        gap,
        TextField(controller: titleLabel, decoration: dec('Bezeichnung des Titels')),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mit Jahr'),
          subtitle: const Text('Ergibt das Histogramm über die Jahre.'),
          value: hasYear,
          onChanged: (v) => setState(() => hasYear = v),
        ),
        if (hasYear) TextField(controller: yearLabel, decoration: dec('Bezeichnung des Jahres')),
        gap,
        TextField(controller: usageLabel, decoration: dec('Nutzung (z. B. Gehört, Gelesen)')),
        const Divider(height: 32),
        Text('Zusatzfelder', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        for (final r in extraRows)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              Expanded(child: TextField(controller: r.ctl, decoration: dec('Bezeichnung'))),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => setState(() => extraRows.remove(r)),
              ),
            ]),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => extraRows.add(_ExtraRow(null, ''))),
            icon: const Icon(Icons.add),
            label: const Text('Zusatzfeld hinzufügen'),
          ),
        ),
        const Divider(height: 32),
        Text('Bewertungen', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 2),
        Text('Jede Bewertung hat 1 bis 5 Sterne, einen Namen, einen Buchstaben und eine Farbe '
            '(z. B. „Redaktion“ mit R, „Leser“ mit L).',
            style: Theme.of(context).textTheme.bodySmall),
        for (final r in ratingRows)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: Color(r.color),
              child: Text(r.letter,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            title: Text(r.name),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => setState(() => ratingRows.remove(r)),
            ),
            onTap: () => editRating(r),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => editRating(null),
            icon: const Icon(Icons.add),
            label: const Text('Bewertung hinzufügen'),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(onPressed: save, icon: const Icon(Icons.check), label: const Text('Speichern')),
      ]),
    );
  }
}
