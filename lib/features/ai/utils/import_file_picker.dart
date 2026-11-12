import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'import_file_check.dart';

/// The platform pickers an import uses, behind one class so widget tests can
/// replace it (`importFilePickerProvider.overrideWithValue`).
///
/// Images go through `image_picker`, which downscales and re-encodes to JPEG
/// natively on iOS, Android and the web, converting iPhone HEIC photos on the
/// way. Desktop pickers ignore those options; `prepareImportImage` covers them.
class ImportFilePicker {
  ImportFilePicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  static const _pdfTypes = XTypeGroup(
    label: 'PDF',
    extensions: ['pdf'],
    mimeTypes: ['application/pdf'],
    uniformTypeIdentifiers: ['com.adobe.pdf'],
  );

  /// Whether to offer "Take photo". Phones and tablets only: a desktop browser
  /// would just open a file dialog, and desktop apps have no camera UI.
  bool get canTakePhoto {
    final mobile = defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android;
    if (!mobile) return false;
    // On the web, defaultTargetPlatform is the browser's OS, and a mobile
    // browser opens the camera for a capture input.
    return kIsWeb || _picker.supportsImageSource(ImageSource.camera);
  }

  Future<XFile?> takePhoto() => _picker.pickImage(
    source: ImageSource.camera,
    maxWidth: kImportImageMaxEdge.toDouble(),
    maxHeight: kImportImageMaxEdge.toDouble(),
    imageQuality: kImportJpegQuality,
    requestFullMetadata: false,
  );

  /// Up to [limit] images. The limit is enforced by the picker only on iOS
  /// and Android, so callers still check the count.
  Future<List<XFile>> pickImages({required int limit}) async {
    if (limit <= 0) return const [];
    if (limit == 1) {
      // pickMultiImage rejects a limit below 2.
      final one = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: kImportImageMaxEdge.toDouble(),
        maxHeight: kImportImageMaxEdge.toDouble(),
        imageQuality: kImportJpegQuality,
        requestFullMetadata: false,
      );
      return one == null ? const [] : [one];
    }
    return _picker.pickMultiImage(
      maxWidth: kImportImageMaxEdge.toDouble(),
      maxHeight: kImportImageMaxEdge.toDouble(),
      imageQuality: kImportJpegQuality,
      limit: limit,
      requestFullMetadata: false,
    );
  }

  /// Any number of PDFs; the caller checks the count.
  Future<List<XFile>> pickPdfs() => openFiles(acceptedTypeGroups: const [_pdfTypes]);
}
