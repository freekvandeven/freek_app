import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:personal_app/presentation/widgets/image_attachment_picker.dart';
import 'package:personal_app/presentation/widgets/image_upload_preview_dialog.dart';
import 'package:personal_app/services/image_upload_service.dart';

class _FakeMultiPickerService implements ImageUploadService {
  final List<XFile> files;
  _FakeMultiPickerService(this.files);

  @override
  Future<List<XFile>> pickMultiImage() async => files;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// A real (if tiny) 1x1 transparent PNG — the preview dialog renders it via
// Image.memory, which throws on garbage bytes even in a widget test.
final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY'
  '42YAAAAASUVORK5CYII=',
);

// XFile.name on the io implementation is derived from the path, not the
// `name:` constructor argument (which is web-only) — pass both so fake
// files behave the same across platforms.
XFile _file(String name) => XFile.fromData(_pngBytes, name: name, path: name);

/// Holds the eventual result of [pickAndConfirmMultipleFromGallery] so the
/// test can keep interacting with dialogs (via [tester]) while the picker's
/// own future is still pending, without two pieces of code racing to drive
/// the same [WidgetTester] concurrently.
class _Result {
  int? value;
}

/// Pumps a page with a button that starts
/// [pickAndConfirmMultipleFromGallery], taps it, and pumps once so the
/// first dialog (if any) is on screen. The caller drives the rest of the
/// interaction and reads [_Result.value] once the flow completes.
Future<_Result> _open(
  WidgetTester tester,
  ImageUploadService service,
  Future<void> Function(ImageUploadResult) onImageReady,
) async {
  final result = _Result();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              result.value = await pickAndConfirmMultipleFromGallery(
                context,
                service,
                onImageReady,
              );
            },
            child: const Text('Pick'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Pick'));
  await tester.pump();
  return result;
}

void main() {
  group('pickAndConfirmMultipleFromGallery (WISH-0096)', () {
    testWidgets('no-ops when the gallery pick returns nothing', (tester) async {
      final received = <ImageUploadResult>[];
      final result = await _open(
        tester,
        _FakeMultiPickerService([]),
        (r) async => received.add(r),
      );
      await tester.pumpAndSettle();

      expect(result.value, 0);
      expect(received, isEmpty);
      expect(find.text('Upload Image'), findsNothing);
    });

    testWidgets(
      'shows a step-labelled dialog per picked image and confirms in order',
      (tester) async {
        final received = <String>[];
        final result = await _open(
          tester,
          _FakeMultiPickerService([_file('a.jpg'), _file('b.jpg')]),
          (r) async => received.add(r.fileName),
        );

        expect(find.text('Upload Image (1 of 2)'), findsOneWidget);
        await tester.tap(find.text('Upload'));
        await tester.pumpAndSettle();

        expect(find.text('Upload Image (2 of 2)'), findsOneWidget);
        await tester.tap(find.text('Upload'));
        await tester.pumpAndSettle();

        expect(result.value, 2);
        expect(received, ['a.jpg', 'b.jpg']);
        expect(find.text('Added 2 images'), findsOneWidget);
      },
    );

    testWidgets('cancelling one image skips it but keeps going', (
      tester,
    ) async {
      final received = <String>[];
      final result = await _open(
        tester,
        _FakeMultiPickerService([_file('a.jpg'), _file('b.jpg')]),
        (r) async => received.add(r.fileName),
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Upload Image (2 of 2)'), findsOneWidget);
      await tester.tap(find.text('Upload'));
      await tester.pumpAndSettle();

      expect(result.value, 1);
      expect(received, ['b.jpg']);
      expect(find.text('Added 1 of 2 images'), findsOneWidget);
    });

    testWidgets('single-image picks show no step label or snackbar', (
      tester,
    ) async {
      final received = <String>[];
      final result = await _open(
        tester,
        _FakeMultiPickerService([_file('a.jpg')]),
        (r) async => received.add(r.fileName),
      );

      expect(find.text('Upload Image'), findsOneWidget);
      await tester.tap(find.text('Upload'));
      await tester.pumpAndSettle();

      expect(result.value, 1);
      expect(received, ['a.jpg']);
      expect(find.textContaining('Added'), findsNothing);
    });
  });
}
