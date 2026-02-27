import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skycase/providers/efb_ui_mode_provider.dart';
import 'package:skycase/screens/home_screen.dart';
import 'package:skycase/screens/home_advanced_screen.dart';

class HomeControllerScreen extends StatefulWidget {
  const HomeControllerScreen({super.key});

  @override
  State<HomeControllerScreen> createState() => _HomeControllerScreenState();
}

class _HomeControllerScreenState extends State<HomeControllerScreen> {
  bool _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_didInit) {
      _didInit = true;
      context.read<EfbUiModeProvider>().load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final efbMode = context.watch<EfbUiModeProvider>();

    if (!efbMode.isLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return efbMode.isCinematic
        ? const HomeAdvancedScreen()
        : const HomeScreen();
  }
}
