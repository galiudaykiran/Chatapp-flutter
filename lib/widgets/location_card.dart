import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationCard extends StatelessWidget {
  final double latitude;
  final double longitude;

  const LocationCard({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  Future<void> _openMaps() async {
    final Uri url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _openMaps,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 110,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.lightGreen[50],
              border: Border.all(color: const Color(0xFF075E54).withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, color: Colors.red, size: 36),
                const SizedBox(height: 4),
                const Text(
                  'Shared GPS Location',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF075E54)),
                ),
                Text(
                  '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map, size: 16, color: Color(0xFF075E54)),
              SizedBox(width: 4),
              Text(
                'Tap to Open in Google Maps',
                style: TextStyle(
                  color: Color(0xFF075E54),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
