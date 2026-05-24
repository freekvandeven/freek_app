import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

/// Push this page when the platform doesn't support the native
/// image_cropper (desktop / web) — uses the Flutter-rendered
/// `crop_your_image` widget instead. Returns the cropped bytes via
/// `Navigator.pop`, or `null` if the user cancels (WISH-0072).
Future<Uint8List?> showFlutterCropperPage(
  BuildContext context,
  Uint8List bytes,
) {
  return Navigator.of(context).push<Uint8List>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _FlutterCropperPage(bytes: bytes),
    ),
  );
}

class _FlutterCropperPage extends StatefulWidget {
  final Uint8List bytes;
  const _FlutterCropperPage({required this.bytes});

  @override
  State<_FlutterCropperPage> createState() => _FlutterCropperPageState();
}

class _FlutterCropperPageState extends State<_FlutterCropperPage> {
  final _controller = CropController();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop'),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => _controller.crop(),
            child: const Text('Done'),
          ),
        ],
      ),
      body: Crop(
        image: widget.bytes,
        controller: _controller,
        onCropped: (result) {
          if (!mounted) return;
          if (result is CropSuccess) {
            Navigator.of(context).pop(result.croppedImage);
          } else {
            setState(() => _busy = false);
          }
        },
        onStatusChanged: (status) {
          if (status == CropStatus.cropping) {
            setState(() => _busy = true);
          }
        },
      ),
    );
  }
}
