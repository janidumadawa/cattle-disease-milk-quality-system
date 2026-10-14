import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'disease_api.dart';
import 'disease_result.dart';
import 'disease_result_view.dart';

/// Image-based cattle disease detection.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _picker = ImagePicker();
  final _api = DiseaseApi();

  XFile? _image;
  Uint8List? _imageBytes;
  DiseaseResult? _result;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600, // keeps uploads small; the model only needs 224 px
        imageQuality: 90,
      );
    } on PlatformException catch (e) {
      setState(
        () => _error = 'Could not open the ${source.name}: ${e.message}',
      );
      return;
    }
    if (picked == null) {
      return; // the user cancelled
    }

    final bytes = await picked.readAsBytes();
    if (!mounted) {
      return;
    }
    setState(() {
      _image = picked;
      _imageBytes = bytes;
      _result = null;
      _error = null;
    });
  }

  Future<void> _identify() async {
    final image = _image;
    if (image == null) {
      return;
    }

    setState(() {
      _loading = true;
      _result = null;
      _error = null;
    });

    try {
      final result = await _api.predict(image);
      if (mounted) {
        setState(() => _result = result);
      }
    } on DiseaseApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Image-based Detection')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ImagePreview(bytes: _imageBytes),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loading
                          ? null
                          : () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Camera'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loading
                          ? null
                          : () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Gallery'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _image == null || _loading ? null : _identify,
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(_loading ? 'Identifying...' : 'Identify disease'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              if (_result != null) ...[
                const SizedBox(height: 16),
                DiseaseResultView(result: _result!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.bytes});

  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 260,
        color: theme.colorScheme.surfaceContainerHighest,
        child: bytes != null
            ? Image.memory(bytes!, fit: BoxFit.cover)
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Take or choose a clear photo of the animal or the '
                      'affected area (skin, udder, hoof or mouth).',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
