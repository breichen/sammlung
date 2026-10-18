import 'package:flutter/material.dart';
import 'group_page.dart';
import 'item_page.dart';
import 'models.dart';
import 'store.dart';
import 'widgets.dart';

/// Alle Einträge eines Jahres (aus dem Histogramm erreichbar).
class YearPage extends StatelessWidget {
  final String collectionId;
  final int year;
  const YearPage({super.key, required this.collectionId, required this.year});

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
          final list = c.sorted.where((i) => i.year == year).toList();
          return Scaffold(
            appBar: AppBar(title: Text('$year')),
            body: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${fmtInt(list.length)} ${list.length == 1 ? 'Eintrag' : 'Einträge'}',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? const Center(child: Text('Keine Einträge in diesem Jahr.'))
                    : ListView.builder(
                        itemExtent: 68,
                        itemCount: list.length,
                        itemBuilder: (ctx, i) {
                          final it = list[i];
                          return ItemRow(
                            item: it,
                            collection: c,
                            showGroup: true,
                            onTap: () => Navigator.push(
                                ctx,
                                MaterialPageRoute(
                                    builder: (_) => ItemPage(collectionId: c.id, itemId: it.id))),
                            onGroupTap: c.hasGroup
                                ? () => Navigator.push(
                                    ctx,
                                    MaterialPageRoute(
                                        builder: (_) => GroupPage(collectionId: c.id, groupKey: it.gk)))
                                : null,
                          );
                        },
                      ),
              ),
            ]),
          );
        },
      );
}
