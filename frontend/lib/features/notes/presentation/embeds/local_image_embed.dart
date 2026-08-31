import 'dart:io' if (dart.library.js) 'package:anynote/core/stubs/io_stub.dart';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../../../core/storage/image_storage.dart';
import '../../../../l10n/app_localizations.dart';

/// Embed builder for local images stored by [ImageStorage].
///
/// Renders inline images from local file paths (native) or
/// SharedPreferences keys (web) within Quill documents.
class LocalImageEmbedBuilder extends quill.EmbedBuilder {
  const LocalImageEmbedBuilder();

  @override
  String get key => 'image';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final node = embedContext.node;
    final data = node.value.data;
    if (data == null) return const _BrokenImage();

    final path = data is String ? data : data.toString();
    if (path.isEmpty) return const _BrokenImage();

    if (kIsWeb) {
      return _WebImage(path: path);
    }
    return _LocalImage(path: path);
  }
}

class _LocalImage extends StatelessWidget {
  final String path;
  const _LocalImage({required this.path});

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: double.infinity),
      child: Image.file(
        file,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const _BrokenImage(),
      ),
    );
  }
}

class _WebImage extends StatefulWidget {
  final String path;
  const _WebImage({required this.path});

  @override
  State<_WebImage> createState() => _WebImageState();
}

class _WebImageState extends State<_WebImage> {
  late Future<Uint8List?> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = ImageStorage.loadImage(widget.path);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final bytes = snapshot.data;
        if (bytes == null) return const _BrokenImage();
        return Image.memory(bytes, fit: BoxFit.contain);
      },
    );
  }
}

class _BrokenImage extends StatelessWidget {
  const _BrokenImage();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: 40,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context)?.imageNotFound ?? 'Image not found',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pattern matching markdown image syntax with file:// protocol.
final _markdownImagePattern = RegExp(r'!\[.*?\]\((file://[^)]+)\)');

/// Converts markdown image text (`![alt](file://path)`) in the document
/// to proper Quill image embeds. This is a one-time migration for notes
/// created before the embed-based image insertion was implemented.
void convertMarkdownImagesToEmbeds(quill.QuillController controller) {
  final doc = controller.document;
  var plainText = doc.toPlainText();

  if (!_markdownImagePattern.hasMatch(plainText)) return;

  // Collect all matches before mutating.
  final matches = _markdownImagePattern.allMatches(plainText).toList();

  // Process from end to start to keep offsets stable.
  for (final match in matches.reversed) {
    final filePath = match.group(1)!;
    final localPath = filePath.replaceFirst('file://', '');
    final len = match.end - match.start;

    doc.replace(match.start, len, quill.BlockEmbed.image(localPath));
  }
}
