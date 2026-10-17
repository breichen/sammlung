import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'collection_editor.dart';
import 'collection_page.dart';
import 'models.dart';
import 'store.dart';
import 'widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _open(BuildContext context, String id) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => CollectionPage(collectionId: id)));

  Future<void> _create(BuildContext context) async {
    final choice = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Neues Verzeichnis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          for (final t in collectionTemplates)
            ListTile(
              leading: CircleAvatar(child: Icon(iconFor(t.icon))),
              title: Text(t.name),
              subtitle: Text([
                if (t.groupLabel != null) t.groupLabel!,
                t.titleLabel,
                if (t.yearLabel != null) t.yearLabel!,
                ...t.extras,
              ].join(' · ')),
              onTap: () => Navigator.pop(ctx, t),
            ),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.tune)),
            title: const Text('Eigener Typ …'),
            subtitle: const Text('Felder und Bezeichnungen selbst festlegen'),
            onTap: () => Navigator.pop(ctx, 'custom'),
          ),
        ]),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice is CollectionTemplate) {
      _open(context, store.addFromTemplate(choice).id);
    } else {
      final id = await Navigator.push<String>(
          context, MaterialPageRoute(builder: (_) => const CollectionEditor()));
      if (id != null && context.mounted) _open(context, id);
    }
  }

  Future<void> _backup(BuildContext context) async {
    try {
      final text = await store.backupJson();
      final dir = await getTemporaryDirectory();
      final d = DateTime.now();
      String p(int n) => n.toString().padLeft(2, '0');
      final file = File('${dir.path}/sammlung-sicherung-${d.year}-${p(d.month)}-${p(d.day)}.json');
      await file.writeAsString(text);
      await Share.shareXFiles([XFile(file.path, mimeType: 'application/json')]);
    } catch (e) {
      if (context.mounted) snack(context, 'Sicherung fehlgeschlagen: $e');
    }
  }

  Future<void> _restore(BuildContext context) async {
    try {
      final res = await FilePicker.platform
          .pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
      if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;
      if (!context.mounted) return;
      if (!await confirm(context, 'Sicherung wiederherstellen?',
          'Alle aktuellen Verzeichnisse werden durch den Inhalt der Datei ersetzt.',
          yes: 'Ersetzen')) {
        return;
      }
      final err = store.restoreFromJson(utf8.decode(res.files.first.bytes!));
      if (context.mounted) snack(context, err ?? 'Sicherung wiederhergestellt');
    } catch (e) {
      if (context.mounted) snack(context, 'Wiederherstellen fehlgeschlagen: $e');
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Sammlung'),
              actions: [
                PopupMenuButton<String>(
                  onSelected: (v) => v == 'backup' ? _backup(context) : _restore(context),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'backup', child: Text('Komplette Sicherung exportieren')),
                    PopupMenuItem(value: 'restore', child: Text('Sicherung wiederherstellen')),
                  ],
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => _create(context),
              icon: const Icon(Icons.add),
              label: const Text('Verzeichnis'),
            ),
            body: !store.loaded
                ? const Center(child: CircularProgressIndicator())
                : store.collections.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                              'Noch keine Verzeichnisse. Lege mit „Verzeichnis“ z. B. Musikalben oder Bücher an.',
                              textAlign: TextAlign.center),
                        ),
                      )
                    : ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), children: [
                        for (final c in store.collections)
                          Card(
                            elevation: 0,
                            color: Colors.white,
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: CircleAvatar(child: Icon(iconFor(c.icon))),
                              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${fmtInt(c.items.length)} Einträge'),
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) async {
                                  if (v == 'edit') {
                                    await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => CollectionEditor(existing: c)));
                                  } else if (await confirm(context, 'Verzeichnis löschen?',
                                      '„${c.name}“ mit ${fmtInt(c.items.length)} Einträgen wird dauerhaft gelöscht.')) {
                                    store.deleteCollection(c);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
                                  PopupMenuItem(value: 'delete', child: Text('Löschen')),
                                ],
                              ),
                              onTap: () => _open(context, c.id),
                            ),
                          ),
                      ]),
          );
        },
      );
}
