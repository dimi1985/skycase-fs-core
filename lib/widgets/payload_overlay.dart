import 'dart:ui';
import 'package:flutter/material.dart';

class PayloadOverlay extends StatelessWidget {
  final VoidCallback onClose;

  const PayloadOverlay({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;


    return Center(
      child: Container(
        width: isMobile ? MediaQuery.of(context).size.width * 0.95 : 500,
        height: isMobile ? MediaQuery.of(context).size.height * 0.85 : 600,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: Stack(
          children: [
            // ✨ Blur effect
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: const SizedBox.expand(),
              ),
            ),

            // 📦 Payload list
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.inventory, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text(
                      "Payload Overview",
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: onClose,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
