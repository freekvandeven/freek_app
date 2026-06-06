import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:super_clipboard/super_clipboard.dart'
    show DataReader, FileFormat;
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../services/log_service.dart';

/// File dropped onto a [FileDropTarget].
class DroppedFile {
  final Uint8List bytes;
  final String fileName;

  /// MIME type from the OS, when reported. `null` when unknown.
  final String? mimeType;

  const DroppedFile({
    required this.bytes,
    required this.fileName,
    this.mimeType,
  });

  bool get isImage => mimeType?.startsWith('image/') ?? false;
}

/// Wraps [child] with a drop region that catches files dragged onto the
/// page from the OS or browser. When the user releases, [onFiles] is
/// invoked with the dropped file(s). Shows a translucent highlight
/// overlay while the drag is over the region (WISH-0077).
///
/// Quietly does nothing on platforms super_drag_and_drop doesn't
/// support (currently mobile is a no-op, which matches the wish —
/// mobile users don't drag-and-drop into apps).
///
/// Only image and arbitrary-file formats are accepted by default;
/// callers can opt to restrict to images via [imagesOnly] when
/// dropping a PDF into a "Images" picker wouldn't make sense.
class FileDropTarget extends StatefulWidget {
  final Widget child;
  final Future<void> Function(List<DroppedFile> files) onFiles;
  final bool imagesOnly;

  const FileDropTarget({
    super.key,
    required this.child,
    required this.onFiles,
    this.imagesOnly = false,
  });

  @override
  State<FileDropTarget> createState() => _FileDropTargetState();
}

class _FileDropTargetState extends State<FileDropTarget> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return DropRegion(
      formats: const [
        Formats.png,
        Formats.jpeg,
        Formats.gif,
        Formats.webp,
        Formats.tiff,
        Formats.bmp,
        Formats.fileUri,
        Formats.plainTextFile,
      ],
      hitTestBehavior: HitTestBehavior.opaque,
      onDropOver: (event) {
        // Accept any drop that has at least one item we can read.
        if (event.session.items.isEmpty) return DropOperation.none;
        if (!_isHovering) {
          setState(() => _isHovering = true);
        }
        return DropOperation.copy;
      },
      onDropLeave: (event) {
        if (_isHovering) setState(() => _isHovering = false);
      },
      onPerformDrop: (event) async {
        if (_isHovering) setState(() => _isHovering = false);
        final dropped = await _collectFiles(event, widget.imagesOnly);
        if (dropped.isEmpty || !mounted) return;
        await widget.onFiles(dropped);
      },
      child: Stack(
        children: [
          widget.child,
          if (_isHovering)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.10),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.file_download_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            widget.imagesOnly ? 'Drop image' : 'Drop file',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Read bytes + filename + mime out of every item in a
/// super_drag_and_drop session, filtering out non-image items when
/// [imagesOnly] is true.
Future<List<DroppedFile>> _collectFiles(
  PerformDropEvent event,
  bool imagesOnly,
) async {
  final results = <DroppedFile>[];
  for (final item in event.session.items) {
    final reader = item.dataReader;
    if (reader == null) continue;

    // Image FileFormats first — these come through both on the web
    // (where the browser exposes dropped images as image/png etc.) and
    // on desktop when the user drags an image file.
    final fileFormats = <({FileFormat format, String ext})>[
      (format: Formats.png, ext: 'png'),
      (format: Formats.jpeg, ext: 'jpg'),
      (format: Formats.gif, ext: 'gif'),
      (format: Formats.webp, ext: 'webp'),
      (format: Formats.tiff, ext: 'tiff'),
      (format: Formats.bmp, ext: 'bmp'),
    ];

    DroppedFile? read;
    for (final entry in fileFormats) {
      if (!reader.canProvide(entry.format)) continue;
      try {
        read = await _readFile(reader, entry.format, entry.ext);
        if (read != null) break;
      } catch (e) {
        LogService.instance.warning('Drop read failed for ${entry.ext}: $e');
      }
    }
    if (read != null) {
      results.add(read);
    } else {
      // Non-image file (PDF, doc, …) — super_clipboard's typed file
      // formats only cover images for now, so we intercept the drag
      // (blocks the browser opening it in a new tab) but can't read
      // arbitrary binaries yet. Logged so callers know.
      LogService.instance.warning(
        'Dropped item has no recognised image format; non-image drop '
        'support is TODO (WISH-0077)',
      );
    }
  }
  return results;
}

Future<DroppedFile?> _readFile(
  DataReader reader,
  FileFormat format,
  String defaultExt,
) async {
  final completer = Completer<DroppedFile?>();
  reader.getFile(format, (file) async {
    try {
      final chunks = <List<int>>[];
      await for (final chunk in file.getStream()) {
        chunks.add(chunk);
      }
      final total = chunks.fold<int>(0, (n, c) => n + c.length);
      final bytes = Uint8List(total);
      var offset = 0;
      for (final c in chunks) {
        bytes.setRange(offset, offset + c.length, c);
        offset += c.length;
      }
      final fileName =
          file.fileName ??
          'dropped_${DateTime.now().millisecondsSinceEpoch}'
              '${defaultExt.isEmpty ? '' : '.$defaultExt'}';
      completer.complete(
        DroppedFile(
          bytes: bytes,
          fileName: fileName,
          mimeType: _mimeFromFormat(format) ?? _mimeFromName(fileName),
        ),
      );
    } catch (e) {
      completer.completeError(e);
    }
  }, onError: completer.completeError);
  return completer.future;
}

String? _mimeFromFormat(FileFormat format) {
  if (format == Formats.png) return 'image/png';
  if (format == Formats.jpeg) return 'image/jpeg';
  if (format == Formats.gif) return 'image/gif';
  if (format == Formats.webp) return 'image/webp';
  if (format == Formats.tiff) return 'image/tiff';
  if (format == Formats.bmp) return 'image/bmp';
  return null;
}

String? _mimeFromName(String name) {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  switch (ext) {
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'tiff':
      return 'image/tiff';
    case 'bmp':
      return 'image/bmp';
    case 'pdf':
      return 'application/pdf';
    default:
      return null;
  }
}

/// `true` on platforms where drag-and-drop from the OS / browser
/// actually fires events. Mobile is a no-op so we don't need to wrap
/// callers there (WISH-0077).
bool get isFileDropSupported {
  if (kIsWeb) return true;
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
}
