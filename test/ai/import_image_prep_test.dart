import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nomorex/features/ai/utils/import_file_check.dart';
import 'package:nomorex/features/ai/utils/import_image_prep.dart';

const _plenty = 7000000;

img.Image _image(int width, int height, {int channels = 3}) {
  final image = img.Image(width: width, height: height, numChannels: channels);
  // A gradient, so the encoder has something to compress.
  for (final p in image) {
    p
      ..r = p.x % 256
      ..g = p.y % 256
      ..b = 128;
    if (channels == 4) p.a = p.x < width ~/ 2 ? 0 : 255;
  }
  return image;
}

Uint8List _jpegWithExif(img.Image image, {int? orientation, bool gps = false}) {
  final exif = img.ExifData();
  if (orientation != null) exif.imageIfd.orientation = orientation;
  if (gps) exif.gpsIfd['GPSLatitude'] = img.IfdValueRational(40, 1);
  image.exif = exif;
  return img.encodeJpg(image, quality: 90);
}

/// Whether the JPEG still has an EXIF (APP1) segment before its image data.
bool _hasExifSegment(Uint8List jpeg) {
  var i = 2;
  while (i + 4 <= jpeg.length && jpeg[i] == 0xff) {
    final marker = jpeg[i + 1];
    if (marker == 0xda) return false;
    if (marker == 0xe1) return true;
    i += 2 + ((jpeg[i + 2] << 8) | jpeg[i + 3]);
  }
  return false;
}

void main() {
  test('keeps a small upright image, only removing JPEG metadata', () {
    final source = _jpegWithExif(_image(800, 600), gps: true);
    expect(_hasExifSegment(source), isTrue, reason: 'fixture should carry EXIF');

    final result = prepareImportImageSync(source, maxBytes: _plenty);

    expect(result.type, ImportFileType.jpeg);
    expect(_hasExifSegment(result.bytes!), isFalse);
    // Same pixels: only the metadata segment went.
    final decoded = img.decodeJpg(result.bytes!)!;
    expect((decoded.width, decoded.height), (800, 600));
  });

  test('passes a small PNG through untouched', () {
    final png = img.encodePng(_image(300, 200));
    final result = prepareImportImageSync(png, maxBytes: _plenty);
    expect(result.type, ImportFileType.png);
    expect(result.bytes, same(png));
  });

  test('downscales a large image to the long-edge limit as JPEG', () {
    final png = img.encodePng(_image(4000, 3000));
    final result = prepareImportImageSync(png, maxBytes: _plenty);

    expect(result.type, ImportFileType.jpeg);
    final decoded = img.decodeJpg(result.bytes!)!;
    expect(decoded.width, kImportImageMaxEdge);
    expect(decoded.height, 1932); // 3000 * 2576 / 4000
  });

  test('downscales a tall image by its height', () {
    final png = img.encodePng(_image(1000, 3000));
    final decoded = img.decodeJpg(prepareImportImageSync(png, maxBytes: _plenty).bytes!)!;
    expect(decoded.height, kImportImageMaxEdge);
  });

  test('turns a rotated photo upright and drops its EXIF', () {
    // Orientation 6: stored landscape, displayed rotated 90° clockwise.
    final source = _jpegWithExif(_image(400, 200), orientation: 6, gps: true);
    final result = prepareImportImageSync(source, maxBytes: _plenty);

    final decoded = img.decodeJpg(result.bytes!)!;
    expect((decoded.width, decoded.height), (200, 400));
    expect(_hasExifSegment(result.bytes!), isFalse);
  });

  test('re-encodes an image over the byte limit even when its size is fine', () {
    // Noise: large as a PNG, much smaller as a JPEG.
    final random = Random(1);
    final noise = img.Image(width: 1200, height: 1200);
    for (final p in noise) {
      p
        ..r = random.nextInt(256)
        ..g = random.nextInt(256)
        ..b = random.nextInt(256);
    }
    final png = img.encodePng(noise);
    final result = prepareImportImageSync(png, maxBytes: png.length - 1);
    expect(result.type, ImportFileType.jpeg);
    expect(result.bytes!.length, lessThan(png.length));
  });

  test('puts a transparent image on white rather than black', () {
    final png = img.encodePng(_image(3000, 100, channels: 4));
    final decoded = img.decodeJpg(prepareImportImageSync(png, maxBytes: _plenty).bytes!)!;
    final pixel = decoded.getPixel(10, 10); // in the transparent half
    expect(pixel.r, greaterThan(240));
    expect(pixel.g, greaterThan(240));
  });

  test('converts a decodable image of another type, such as GIF', () {
    final gif = img.encodeGif(_image(100, 100));
    final result = prepareImportImageSync(gif, maxBytes: _plenty);
    expect(result.type, ImportFileType.jpeg);
  });

  test('fails when the image is still too large after shrinking', () {
    final png = img.encodePng(_image(3000, 3000));
    expect(prepareImportImageSync(png, maxBytes: 1000).failure, ImagePrepFailure.tooLarge);
  });

  test('names HEIC photos it can\'t convert', () {
    final heic = Uint8List.fromList([0, 0, 0, 24, ...ascii.encode('ftypheic'), ...List.filled(64, 0)]);
    expect(prepareImportImageSync(heic, maxBytes: _plenty).failure, ImagePrepFailure.heic);
  });

  test('refuses things that aren\'t images, including PDFs', () {
    expect(
      prepareImportImageSync(Uint8List.fromList(ascii.encode('hello')), maxBytes: _plenty).failure,
      ImagePrepFailure.unsupported,
    );
    expect(
      prepareImportImageSync(Uint8List.fromList(ascii.encode('%PDF-1.7 ...')), maxBytes: _plenty).failure,
      ImagePrepFailure.unsupported,
    );
  });

  group('stripJpegMetadata', () {
    test('returns malformed input unchanged', () {
      final junk = Uint8List.fromList([0xff, 0xd8, 0x00, 0x01, 0x02]);
      expect(stripJpegMetadata(junk), same(junk));
    });

    test('keeps every non-metadata segment', () {
      final source = _jpegWithExif(_image(64, 64), gps: true);
      final stripped = stripJpegMetadata(source);
      expect(stripped.length, lessThan(source.length));
      expect(img.decodeJpg(stripped), isNotNull);
    });
  });
}
