import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Machi Navi',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const WebViewScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  int _progress = 0; // 0..100

  static const String kInitialUrl = 'https://flutter.dev';

  _handlePopInvokedWithResult(didPop, result) async {
    if (didPop) return;
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    } else {
      if (context.mounted) {
        Navigator.of(context).maybePop();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) => setState(() => _progress = progress),
          onPageStarted: (_) {},
          onPageFinished: (_) => setState(() => _progress = 100),
          onWebResourceError: (error) {
            // Optional: you can show a snackbar or error UI
            debugPrint(
              'WebView error: ${error.errorCode} ${error.description}',
            );
          },
        ),
      )
      ..loadRequest(Uri.parse(kInitialUrl));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _handlePopInvokedWithResult,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Machi Navi'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _controller.reload(),
              tooltip: 'Reload',
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: _progress < 100
                ? LinearProgressIndicator(value: _progress / 100)
                : const SizedBox.shrink(),
          ),
        ),
        body: SafeArea(child: WebViewWidget(controller: _controller)),
      ),
    );
  }
}
