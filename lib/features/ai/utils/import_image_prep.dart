import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'import_file_check.dart';

enum ImagePrepFailure {
  /// Not an image the app can read or convert.
  unsupported,

  /// A HEIC photo the platform picker didn't convert, which the app can't decode.
  heic,

  /// Still over the per-image limit after downscaling.
  tooLarge,
}

/// The outcome of [prepareImportImage]: either upload-ready bytes and their
/// type, or why the image can't be used.
class PreparedImage {
  const PreparedImage.ok(Uint8List this.bytes, ImportFileType this.type) : failure = null;
  const PreparedImage.failed(ImagePrepFailure this.failure) : bytes = null, type = null;

  final Uint8List? bytes;
  final ImportFileType? type;
  final ImagePrepFailure? failure;
}

/// Makes a picked image ready to upload, off the UI thread where the
/// platform allows (`compute` runs inline on the web).
///
/// On iOS, Android and the web the picker has usually done the work already:
/// it downscales and re-encodes to JPEG, converting HEIC on the way. This is
/// the fallback for everything it doesn't cover, such as desktop pickers that
/// ignore the size options, and large PNG screenshots.
Future<PreparedImage> prepareImportImage(Uint8List bytes, {required int maxBytes}) =>
    compute(_prepareInIsolate, (bytes, maxBytes));

PreparedImage _prepareInIsolate((Uint8List, int) args) => prepareImportImageSync(args.$1, maxBytes: args.$2);

/// The synchronous form of [prepareImportImage], for tests.
///
/// An image is kept as it is when it's an accepted type, within [maxBytes]
/// and [kImportImageMaxEdge], and upright. JPEG metadata is still removed,
/// because phone photos carry the location they were taken. Anything else is
/// decoded, turned upright, downscaled and re-encoded as JPEG.
PreparedImage prepareImportImageSync(Uint8List bytes, {required int maxBytes}) {
  final type = detectImportFileType(bytes);
  if (type == ImportFileType.pdf) return const PreparedImage.failed(ImagePrepFailure.unsupported);

  if (type != null) {
    final size = _dimensions(bytes, type);
    final orientation = type == ImportFileType.jpeg ? _jpegOrientation(bytes) : null;
    final upright = orientation == null || orientation == 1;
    if (size != null && math.max(size.$1, size.$2) <= kImportImageMaxEdge && bytes.length <= maxBytes && upright) {
      return PreparedImage.ok(type == ImportFileType.jpeg ? stripJpegMetadata(bytes) : bytes, type);
    }
  }

  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    decoded = null;
  }
  if (decoded == null) {
    return PreparedImage.failed(isHeic(bytes) ? ImagePrepFailure.heic : ImagePrepFailure.unsupported);
  }

  var image = img.bakeOrientation(decoded);
  final longEdge = math.max(image.width, image.height);
  if (longEdge > kImportImageMaxEdge) {
    image = image.width >= image.height
        ? img.copyResize(image, width: kImportImageMaxEdge, interpolation: img.Interpolation.average)
        : img.copyResize(image, height: kImportImageMaxEdge, interpolation: img.Interpolation.average);
  }
  if (image.hasAlpha) {
    // JPEG has no transparency: put a transparent screenshot on white rather
    // than the black it would otherwise get.
    final background = img.Image(width: image.width, height: image.height)..clear(img.ColorRgb8(255, 255, 255));
    image = img.compositeImage(background, image);
  }
  // Re-encoding writes whatever EXIF the image carries, location included.
  image.exif = img.ExifData();

  final out = img.encodeJpg(image, quality: kImportJpegQuality);
  if (out.length > maxBytes) return const PreparedImage.failed(ImagePrepFailure.tooLarge);
  return PreparedImage.ok(out, ImportFileType.jpeg);
}

/// Width and height from the header alone, without decoding pixels.
(int, int)? _dimensions(Uint8List bytes, ImportFileType type) {
  try {
    final img.Decoder decoder = switch (type) {
      ImportFileType.jpeg => img.JpegDecoder(),
      ImportFileType.png => img.PngDecoder(),
      ImportFileType.webp => img.WebPDecoder(),
      ImportFileType.pdf => throw StateError('not an image'),
    };
    final info = decoder.startDecode(bytes);
    if (info == null || info.width <= 0 || info.height <= 0) return null;
    return (info.width, info.height);
  } catch (_) {
    return null;
  }
}

int? _jpegOrientation(Uint8List bytes) {
  try {
    final exif = img.decodeJpgExif(bytes);
    if (exif == null || !exif.imageIfd.hasOrientation) return null;
    return exif.imageIfd.orientation;
  } catch (_) {
    return null;
  }
}

/// Removes a JPEG's metadata segments (EXIF and XMP in APP1, IPTC in APP13)
/// without touching the image data. Returns the input unchanged if its
/// structure isn't what's expected.
///
/// Only safe on an image that's already upright: EXIF is also where the
/// orientation lives.
@visibleForTesting
Uint8List stripJpegMetadata(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xff || bytes[1] != 0xd8) return bytes;
  final out = BytesBuilder(copy: false)..add(const [0xff, 0xd8]);
  var i = 2;
  while (i + 4 <= bytes.length) {
    if (bytes[i] != 0xff) return bytes;
    final marker = bytes[i + 1];
    // Start of scan: the compressed image follows, so copy the rest as is.
    if (marker == 0xda) {
      out.add(Uint8List.sublistView(bytes, i));
      return out.takeBytes();
    }
    // Fill bytes and markers that have no length field.
    if (marker == 0xff) {
      i += 1;
      continue;
    }
    if (marker == 0x01 || (marker >= 0xd0 && marker <= 0xd7)) {
      out.add(Uint8List.sublistView(bytes, i, i + 2));
      i += 2;
      continue;
    }
    final length = (bytes[i + 2] << 8) | bytes[i + 3];
    final end = i + 2 + length;
    if (length < 2 || end > bytes.length) return bytes;
    if (marker != 0xe1 && marker != 0xed) {
      out.add(Uint8List.sublistView(bytes, i, end));
    }
    i = end;
  }
  return bytes;
}
