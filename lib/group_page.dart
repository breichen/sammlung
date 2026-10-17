import 'package:flutter/material.dart';
import 'item_page.dart';
import 'models.dart';
import 'store.dart';
import 'widgets.dart';

/// Alle Einträge einer Gruppe (z. B. alle Alben eines Interpreten) mit Jahres-Histogramm.
class GroupPage extends StatelessWidget {
  final String collectionId, groupKey;
  const GroupPage({super.key, required this.collectionId, required this.groupKey});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final c = store.byId(collectionId);
          final g = c?.groupByKey(groupKey);
          if (c == null || g == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted && Navigator.canPop(context)) Navigator.pop(context);
            });
            return const Scaffold();
          }
          final items = List<Item>.of(g.items)
            ..sort((a, b) {
              final d = (a.year ?? 99999).compareTo(b.year ?? 99999);
              return d != 0 ? d : a.tk.compareTo(b.tk);
            });
          final years = <int, int>{};
          for (final it in items) {
            if (it.year != null) years[it.year!] = (years[it.year!] ?? 0) + 1;
          }
          return Scaffold(
            appBar: AppBar(title: Text(g.name)),
            body: ListView.builder(
              itemCount: items.length + 1,
              itemBuilder: (ctx, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${items.length} ${items.length == 1 ? 'Eintrag' : 'Einträge'}',
                          style: Theme.of(ctx)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      if (c.hasYear && years.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        YearHistogram(counts: years, unit: c.name, barWidth: 30),
                      ],
                    ]),
                  );
                }
                final it = items[i - 1];
                return SizedBox(
                  height: 60,
                  child: ItemRow(
                    item: it,
                    collection: c,
                    showGroup: false,
                    onTap: () => Navigator.push(ctx,
                        MaterialPageRoute(builder: (_) => ItemPage(collectionId: c.id, itemId: it.id))),
                  ),
                );
              },
            ),
          );
        },
      );
}
