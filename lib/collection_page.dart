import 'package:flutter/material.dart';
import 'collection_editor.dart';
import 'group_page.dart';
import 'import_export.dart';
import 'item_page.dart';
import 'models.dart';
import 'ratings_page.dart';
import 'stats_page.dart';
import 'store.dart';
import 'widgets.dart';

class CollectionPage extends StatelessWidget {
  final String collectionId;
  const CollectionPage({super.key, required this.collectionId});

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
          return DefaultTabController(
            length: c.hasGroup ? 3 : 2,
            child: Scaffold(
              appBar: AppBar(
                title: Text(c.name),
                actions: [_Menu(collection: c)],
                bottom: TabBar(tabs: [
                  const Tab(text: 'Alle'),
                  if (c.hasGroup) Tab(text: c.groupsName),
                  const Tab(text: 'Statistik'),
                ]),
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => ItemEditor(collection: c))),
                child: const Icon(Icons.add),
              ),
              body: TabBarView(children: [
                ItemsTab(collection: c),
                if (c.hasGroup) GroupsTab(collection: c),
                StatsTab(collection: c),
              ]),
            ),
          );
        },
      );
}

class _Menu extends StatelessWidget {
  final Collection collection;
  const _Menu({required this.collection});

  PopupMenuItem<String> _i(String v, IconData i, String t) => PopupMenuItem(
        value: v,
        child: Row(children: [Icon(i, size: 20), const SizedBox(width: 12), Text(t)]),
      );

  @override
  Widget build(BuildContext context) {
    final c = collection;
    return PopupMenuButton<String>(
      onSelected: (v) async {
        switch (v) {
          case 'import':
            await importFlow(context, c);
          case 'export':
            await exportExcel(context, c);
          case 'copy':
            await copyAsText(context, c);
          case 'ratings':
            await Navigator.push(
                context, MaterialPageRoute(builder: (_) => RatingsPage(collectionId: c.id)));
          case 'edit':
            await Navigator.push(
                context, MaterialPageRoute(builder: (_) => CollectionEditor(existing: c)));
          case 'sort':
            c.sortByYear = !c.sortByYear;
            c.touch();
            store.changed();
          case 'delete':
            if (await confirm(context, 'Verzeichnis löschen?',
                '„${c.name}“ mit ${fmtInt(c.items.length)} Einträgen wird dauerhaft gelöscht.')) {
              store.deleteCollection(c);
            }
        }
      },
      itemBuilder: (_) => [
        _i('import', Icons.file_download, 'Importieren (Excel, CSV, Zwischenablage)'),
        _i('export', Icons.table_view, 'Als Excel exportieren'),
        _i('copy', Icons.content_copy, 'Als Text kopieren'),
        _i('ratings', Icons.star_half, 'Bewertungen verwalten'),
        if (c.hasGroup && c.hasYear)
          _i('sort', Icons.sort,
              c.sortByYear ? 'Innerhalb ${c.groupLabel}: nach Titel' : 'Innerhalb ${c.groupLabel}: nach Jahr'),
        _i('edit', Icons.edit, 'Verzeichnis bearbeiten'),
        _i('delete', Icons.delete_outline, 'Verzeichnis löschen'),
      ],
    );
  }
}

InputDecoration _filterDecoration(String hint, String query, VoidCallback onClear) => InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.search),
      suffixIcon: query.isEmpty ? null : IconButton(icon: const Icon(Icons.clear), onPressed: onClear),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
    );

/// Gesamtliste mit Filter und Buchstabenleiste.
class ItemsTab extends StatefulWidget {
  final Collection collection;
  const ItemsTab({super.key, required this.collection});
  @override
  State<ItemsTab> createState() => _ItemsTabState();
}

class _ItemsTabState extends State<ItemsTab> with AutomaticKeepAliveClientMixin {
  final q = TextEditingController();
  String query = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = widget.collection;
    final list = filterItems(c.sorted, query);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
        child: TextField(
          controller: q,
          onChanged: (v) => setState(() => query = v),
          decoration: _filterDecoration('Filtern …', query, () {
            q.clear();
            setState(() => query = '');
          }),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
              query.isEmpty
                  ? '${fmtInt(c.items.length)} Einträge'
                  : '${fmtInt(list.length)} von ${fmtInt(c.items.length)}',
              style: Theme.of(context).textTheme.bodySmall),
        ),
      ),
      Expanded(
        child: AlphaList(
          count: list.length,
          extent: 68,
          letterAt: (i) => list[i].letter,
          empty: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
                c.items.isEmpty
                    ? 'Noch keine Einträge. Tippe auf + oder importiere eine Liste über das Menü oben rechts.'
                    : 'Keine Treffer.',
                textAlign: TextAlign.center),
          ),
          itemBuilder: (ctx, i) {
            final it = list[i];
            return ItemRow(
              item: it,
              collection: c,
              showGroup: true,
              onTap: () => Navigator.push(ctx,
                  MaterialPageRoute(builder: (_) => ItemPage(collectionId: c.id, itemId: it.id))),
              onGroupTap: c.hasGroup
                  ? () => Navigator.push(ctx,
                      MaterialPageRoute(builder: (_) => GroupPage(collectionId: c.id, groupKey: it.gk)))
                  : null,
            );
          },
        ),
      ),
    ]);
  }
}

/// Liste aller Gruppen (z. B. Interpreten) mit Filter und Buchstabenleiste.
class GroupsTab extends StatefulWidget {
  final Collection collection;
  const GroupsTab({super.key, required this.collection});
  @override
  State<GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<GroupsTab> with AutomaticKeepAliveClientMixin {
  final q = TextEditingController();
  String query = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = widget.collection;
    final list = filterGroups(c.groups, query);
    final scheme = Theme.of(context).colorScheme;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
        child: TextField(
          controller: q,
          onChanged: (v) => setState(() => query = v),
          decoration: _filterDecoration('${c.groupsName} filtern …', query, () {
            q.clear();
            setState(() => query = '');
          }),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
              query.isEmpty
                  ? '${fmtInt(c.groups.length)} ${c.groupsName}'
                  : '${fmtInt(list.length)} von ${fmtInt(c.groups.length)}',
              style: Theme.of(context).textTheme.bodySmall),
        ),
      ),
      Expanded(
        child: AlphaList(
          count: list.length,
          extent: 54,
          letterAt: (i) => list[i].letter,
          empty: const Padding(padding: EdgeInsets.all(32), child: Text('Keine Treffer.')),
          itemBuilder: (ctx, i) {
            final g = list[i];
            return InkWell(
              onTap: () => Navigator.push(ctx,
                  MaterialPageRoute(builder: (_) => GroupPage(collectionId: c.id, groupKey: g.key))),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(children: [
                  Expanded(
                    child: Text(g.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                        color: scheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
                    child: Text('${g.items.length}',
                        style: TextStyle(
                            color: scheme.onPrimaryContainer, fontWeight: FontWeight.bold)),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}
