import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'models.dart';

const starColor = Color(0xFFE9A23B);

void snack(BuildContext context, String msg) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));

Future<bool> confirm(BuildContext context, String title, String text, {String yes = 'Löschen'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(text),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Abbrechen')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(yes)),
      ],
    ),
  );
  return ok == true;
}

/// Kleine farbige Marke: Buchstabe + Sterne, z. B. "R ★ 3".
class RatingPill extends StatelessWidget {
  final RatingDef def;
  final int value;
  const RatingPill({super.key, required this.def, required this.value});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Color(def.color), borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(def.letter,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
          const SizedBox(width: 2),
          const Icon(Icons.star, size: 11, color: Colors.white),
          Text('$value', style: const TextStyle(color: Colors.white, fontSize: 11)),
        ]),
      );
}

/// 5 Sterne zum Antippen. Erneutes Tippen auf den gewählten Stern löscht die Wertung.
class StarRow extends StatelessWidget {
  final int value;
  final Color color;
  final ValueChanged<int> onChanged;
  const StarRow({super.key, required this.value, required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= 5; i++)
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () => onChanged(value == i ? 0 : i),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Icon(i <= value ? Icons.star : Icons.star_border, color: color, size: 30),
            ),
          ),
      ]);
}

/// Eine Zeile der Gesamtliste. Feste Höhe, damit Springen und Scrollen schnell bleiben.
class ItemRow extends StatelessWidget {
  final Item item;
  final Collection collection;
  final bool showGroup;
  final VoidCallback onTap;
  final VoidCallback? onGroupTap;
  const ItemRow({
    super.key,
    required this.item,
    required this.collection,
    required this.showGroup,
    required this.onTap,
    this.onGroupTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = collection;
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                if (showGroup && c.hasGroup)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onGroupTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(item.group.isEmpty ? '–' : item.group,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: primary, fontSize: 13)),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (c.hasYear && item.year != null)
                Text('${item.year}', style: const TextStyle(color: Colors.black54, fontSize: 13)),
              if (item.ratings.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    for (final d in c.ratings)
                      if (item.ratings[d.id] != null) RatingPill(def: d, value: item.ratings[d.id]!),
                  ]),
                ),
            ],
          ),
        ]),
      ),
    );
  }
}

/// Liste mit Buchstabenleiste links. Die Leiste springt zum ersten Eintrag des Buchstabens.
/// Alle Zeilen haben dieselbe Höhe, dadurch ist das Springen sofort und exakt.
class AlphaList extends StatefulWidget {
  final int count;
  final String Function(int) letterAt;
  final IndexedWidgetBuilder itemBuilder;
  final double extent;
  final Widget empty;
  const AlphaList({
    super.key,
    required this.count,
    required this.letterAt,
    required this.itemBuilder,
    required this.extent,
    required this.empty,
  });

  @override
  State<AlphaList> createState() => _AlphaListState();
}

class _AlphaListState extends State<AlphaList> {
  final controller = ScrollController();
  final current = ValueNotifier<String>('#');

  @override
  void initState() {
    super.initState();
    controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    controller.dispose();
    current.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (widget.count == 0 || !controller.hasClients) return;
    final i = (controller.offset / widget.extent).floor().clamp(0, widget.count - 1).toInt();
    current.value = widget.letterAt(i);
  }

  Map<String, int> _firstIndex() {
    final first = <String, int>{};
    for (var i = 0; i < widget.count; i++) {
      first.putIfAbsent(widget.letterAt(i), () => i);
    }
    return first;
  }

  void _jumpTo(String letter, Map<String, int> first) {
    var idx = first[letter];
    if (idx == null) {
      for (var k = alphabet.indexOf(letter) + 1; k < alphabet.length && idx == null; k++) {
        idx = first[alphabet[k]];
      }
      idx ??= widget.count - 1;
    }
    if (!controller.hasClients) return;
    final target = (idx * widget.extent).clamp(0.0, controller.position.maxScrollExtent).toDouble();
    controller.jumpTo(target);
  }

  Widget _bar(Map<String, int> first) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 26,
      child: LayoutBuilder(builder: (context, cons) {
        final h = cons.maxHeight;
        final fs = (h / alphabet.length * 0.62).clamp(8.0, 12.0).toDouble();
        void hit(double dy) {
          final i = (dy / h * alphabet.length).floor().clamp(0, alphabet.length - 1).toInt();
          _jumpTo(alphabet[i], first);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => hit(d.localPosition.dy),
          onVerticalDragUpdate: (d) => hit(d.localPosition.dy),
          child: ValueListenableBuilder<String>(
            valueListenable: current,
            builder: (_, cur, __) => Column(children: [
              for (final l in alphabet)
                Expanded(
                  child: Center(
                    child: Text(l,
                        style: TextStyle(
                          fontSize: fs,
                          fontWeight: l == cur ? FontWeight.w900 : FontWeight.w500,
                          color: l == cur
                              ? scheme.primary
                              : (first.containsKey(l) ? scheme.onSurface : scheme.outlineVariant),
                        )),
                  ),
                ),
            ]),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.count == 0) return Center(child: widget.empty);
    final first = _firstIndex();
    return Row(children: [
      _bar(first),
      Expanded(
        child: ListView.builder(
          controller: controller,
          itemExtent: widget.extent,
          itemCount: widget.count,
          itemBuilder: widget.itemBuilder,
        ),
      ),
    ]);
  }
}

/// Balkendiagramm: Anzahl pro Jahr. Bei vielen Jahren seitlich scrollbar, Balken antippbar.
class YearHistogram extends StatefulWidget {
  final Map<int, int> counts;
  final String unit;
  final double barWidth;
  const YearHistogram({super.key, required this.counts, required this.unit, this.barWidth = 14});

  @override
  State<YearHistogram> createState() => _YearHistogramState();
}

class _YearHistogramState extends State<YearHistogram> {
  int? selected; // Index ab minYear
  final scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // neueste Jahre zuerst zeigen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final counts = widget.counts;
    if (counts.isEmpty) return const Text('Keine Jahresangaben vorhanden.');
    final minY = counts.keys.reduce(math.min);
    final maxY = counts.keys.reduce(math.max);
    final n = maxY - minY + 1;
    final maxC = counts.values.reduce(math.max);
    final color = Theme.of(context).colorScheme.primary;
    final sel = (selected != null && selected! < n) ? selected : null;

    return LayoutBuilder(builder: (context, cons) {
      final width = math.max(cons.maxWidth, n * widget.barWidth);
      final bw = width / n;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          sel == null
              ? 'Tippe auf einen Balken'
              : '${minY + sel}: ${counts[minY + sel] ?? 0} ${widget.unit}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 150,
          child: SingleChildScrollView(
            controller: scroll,
            scrollDirection: Axis.horizontal,
            child: GestureDetector(
              onTapDown: (d) => setState(
                  () => selected = (d.localPosition.dx / bw).floor().clamp(0, n - 1).toInt()),
              child: CustomPaint(
                size: Size(width, 150),
                painter: _HistPainter(counts, minY, n, maxC, color, sel, bw),
              ),
            ),
          ),
        ),
      ]);
    });
  }
}

class _HistPainter extends CustomPainter {
  final Map<int, int> counts;
  final int minY, n, maxC;
  final Color color;
  final int? selected;
  final double bw;
  _HistPainter(this.counts, this.minY, this.n, this.maxC, this.color, this.selected, this.bw);

  void _text(Canvas canvas, String s, Offset center, {Color col = Colors.black54, bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(
              fontSize: 10, color: col, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const labelH = 18.0;
    const topPad = 14.0;
    final chartH = size.height - labelH - topPad;
    final step = bw >= 28 ? 1 : (bw >= 14 ? 2 : 5);
    final base = Paint()..color = color.withAlpha(170);
    final hi = Paint()..color = color;
    canvas.drawLine(Offset(0, size.height - labelH), Offset(size.width, size.height - labelH),
        Paint()..color = Colors.black26);
    for (var i = 0; i < n; i++) {
      final y = minY + i;
      final c = counts[y] ?? 0;
      final cx = i * bw + bw / 2;
      if (c > 0) {
        final h = math.max(2.0, chartH * c / maxC);
        final rect = Rect.fromLTWH(i * bw + bw * 0.12, size.height - labelH - h, bw * 0.76, h);
        canvas.drawRRect(
            RRect.fromRectAndCorners(rect, topLeft: const Radius.circular(3), topRight: const Radius.circular(3)),
            i == selected ? hi : base);
        if (bw >= 20 || i == selected) {
          _text(canvas, '$c', Offset(cx, rect.top - 7), col: Colors.black87, bold: i == selected);
        }
      }
      if (y % step == 0 || i == selected) {
        _text(canvas, '$y', Offset(cx, size.height - labelH / 2),
            col: i == selected ? Colors.black87 : Colors.black54, bold: i == selected);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HistPainter old) =>
      old.selected != selected || old.counts != counts || old.bw != bw;
}
