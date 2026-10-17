import 'package:flutter/material.dart';
import 'group_page.dart';
import 'models.dart';
import 'ratings_page.dart';
import 'store.dart';
import 'widgets.dart';

Item? findItem(Collection c, String id) {
  for (final i in c.items) {
    if (i.id == id) return i;
  }
  return null;
}

/// Detailseite: Bewertungen vergeben und eintragen, wann man es gehört/gelesen/… hat.
class ItemPage extends StatelessWidget {
  final String collectionId, itemId;
  const ItemPage({super.key, required this.collectionId, required this.itemId});

  Future<void> _addAt(BuildContext context, Item it) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(1990),
      lastDate: now,
      helpText: 'Welcher Tag?',
    );
    if (d == null || !context.mounted) return;
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(now), helpText: 'Uhrzeit');
    if (t == null) return;
    store.addListen(it, DateTime(d.year, d.month, d.day, t.hour, t.minute).millisecondsSinceEpoch);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final c = store.byId(collectionId);
          final it = c == null ? null : findItem(c, itemId);
          if (c == null || it == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted && Navigator.canPop(context)) Navigator.pop(context);
            });
            return const Scaffold();
          }
          final scheme = Theme.of(context).colorScheme;
          final listens = it.listens.reversed.toList();
          final extras = [for (final e in c.extras) if ((it.extras[e.id] ?? '').isNotEmpty) '${e.label}: ${it.extras[e.id]}'];

          return Scaffold(
            appBar: AppBar(
              title: Text(c.name),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ItemEditor(collection: c, item: it))),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await confirm(context, 'Eintrag löschen?', '„${it.title}“ wird dauerhaft gelöscht.')) {
                      store.deleteItem(c, it);
                    }
                  },
                ),
              ],
            ),
            body: ListView(padding: const EdgeInsets.all(16), children: [
              Text(it.title,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (c.hasGroup)
                  InkWell(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => GroupPage(collectionId: c.id, groupKey: it.gk))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(it.group.isEmpty ? '–' : it.group,
                            style: TextStyle(
                                fontSize: 17, color: scheme.primary, fontWeight: FontWeight.w600)),
                        Icon(Icons.chevron_right, color: scheme.primary, size: 20),
                      ]),
                    ),
                  ),
                if (c.hasYear && it.year != null)
                  Text('${it.year}', style: const TextStyle(fontSize: 17, color: Colors.black54)),
              ]),
              for (final e in extras)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(e, style: const TextStyle(color: Colors.black87)),
                ),
              const Divider(height: 32),
              Text('Bewertungen',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              if (c.ratings.isEmpty)
                Row(children: [
                  const Expanded(child: Text('Noch keine Bewertungsarten angelegt.')),
                  TextButton(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => RatingsPage(collectionId: c.id))),
                    child: const Text('Anlegen'),
                  ),
                ])
              else
                for (final d in c.ratings)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Color(d.color),
                        child: Text(d.letter,
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(d.name, style: const TextStyle(fontSize: 15))),
                      StarRow(
                        value: it.ratings[d.id] ?? 0,
                        color: Color(d.color),
                        onChanged: (v) => store.setRating(it, d.id, v),
                      ),
                    ]),
                  ),
              const Divider(height: 32),
              Row(children: [
                Expanded(
                  child: Text(
                      '${c.usageLabel}${listens.isEmpty ? '' : ' (${listens.length}×)'}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      store.addListen(it, DateTime.now().millisecondsSinceEpoch);
                      snack(context, 'Eingetragen: jetzt ${c.usageLabel.toLowerCase()}');
                    },
                    icon: const Icon(Icons.play_circle),
                    label: Text('Jetzt ${c.usageLabel.toLowerCase()}'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => _addAt(context, it),
                  icon: const Icon(Icons.event),
                  label: const Text('Anderer Zeitpunkt'),
                ),
              ]),
              const SizedBox(height: 6),
              if (listens.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Noch nicht eingetragen.', style: Theme.of(context).textTheme.bodySmall),
                )
              else
                for (final ms in listens)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history, size: 20),
                    title: Text(fmtDateTime(ms)),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => store.removeListen(it, ms),
                    ),
                  ),
            ]),
          );
        },
      );
}

/// Eintrag anlegen oder ändern.
class ItemEditor extends StatefulWidget {
  final Collection collection;
  final Item? item;
  const ItemEditor({super.key, required this.collection, this.item});
  @override
  State<ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<ItemEditor> {
  late String group = widget.item?.group ?? '';
  late final title = TextEditingController(text: widget.item?.title ?? '');
  late final year = TextEditingController(text: widget.item?.year?.toString() ?? '');
  late final Map<String, TextEditingController> extras = {
    for (final e in widget.collection.extras)
      e.id: TextEditingController(text: widget.item?.extras[e.id] ?? ''),
  };
  late final List<String> groupNames = [
    for (final g in widget.collection.groups)
      if (!g.name.startsWith('(ohne ')) g.name,
  ];

  @override
  void dispose() {
    title.dispose();
    year.dispose();
    for (final c in extras.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    final c = widget.collection;
    final t = title.text.trim();
    if (t.isEmpty) {
      snack(context, 'Bitte ${c.titleLabel} eingeben');
      return;
    }
    int? y;
    final ys = year.text.trim();
    if (c.hasYear && ys.isNotEmpty) {
      y = parseYear(ys);
      if (y == null) {
        snack(context, 'Das Jahr ist ungültig');
        return;
      }
    }
    final probe = Item('', group: group.trim(), title: t, year: y)..refresh(c.hasGroup);
    final key = c.dupKey(probe);
    final dup = c.items.any((x) => x != widget.item && c.dupKey(x) == key);
    if (dup &&
        !await confirm(context, 'Eintrag existiert schon',
            'Es gibt bereits einen Eintrag mit gleichem Namen und Jahr. Trotzdem speichern?',
            yes: 'Speichern')) {
      return;
    }
    final it = widget.item ?? Item(store.newId(), title: t);
    it.group = group.trim();
    it.title = t;
    it.year = y;
    it.extras = {
      for (final e in extras.entries)
        if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
    };
    if (widget.item == null) {
      store.addItem(c, it);
    } else {
      store.updateItem(c, it);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.collection;
    const gap = SizedBox(height: 14);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item == null ? 'Neuer Eintrag' : 'Eintrag ändern'),
        actions: [IconButton(icon: const Icon(Icons.check), onPressed: save)],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (c.hasGroup) ...[
          Autocomplete<String>(
            initialValue: TextEditingValue(text: group),
            optionsBuilder: (v) {
              final q = norm(v.text);
              if (q.isEmpty) return const Iterable<String>.empty();
              return groupNames.where((n) => norm(n).contains(q)).take(8);
            },
            onSelected: (s) => group = s,
            fieldViewBuilder: (ctx, ctrl, focus, onSubmit) => TextField(
              controller: ctrl,
              focusNode: focus,
              onChanged: (v) => group = v,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                  labelText: c.groupLabel, border: const OutlineInputBorder()),
            ),
          ),
          gap,
        ],
        TextField(
          controller: title,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: c.titleLabel, border: const OutlineInputBorder()),
        ),
        if (c.hasYear) ...[
          gap,
          TextField(
            controller: year,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: c.yearLabel, border: const OutlineInputBorder()),
          ),
        ],
        for (final e in c.extras) ...[
          gap,
          TextField(
            controller: extras[e.id],
            decoration: InputDecoration(labelText: e.label, border: const OutlineInputBorder()),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(onPressed: save, icon: const Icon(Icons.check), label: const Text('Speichern')),
      ]),
    );
  }
}
