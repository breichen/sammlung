import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';
import 'widgets.dart';

/// Bewertungsarten eines Verzeichnisses: Name, Buchstabe, Farbe (jeweils 1-5 Sterne).
class RatingsPage extends StatelessWidget {
  final String collectionId;
  const RatingsPage({super.key, required this.collectionId});

  Future<void> _edit(BuildContext context, Collection c, RatingDef? r) async {
    final used = {for (final x in c.ratings) if (x != r) x.letter.toUpperCase()};
    final res = await showDialog<(String, String, int)>(
      context: context,
      builder: (_) => _RatingDialog(existing: r, used: used, defaultColor: ratingPalette[c.ratings.length % ratingPalette.length]),
    );
    if (res == null) return;
    if (r == null) {
      store.addRating(c, res.$1, res.$2, res.$3);
    } else {
      store.updateRating(r, res.$1, res.$2, res.$3);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final c = store.byId(collectionId);
          if (c == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted && Navigator.canPop(context)) Navigator.pop(context);
            });
            return const Scaffold();
          }
          return Scaffold(
            appBar: AppBar(title: const Text('Bewertungen')),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => _edit(context, c, null),
              icon: const Icon(Icons.add),
              label: const Text('Bewertung'),
            ),
            body: c.ratings.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                          'Noch keine Bewertungen. Lege z. B. „Redaktion“ mit R und „Leser“ mit L an, '
                          'jeweils mit 1 bis 5 Sternen. Beim Import aus Excel entstehen sie automatisch aus den Spalten nach dem Jahr.',
                          textAlign: TextAlign.center),
                    ),
                  )
                : ListView(padding: const EdgeInsets.only(bottom: 90), children: [
                    for (final r in c.ratings)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Color(r.color),
                          child: Text(r.letter,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(r.name),
                        subtitle: Text(
                            '${fmtInt(c.items.where((i) => i.ratings.containsKey(r.id)).length)} Einträge bewertet'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            if (await confirm(context, 'Bewertung löschen?',
                                '„${r.name}“ und alle vergebenen Sterne werden gelöscht.')) {
                              store.deleteRating(c, r);
                            }
                          },
                        ),
                        onTap: () => _edit(context, c, r),
                      ),
                  ]),
          );
        },
      );
}

class _RatingDialog extends StatefulWidget {
  final RatingDef? existing;
  final Set<String> used;
  final int defaultColor;
  const _RatingDialog({this.existing, required this.used, required this.defaultColor});
  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  late final name = TextEditingController(text: widget.existing?.name ?? '');
  late final letter = TextEditingController(text: widget.existing?.letter ?? '');
  late int color = widget.existing?.color ?? widget.defaultColor;
  String? error;

  @override
  void dispose() {
    name.dispose();
    letter.dispose();
    super.dispose();
  }

  void submit() {
    final n = name.text.trim();
    if (n.isEmpty) {
      setState(() => error = 'Bitte einen Namen eingeben');
      return;
    }
    var l = letter.text.trim().toUpperCase();
    if (l.isEmpty) l = n.substring(0, 1).toUpperCase();
    l = l.substring(0, 1);
    if (widget.used.contains(l)) {
      setState(() => error = 'Der Buchstabe $l ist schon vergeben');
      return;
    }
    Navigator.pop(context, (n, l, color));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.existing == null ? 'Neue Bewertung' : 'Bewertung ändern'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: name,
              autofocus: widget.existing == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Name (z. B. Redaktion)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: letter,
              maxLength: 1,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                  labelText: 'Buchstabe', helperText: 'Leer lassen = erster Buchstabe des Namens'),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final c in ratingPalette)
                GestureDetector(
                  onTap: () => setState(() => color = c),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: color == c ? Colors.black : Colors.transparent, width: 3),
                    ),
                    child: color == c ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                  ),
                ),
            ]),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          FilledButton(onPressed: submit, child: const Text('Speichern')),
        ],
      );
}
