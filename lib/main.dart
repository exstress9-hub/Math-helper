import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'ink.dart';

void main() => runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: App()));

class App extends StatefulWidget {
  const App({super.key});
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final WebViewController c;
  @override
  void initState() {
    super.initState();
    c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0D2747))
      ..addJavaScriptChannel('Foto', onMessageReceived: (m) => _onMsg(m.message))
      ..loadFlutterAsset('assets/index.html');
  }

  Future<void> _js(String code) => c.runJavaScript(code);

  Future<void> _onMsg(String m) async {
    if (m == 'ink') {
      final t = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const InkPage()));
      if (t != null) await _js('setFromPhoto(${jsonEncode(t)},"ink")');
      return;
    }
    if (m != 'open') return;
    final src = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (_) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(leading: const Icon(Icons.photo_camera), title: const Text('Kamera'), onTap: () => Navigator.pop(context, ImageSource.camera)),
              ListTile(leading: const Icon(Icons.photo), title: const Text('Galeri'), onTap: () => Navigator.pop(context, ImageSource.gallery)),
            ])));
    if (src == null) return;
    final f = await ImagePicker().pickImage(source: src, maxWidth: 1600, imageQuality: 85);
    if (f == null) return;
    await _js('photoErr("Okunuyor...")');
    final text = await _ocr(f.path);
    if (text == null || text.trim().isEmpty) {
      await _js('photoErr("Yazı okunamadı. Daha net ve yakından çekmeyi dene.")');
      return;
    }
    await _js('setFromPhoto(${jsonEncode(text.trim())},"ocr")');
  }

  // Tamamen telefonda (internetsiz) okuma
  Future<String?> _ocr(String path) async {
    final rec = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final t = await rec.processImage(InputImage.fromFilePath(path));
      return t.text.replaceAll('\n', ' ');
    } catch (_) {
      return null;
    } finally {
      rec.close();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: const Color(0xFF0D2747), body: SafeArea(child: WebViewWidget(controller: c)));
}
