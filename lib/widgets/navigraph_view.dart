import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class NavigraphWebview extends StatefulWidget {
  const NavigraphWebview({super.key});

  @override
  State<NavigraphWebview> createState() => _NavigraphWebviewState();
}

class _NavigraphWebviewState extends State<NavigraphWebview> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();

    controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0xFF000000))
          ..loadRequest(Uri.parse("https://charts.navigraph.com"));
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: controller);
  }
}
