import 'package:flutter/material.dart';
import 'group_page.dart';
import 'item_page.dart';
import 'models.dart';
import 'widgets.dart';

Widget _card(BuildContext context, String title, Widget child) => Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          child,
        ]),
      ),
    );

class StatsTab extends StatelessWidget {
  final Collection collection;
  const StatsTab({super.key, required this.collection});

  Widget _tile(BuildContext context, String value, String label) => Expanded(
        child: Card(
          elevation: 0,
          color: Colors.white,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            child: Column(children: [
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
              const SizedBox(height: 2),
              Text(label,
                  textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = collection;
    final scheme = Theme.of(context).colorScheme;
    final years = c.yearCounts;
    final withYear = years.values.fold<int>(0, (a, b) => a + b);

    // Gruppen mit den meisten Einträgen
    final top = c.hasGroup ? (List<GroupEntry>.of(c.groups)
      ..sort((a, b) {
        final d = b.items.length.compareTo(a.items.length);
        return d != 0 ? d : a.key.compareTo(b.key);
      })) : <GroupEntry>[];
    final topN = top.take(20).toList();
    final topMax = topN.isEmpty ? 1 : topN.first.items.length;

    // zuletzt benutzt
    final recent = c.items.where((i) => i.listens.isNotEmpty).toList()
      ..sort((a, b) => b.lastListen!.compareTo(a.lastListen!));

    return ListView(padding: const EdgeInsets.all(10), children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          _tile(context, fmtInt(c.items.length), 'Einträge'),
          if (c.hasGroup) _tile(context, fmtInt(c.groups.length), c.groupsName),
          if (c.hasYear && years.isNotEmpty)
            _tile(context, '${years.keys.reduce((a, b) => a < b ? a : b)}–${years.keys.reduce((a, b) => a > b ? a : b)}',
                'Zeitraum'),
        ]),
      ),
      if (c.hasYear)
        _card(
          context,
          'Einträge pro Jahr',
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            YearHistogram(counts: years, unit: c.name),
            if (withYear < c.items.length)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('${fmtInt(c.items.length - withYear)} Einträge ohne Jahr nicht enthalten',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
          ]),
        ),
      if (c.hasGroup && topN.isNotEmpty)
        _card(
          context,
          '${c.groupsName} mit den meisten Einträgen',
          Column(children: [
            for (var i = 0; i < topN.length; i++)
              InkWell(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => GroupPage(collectionId: c.id, groupKey: topN[i].key))),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    SizedBox(
                      width: 26,
                      child: Text('${i + 1}.', style: Theme.of(context).textTheme.bodySmall),
                    ),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(topN[i].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: topN[i].items.length / topMax,
                            minHeight: 5,
                            backgroundColor: scheme.surfaceContainerHighest,
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 10),
                    Text('${topN[i].items.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
          ]),
        ),
      if (c.ratings.isNotEmpty)
        _card(
          context,
          'Bewertungen',
          Column(children: [
            for (final d in c.ratings)
              Builder(builder: (_) {
                final vals = [for (final it in c.items) if (it.ratings[d.id] != null) it.ratings[d.id]!];
                final avg = vals.isEmpty ? 0.0 : vals.reduce((a, b) => a + b) / vals.length;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: Color(d.color),
                      child: Text(d.letter,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(d.name)),
                    Text(
                        vals.isEmpty
                            ? 'keine Wertungen'
                            : '${fmtInt(vals.length)} bewertet · Ø ${avg.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ]),
                );
              }),
          ]),
        ),
      if (recent.isNotEmpty)
        _card(
          context,
          'Zuletzt ${c.usageLabel.toLowerCase()}',
          Column(children: [
            for (final it in recent.take(10))
              InkWell(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ItemPage(collectionId: c.id, itemId: it.id))),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(it.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (c.hasGroup && it.group.isNotEmpty)
                          Text(it.group,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall),
                      ]),
                    ),
                    Text(fmtDateTime(it.lastListen!), style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
              ),
          ]),
        ),
      const SizedBox(height: 70),
    ]);
  }
}
