import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class MarkerUtils {
  static final Map<String, BitmapDescriptor> _markerCache = {};

  static String _getMarkerKey(String? url, String name, Color color, bool hasStar) {
    return '${url ?? ''}_${name}_${color.value}_$hasStar';
  }

  static String _getGroupMarkerKey(List<Map<String, dynamic>> users) {
    final ids = users.map((u) => u['id'].toString()).toList()..sort();
    return ids.join(',');
  }
  static Future<ui.Image?> _loadAvatarImage(String? url, int size) async {
    if (url == null || url.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return await decodeImageFromList(response.bodyBytes);
      }
    } catch (e) {
      debugPrint("Error loading avatar image: $e");
    }
    return null;
  }

  /// Creates a circular avatar marker from a URL.
  /// If URL is null or loading fails, falls back to an initial-based circle.
  static Future<BitmapDescriptor> getAvatarMarker({
    String? url,
    required String name,
    required Color color,
    int size = 120,
    bool hasStar = false,
  }) async {
    final String key = _getMarkerKey(url, name, color, hasStar);
    if (_markerCache.containsKey(key)) return _markerCache[key]!;

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
          final ui.Image image = await decodeImageFromList(response.bodyBytes);
          
          canvas.save();
          final Rect imageRect = Rect.fromCircle(center: Offset(radius, radius), radius: radius - 6);
          final Path path = Path()..addOval(imageRect);
          canvas.clipPath(path);
          paintImage(
            canvas: canvas,
            rect: imageRect,
            image: image,
            fit: BoxFit.cover,
          );
          canvas.restore();
          image.dispose(); // Dispose avatar image
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
    
    // Explicit disposal
    markerAsImage.dispose();
    
    final descriptor = BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
    _markerCache[key] = descriptor;
    return descriptor;
  }

  /// Creates a composite marker showing up to 3 overlapping avatars/badges for a cluster.
  static Future<BitmapDescriptor> getGroupAvatarMarker(
    List<Map<String, dynamic>> users, {
    int size = 120,
  }) async {
    final String key = _getGroupMarkerKey(users);
    if (_markerCache.containsKey(key)) return _markerCache[key]!;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    
    final double radius = size / 2.0;
    
    // We display max 3 circles: user[0], user[1], and a "+N" badge if more than 2 users.
    int displayCount = users.length > 2 ? 3 : users.length;
    // Calculate total width of the canvas (circles overlap by 40%)
    double totalWidth = size + (displayCount - 1) * (size * 0.6);
    
    // Draw from right to left so left (index 0) is on top
    for (int i = displayCount - 1; i >= 0; i--) {
      bool isBadge = (i == 2 && users.length > 2);
      Map<String, dynamic>? user = isBadge ? null : users[i];
      
      double centerX = radius + (i * (size * 0.6));
      double centerY = radius;
      Offset center = Offset(centerX, centerY);

      // 1. Draw Shadow
      final Paint shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(centerX, centerY + 2), radius, shadowPaint);

      // 2. Draw White Border
      final Paint borderPaint = Paint()..color = Colors.white;
      canvas.drawCircle(center, radius, borderPaint);

      // 3. Draw Inner Content
      if (isBadge) {
        final Paint badgePaint = Paint()..color = Colors.grey.shade300;
        canvas.drawCircle(center, radius - 6, badgePaint);
        
        final String badgeText = '+${users.length - 2}';
        final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
        textPainter.text = TextSpan(
          text: badgeText,
          style: TextStyle(
            fontSize: radius * 0.8,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(centerX - (textPainter.width / 2), centerY - (textPainter.height / 2)),
        );
      } else {
        final bool isMe = user!['is_me'] == true;
        final Color color = isMe ? Colors.blueAccent : Colors.deepPurple;
        
        final Paint innerPaint = Paint()..color = color;
        canvas.drawCircle(center, radius - 6, innerPaint);
        
        final String? avatarUrl = user['avatar'];
        final String name = user['name'] ?? 'Unknown';
        
        ui.Image? image = await _loadAvatarImage(avatarUrl, (size - 12).toInt());
        
        if (image != null) {
          canvas.save();
          final Rect imageRect = Rect.fromCircle(center: center, radius: radius - 6);
          final Path path = Path()..addOval(imageRect);
          canvas.clipPath(path);
          paintImage(
            canvas: canvas,
            rect: imageRect,
            image: image,
            fit: BoxFit.cover,
          );
          canvas.restore();
          image.dispose(); // Dispose avatar image
        } else {
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
            Offset(centerX - (textPainter.width / 2), centerY - (textPainter.height / 2)),
          );
        }
        
        // 4. Draw Star Badge if needed
        if (isMe) {
          final double starRadius = radius * 0.4;
          final Offset starPos = Offset(centerX + radius * 0.6, centerY - radius * 0.6);
          
          final Paint starBorderPaint = Paint()..color = Colors.white;
          canvas.drawCircle(starPos, starRadius, starBorderPaint);
          
          final Paint starPaint = Paint()..color = Colors.amber;
          canvas.drawCircle(starPos, starRadius - 2, starPaint);
          
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
      }
    }
    
    final ui.Image markerAsImage = await pictureRecorder.endRecording().toImage(totalWidth.toInt(), size + 10);
    final byteData = await markerAsImage.toByteData(format: ui.ImageByteFormat.png);
    
    // Explicit disposal
    markerAsImage.dispose();
    
    final descriptor = BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
    _markerCache[key] = descriptor;
    return descriptor;
  }
}
