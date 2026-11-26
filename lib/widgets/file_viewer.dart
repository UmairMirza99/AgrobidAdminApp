import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/api.dart';
import 'common.dart';
import 'open_bytes_stub.dart' if (dart.library.js_interop) 'open_bytes_web.dart';

/// Fetches a protected file with the admin token and shows it: images inline, PDFs in a new tab.
Future<void> showProtectedFile(BuildContext context, ApiClient api, {required String path, required String title, required String contentType}) async {
  if (contentType == 'application/pdf') {
    await runAction(context, () async => openBytesInNewTab(await api.bytes(path), contentType));
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 760),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            title: Text(title),
            trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ),
          Flexible(
            child: FutureBuilder<Uint8List>(
              future: api.bytes(path),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Padding(padding: const EdgeInsets.all(32), child: Text(snapshot.error.toString()));
                if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator());
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(child: InteractiveViewer(maxScale: 5, child: Image.memory(snapshot.data!, fit: BoxFit.contain))),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => openBytesInNewTab(snapshot.data!, contentType),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open full size in a new tab'),
                    ),
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
    ),
  );
}

/// A circular profile photo loaded with the admin token; shows initials when there is none.
class ProtectedAvatar extends StatelessWidget {
  const ProtectedAvatar({super.key, required this.api, required this.path, required this.name, this.hasPhoto = true, this.radius = 36});

  final ApiClient api;
  final String path;
  final String name;
  final bool hasPhoto;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();
    final fallback = CircleAvatar(radius: radius, child: Text(initials, style: TextStyle(fontSize: radius * 0.6)));
    if (!hasPhoto) return fallback;
    return FutureBuilder<Uint8List>(
      future: api.bytes(path),
      builder: (context, snapshot) => snapshot.hasData ? CircleAvatar(radius: radius, backgroundImage: MemoryImage(snapshot.data!)) : fallback,
    );
  }
}
