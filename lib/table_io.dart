// Tabellen lesen und schreiben: xlsx (ohne Zusatzpaket) und CSV/TSV.
import 'dart:convert';
import 'dart:io' show ZLibDecoder;
import 'dart:typed_data';
import 'package:xml/xml.dart';

// ───────────────────────── ZIP ─────────────────────────
final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> data) {
  var c = 0xFFFFFFFF;
  for (final b in data) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

/// Liest die für uns relevanten Dateien (Tabellenblätter, Shared Strings) aus einer xlsx.
Map<String, Uint8List> _unzip(Uint8List data) {
  final bd = ByteData.sublistView(data);
  var eocd = -1;
  final lowest = data.length - 22 - 65535;
  for (var i = data.length - 22; i >= 0 && i >= lowest; i--) {
    if (bd.getUint32(i, Endian.little) == 0x06054b50) {
      eocd = i;
      break;
    }
  }
  if (eocd < 0) throw const FormatException('Das ist keine gültige xlsx-Datei.');
  final count = bd.getUint16(eocd + 10, Endian.little);
  var p = bd.getUint32(eocd + 16, Endian.little);
  final out = <String, Uint8List>{};
  for (var n = 0; n < count; n++) {
    if (bd.getUint32(p, Endian.little) != 0x02014b50) break;
    final method = bd.getUint16(p + 10, Endian.little);
    final compSize = bd.getUint32(p + 20, Endian.little);
    final nameLen = bd.getUint16(p + 28, Endian.little);
    final extraLen = bd.getUint16(p + 30, Endian.little);
    final commentLen = bd.getUint16(p + 32, Endian.little);
    final localOff = bd.getUint32(p + 42, Endian.little);
    final name = utf8.decode(data.sublist(p + 46, p + 46 + nameLen), allowMalformed: true);
    p += 46 + nameLen + extraLen + commentLen;
    if (!(name.startsWith('xl/worksheets/sheet') || name == 'xl/sharedStrings.xml')) continue;
    final lNameLen = bd.getUint16(localOff + 26, Endian.little);
    final lExtraLen = bd.getUint16(localOff + 28, Endian.little);
    final start = localOff + 30 + lNameLen + lExtraLen;
    final raw = data.sublist(start, start + compSize);
    out[name] = method == 0
        ? Uint8List.fromList(raw)
        : Uint8List.fromList(ZLibDecoder(raw: true).convert(raw));
  }
  return out;
}

Uint8List _zip(Map<String, List<int>> files) {
  final out = BytesBuilder();
  final central = BytesBuilder();
  var offset = 0;
  files.forEach((name, data) {
    final nameBytes = utf8.encode(name);
    final crc = _crc32(data);
    final local = ByteData(30)
      ..setUint32(0, 0x04034b50, Endian.little)
      ..setUint16(4, 20, Endian.little)
      ..setUint16(6, 0x0800, Endian.little)
      ..setUint16(8, 0, Endian.little)
      ..setUint16(10, 0, Endian.little)
      ..setUint16(12, 33, Endian.little)
      ..setUint32(14, crc, Endian.little)
      ..setUint32(18, data.length, Endian.little)
      ..setUint32(22, data.length, Endian.little)
      ..setUint16(26, nameBytes.length, Endian.little)
      ..setUint16(28, 0, Endian.little);
    out
      ..add(local.buffer.asUint8List())
      ..add(nameBytes)
      ..add(data);
    final cd = ByteData(46)
      ..setUint32(0, 0x02014b50, Endian.little)
      ..setUint16(4, 20, Endian.little)
      ..setUint16(6, 20, Endian.little)
      ..setUint16(8, 0x0800, Endian.little)
      ..setUint16(10, 0, Endian.little)
      ..setUint16(12, 0, Endian.little)
      ..setUint16(14, 33, Endian.little)
      ..setUint32(16, crc, Endian.little)
      ..setUint32(20, data.length, Endian.little)
      ..setUint32(24, data.length, Endian.little)
      ..setUint16(28, nameBytes.length, Endian.little)
      ..setUint16(30, 0, Endian.little)
      ..setUint16(32, 0, Endian.little)
      ..setUint16(34, 0, Endian.little)
      ..setUint16(36, 0, Endian.little)
      ..setUint32(38, 0, Endian.little)
      ..setUint32(42, offset, Endian.little);
    central
      ..add(cd.buffer.asUint8List())
      ..add(nameBytes);
    offset += 30 + nameBytes.length + data.length;
  });
  final cdBytes = central.toBytes();
  final eocd = ByteData(22)
    ..setUint32(0, 0x06054b50, Endian.little)
    ..setUint16(4, 0, Endian.little)
    ..setUint16(6, 0, Endian.little)
    ..setUint16(8, files.length, Endian.little)
    ..setUint16(10, files.length, Endian.little)
    ..setUint32(12, cdBytes.length, Endian.little)
    ..setUint32(16, offset, Endian.little)
    ..setUint16(20, 0, Endian.little);
  out
    ..add(cdBytes)
    ..add(eocd.buffer.asUint8List());
  return out.toBytes();
}

// ───────────────────────── XLSX lesen ─────────────────────────
int _colIndex(String ref) {
  var n = 0;
  var found = false;
  for (final u in ref.codeUnits) {
    if (u >= 65 && u <= 90) {
      n = n * 26 + (u - 64);
      found = true;
    } else {
      break;
    }
  }
  return found ? n - 1 : -1;
}

String _num(String v) {
  final d = double.tryParse(v);
  if (d == null) return v;
  return d == d.roundToDouble() && d.abs() < 1e15 ? d.toInt().toString() : v;
}

/// Liest das erste Tabellenblatt als Liste von Zeilen mit Text-Zellen.
/// Läuft als Top-Level-Funktion, damit sie per compute() im Hintergrund laufen kann.
List<List<String>> readXlsx(Uint8List bytes) {
  final files = _unzip(bytes);
  final sheetNames = files.keys.where((k) => k.startsWith('xl/worksheets/sheet')).toList()..sort();
  if (sheetNames.isEmpty) throw const FormatException('Kein Tabellenblatt gefunden.');

  final shared = <String>[];
  final ss = files['xl/sharedStrings.xml'];
  if (ss != null) {
    final doc = XmlDocument.parse(utf8.decode(ss));
    for (final si in doc.findAllElements('si')) {
      shared.add(si
          .findAllElements('t')
          .where((t) => t.parentElement?.name.local != 'rPh')
          .map((t) => t.innerText)
          .join());
    }
  }

  final sheet = XmlDocument.parse(utf8.decode(files[sheetNames.first]!));
  final rows = <List<String>>[];
  for (final row in sheet.findAllElements('row')) {
    final cells = <String>[];
    for (final c in row.findElements('c')) {
      final col = _colIndex(c.getAttribute('r') ?? '');
      final type = c.getAttribute('t');
      var v = '';
      if (type == 'inlineStr') {
        v = c.findAllElements('t').map((t) => t.innerText).join();
      } else {
        final raw = c.getElement('v')?.innerText ?? '';
        if (type == 's') {
          final i = int.tryParse(raw);
          v = (i != null && i >= 0 && i < shared.length) ? shared[i] : '';
        } else if (type == 'b') {
          v = raw == '1' ? 'WAHR' : 'FALSCH';
        } else if (type == null || type == 'n') {
          v = _num(raw);
        } else {
          v = raw;
        }
      }
      if (col >= 0) {
        while (cells.length <= col) {
          cells.add('');
        }
        cells[col] = v;
      } else {
        cells.add(v);
      }
    }
    rows.add(cells);
  }
  return rows;
}

// ───────────────────────── XLSX schreiben ─────────────────────────
String _esc(String s) => s
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

String _colName(int i) {
  var s = '';
  var n = i + 1;
  while (n > 0) {
    final r = (n - 1) % 26;
    s = String.fromCharCode(65 + r) + s;
    n = (n - 1) ~/ 26;
  }
  return s;
}

/// Zellen: String, int/double oder null (leer). Top-Level für compute().
Uint8List writeXlsx(List<List<Object?>> rows) {
  final sb = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<cols><col min="1" max="2" width="32" customWidth="1"/></cols><sheetData>');
  for (var r = 0; r < rows.length; r++) {
    sb.write('<row r="${r + 1}">');
    final row = rows[r];
    for (var c = 0; c < row.length; c++) {
      final v = row[c];
      if (v == null || v == '') continue;
      final ref = '${_colName(c)}${r + 1}';
      if (v is num) {
        sb.write('<c r="$ref"><v>$v</v></c>');
      } else {
        sb.write('<c r="$ref" t="inlineStr"><is><t xml:space="preserve">${_esc(v.toString())}</t></is></c>');
      }
    }
    sb.write('</row>');
  }
  sb.write('</sheetData></worksheet>');

  const header = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
  return _zip({
    '[Content_Types].xml': utf8.encode('$header'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
        '</Types>'),
    '_rels/.rels': utf8.encode('$header'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
        '</Relationships>'),
    'xl/workbook.xml': utf8.encode('$header'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<sheets><sheet name="Sammlung" sheetId="1" r:id="rId1"/></sheets></workbook>'),
    'xl/_rels/workbook.xml.rels': utf8.encode('$header'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
        '</Relationships>'),
    'xl/worksheets/sheet1.xml': utf8.encode(sb.toString()),
  });
}

// ───────────────────────── CSV / TSV ─────────────────────────
String detectDelimiter(String text) {
  final head = text.split('\n').take(5).join('\n');
  if (head.contains('\t')) return '\t';
  if (head.contains(';')) return ';';
  return ',';
}

List<List<String>> parseDelimited(String text, String delim) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  final d = delim.codeUnitAt(0);
  final u = text.codeUnits;
  for (var i = 0; i < u.length; i++) {
    final ch = u[i];
    if (quoted) {
      if (ch == 0x22) {
        if (i + 1 < u.length && u[i + 1] == 0x22) {
          cell.writeCharCode(0x22);
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.writeCharCode(ch);
      }
    } else if (ch == 0x22 && cell.isEmpty) {
      quoted = true;
    } else if (ch == d) {
      row.add(cell.toString());
      cell.clear();
    } else if (ch == 0x0A || ch == 0x0D) {
      if (ch == 0x0D && i + 1 < u.length && u[i + 1] == 0x0A) i++;
      row.add(cell.toString());
      cell.clear();
      rows.add(row);
      row = <String>[];
    } else {
      cell.writeCharCode(ch);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(row);
  }
  return rows;
}

List<List<String>> parseTextTable(String text) {
  final t = text.startsWith('\uFEFF') ? text.substring(1) : text;
  return parseDelimited(t, detectDelimiter(t));
}
