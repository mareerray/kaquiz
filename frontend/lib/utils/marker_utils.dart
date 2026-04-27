import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class MarkerUtils {
  /// Creates a circular avatar marker from a URL.
  /// If URL is null or loading fails, falls back to an initial-based circle.
  static Future<BitmapDescriptor> getAvatarMarker({
    String? url,
    required String name,
    required Color color,
    int size = 120,
    bool hasStar = false,
  }) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final double radius = size / 2.0;

    // 1. Draw Shadow
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset(radius, radius + 2), radius, shadowPaint);

    // 2. Draw White Border
    final Paint borderPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(radius, radius), radius, borderPaint);

    // 3. Draw Color Inner Circle (Background)
    final Paint innerPaint = Paint()..color = color;
    canvas.drawCircle(Offset(radius, radius), radius - 6, innerPaint);

    bool imageLoaded = false;
    if (url != null && url.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final ui.Codec codec = await ui.instantiateImageCodec(
            response.bodyBytes, 
            targetWidth: (size - 12).toInt(), 
            targetHeight: (size - 12).toInt()
          );
          final ui.FrameInfo fi = await codec.getNextFrame();
          
          final ui.Image image = fi.image;
          
          canvas.save();
          final Path path = Path()..addOval(Rect.fromCircle(center: Offset(radius, radius), radius: radius - 6));
          canvas.clipPath(path);
          canvas.drawImage(image, Offset(radius - (image.width / 2), radius - (image.height / 2)), Paint());
          canvas.restore();
          imageLoaded = true;
        }
      } catch (e) {
        debugPrint("Error loading avatar for $name: $e");
      }
    }

    if (!imageLoaded) {
      final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
      textPainter.text = TextSpan(
        text: name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: radius,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(radius - (textPainter.width / 2), radius - (textPainter.height / 2)),
      );
    }

    // 4. Draw Star Badge if needed
    if (hasStar) {
      final double starRadius = radius * 0.4;
      final Offset starPos = Offset(radius * 1.6, radius * 0.4);
      
      // Star Background (Border)
      final Paint starBorderPaint = Paint()..color = Colors.white;
      canvas.drawCircle(starPos, starRadius, starBorderPaint);
      
      // Star Inner (Gold)
      final Paint starPaint = Paint()..color = Colors.amber;
      canvas.drawCircle(starPos, starRadius - 2, starPaint);
      
      // Star Icon
      TextPainter starIconPainter = TextPainter(textDirection: TextDirection.ltr);
      starIconPainter.text = TextSpan(
        text: '★',
        style: TextStyle(
          fontSize: starRadius * 1.4,
          color: Colors.white,
        ),
      );
      starIconPainter.layout();
      starIconPainter.paint(
        canvas,
        Offset(starPos.dx - (starIconPainter.width / 2), starPos.dy - (starIconPainter.height / 2)),
      );
    }

    final ui.Image markerAsImage = await pictureRecorder.endRecording().toImage(size, size + 10);
    final byteData = await markerAsImage.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }
}
