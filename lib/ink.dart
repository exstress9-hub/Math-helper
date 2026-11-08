import 'package:flutter/material.dart';
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart';

/// Parmakla yazma ekranı. Seçilen metni Navigator.pop ile döndürür.
class InkPage extends StatefulWidget {
  const InkPage({super.key});
  @override
  State<InkPage> createState() => _InkPageState();
}

class _InkPageState extends State<InkPage> {
  static const lang = 'en-US'; // rakam ve işaretleri en iyi bu model okur
  final Ink _ink = Ink();
  final _rec = DigitalInkRecognizer(languageCode: lang);
  final _mm = DigitalInkRecognizerModelManager();
  Stroke? _cur;
  List<String> _cands = [];
  String _msg = 'Soruyu parmağınla yaz (örn: 2x+6=14), sonra Oku’ya bas.';
  bool _busy = false;

  @override
  void dispose() {
    _rec.close();
    super.dispose();
  }

  void _add(Offset p) => _cur!.points.add(StrokePoint(x: p.dx, y: p.dy, t: DateTime.now().millisecondsSinceEpoch));

  Future<void> _read() async {
    if (_ink.strokes.isEmpty) return;
    setState(() => _busy = true);
    try {
      if (!await _mm.isModelDownloaded(lang)) {
        setState(() => _msg = 'Yazı modeli indiriliyor (sadece ilk seferde internet gerekir)...');
        await _mm.downloadModel(lang, isWifiRequired: false);
      }
      final r = await _rec.recognize(_ink);
      setState(() {
        _cands = r.map((c) => c.text).toList();
        _msg = _cands.isEmpty ? 'Okunamadı, daha büyük ve net yaz.' : 'Doğru olanı seç (sonra kutuda düzeltebilirsin):';
      });
    } catch (_) {
      setState(() => _msg = 'Model indirilemedi. İnterneti açıp bir kez dene.');
    }
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D2747),
      appBar: AppBar(backgroundColor: const Color(0xFF12335C), foregroundColor: Colors.white, title: const Text('Parmakla yaz')),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: GestureDetector(
              onPanStart: (d) => setState(() {
                _cur = Stroke();
                _ink.strokes.add(_cur!);
                _add(d.localPosition);
              }),
              onPanUpdate: (d) => setState(() => _add(d.localPosition)),
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF4F1E4), borderRadius: BorderRadius.circular(14)),
                child: ClipRRect(borderRadius: BorderRadius.circular(14), child: CustomPaint(painter: _P(_ink), child: const SizedBox.expand())),
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text(_msg, style: const TextStyle(color: Colors.white70))),
          if (_cands.isNotEmpty)
            Wrap(spacing: 8, children: [
              for (final c in _cands.take(5)) ActionChip(label: Text(c, style: const TextStyle(fontSize: 18)), onPressed: () => Navigator.pop(context, c))
            ]),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              OutlinedButton(onPressed: () => setState(() { _ink.strokes.clear(); _cands = []; }), child: const Text('Temizle')),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: () => setState(() { if (_ink.strokes.isNotEmpty) _ink.strokes.removeLast(); }), child: const Text('Geri al')),
              const Spacer(),
              FilledButton(onPressed: _busy ? null : _read, child: Text(_busy ? '...' : 'Oku')),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _P extends CustomPainter {
  final Ink ink;
  _P(this.ink);
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = const Color(0xFF10223C)..strokeWidth = 4..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    for (final st in ink.strokes) {
      final path = Path();
      for (var i = 0; i < st.points.length; i++) {
        final pt = st.points[i];
        i == 0 ? path.moveTo(pt.x, pt.y) : path.lineTo(pt.x, pt.y);
      }
      c.drawPath(path, p);
    }
  }
  @override
  bool shouldRepaint(_P o) => true;
}
