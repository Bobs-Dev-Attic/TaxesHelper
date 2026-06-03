import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Small helper that renders a receipt image from either freshly-picked bytes
/// or a remote download URL — whichever is provided.
class _ReceiptImage extends StatelessWidget {
  const _ReceiptImage({this.bytes, this.url, this.fit = BoxFit.cover});

  final Uint8List? bytes;
  final String? url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (bytes != null) {
      return Image.memory(bytes!, fit: fit);
    }
    if (url != null) {
      return Image.network(
        url!,
        fit: fit,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (context, _, __) => const Center(
          child: Icon(Icons.broken_image_outlined),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

/// A tappable thumbnail with a remove button, shown on the edit form.
class ReceiptThumbnail extends StatelessWidget {
  const ReceiptThumbnail({
    super.key,
    this.bytes,
    this.url,
    required this.onView,
    this.onRemove,
  });

  final Uint8List? bytes;
  final String? url;
  final VoidCallback onView;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: onView,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: _ReceiptImage(bytes: bytes, url: url),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Remove receipt',
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: onRemove,
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          left: 8,
          child: Material(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.zoom_in, color: Colors.white, size: 18),
                  SizedBox(width: 4),
                  Text('Tap to view',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-screen, pinch-to-zoom receipt viewer.
class ReceiptViewerScreen extends StatelessWidget {
  const ReceiptViewerScreen({super.key, this.bytes, this.url});

  final Uint8List? bytes;
  final String? url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Receipt'),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: _ReceiptImage(bytes: bytes, url: url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
