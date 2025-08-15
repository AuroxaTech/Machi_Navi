import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
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
  static const String kInitialUrl = 'https://apps.machinavi.net/';

  late final WebViewController _controller;
  int _progress = 0; // 0..100
  bool _showSplash = true;
  late DateTime _splashStart;
  WebResourceError? _error;

  Future<void> _logWebSessionState() async {
    try {
      final cookies = await _controller
          .runJavaScriptReturningResult('document.cookie')
          .timeout(const Duration(seconds: 2));
      final lsLen = await _controller
          .runJavaScriptReturningResult('localStorage.length')
          .timeout(const Duration(seconds: 2));
      final url = await _controller.currentUrl();
      log('[WebView] url=$url cookies=$cookies localStorage.length=$lsLen');
    } catch (e) {
      log('[WebView] Failed to inspect session state: $e');
    }
  }

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
    _splashStart = DateTime.now();
    FlutterNativeSplash.remove();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            setState(() => _progress = progress);
            _maybeHideSplash();
          },
          onPageStarted: (_) {},
          onPageFinished: (_) async {
            setState(() => _progress = 100);
            _maybeHideSplash(force: true);
            await _logWebSessionState();
          },
          onWebResourceError: (error) {
            debugPrint(
              'WebView error: ${error.errorCode} ${error.description}',
            );
            setState(() {
              _error = error;
              _showSplash = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(kInitialUrl));

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _maybeHideSplash(force: true);
    });
  }

  void _maybeHideSplash({bool force = false}) {
    if (!_showSplash) return;
    final elapsed = DateTime.now().difference(_splashStart);
    final minElapsed = elapsed.inMilliseconds >= 800;
    if (force || (_progress > 0 && minElapsed)) {
      setState(() => _showSplash = false);
    }
  }

  Future<void> _retry() async {
    setState(() {
      _error = null;
      _progress = 0;
      _showSplash = true; // brief overlay while retry begins
      _splashStart = DateTime.now();
    });
    await _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _handlePopInvokedWithResult,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: _error == null && _progress < 100
                ? LinearProgressIndicator(
                    value: _progress / 100,
                    color: const Color(0xFF34A21A),
                    backgroundColor: const Color(
                      0xFF34A21A,
                    ).withValues(alpha: 0.2),
                  )
                : const SizedBox.shrink(),
          ),
        ),
        body: Stack(
          children: [
            RefreshIndicator(
              color: const Color(0xFF34A21A),
              backgroundColor: Colors.white,
              onRefresh: () async {
                await _controller.reload();
                // Wait briefly to let the refresh indicator show.
                await Future.delayed(const Duration(milliseconds: 300));
              },
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Give WebView a bounded size equal to the viewport to
                  // prevent infinite height constraints in platform view.
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: constraints.maxHeight,
                      width: constraints.maxWidth,
                      child: SafeArea(
                        child: WebViewWidget(controller: _controller),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_showSplash)
              Positioned.fill(
                child: Container(
                  color: Colors.white,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'MachiNavi',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        const SizedBox(
                          width: 200,
                          child: LinearProgressIndicator(
                            color: Color(0xFF34A21A),
                            backgroundColor: Color(0xFF34A21A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_error != null)
              Positioned.fill(
                child: Container(
                  color: Colors.white,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi_off, size: 56, color: Colors.black54),
                          const SizedBox(height: 12),
                          const Text(
                            'Something went wrong',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _error!.description,
                            style: const TextStyle(color: Colors.black54),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF34A21A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            ),
                            onPressed: _retry,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
