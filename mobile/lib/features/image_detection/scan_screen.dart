import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'disease_api.dart';
import 'disease_result.dart';
import 'disease_result_view.dart';
import 'photo_guide.dart';

/// Image-based cattle disease detection.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _picker = ImagePicker();
  final _api = DiseaseApi();

  PhotoSubject _subject = PhotoSubject.wholeAnimal;
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
    // Predict straight away; no extra button press needed.
    await _identify();
  }

  /// Back to the photo guide.
  void _reset() {
    setState(() {
      _image = null;
      _imageBytes = null;
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

  List<Widget> _pickButtons() {
    final again = _imageBytes != null;
    return [
      FilledButton.icon(
        onPressed: _loading ? null : () => _pickImage(ImageSource.camera),
        icon: const Icon(Icons.photo_camera_outlined),
        label: Text(again ? 'Take another photo' : 'Open camera'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: _loading ? null : () => _pickImage(ImageSource.gallery),
        icon: const Icon(Icons.photo_library_outlined),
        label: const Text('Choose from gallery'),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      ),
    ];
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
            children: _imageBytes == null
                ? [
                    PhotoGuide(
                      subject: _subject,
                      onSubjectChanged: (s) => setState(() => _subject = s),
                    ),
                    const SizedBox(height: 20),
                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                      const SizedBox(height: 12),
                    ],
                    ..._pickButtons(),
                  ]
                : [
                    _ImagePreview(bytes: _imageBytes),
                    const SizedBox(height: 12),
                    if (_loading) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      const Text(
                        'Analysing photo...',
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _identify,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try again'),
                      ),
                    ],
                    if (_result != null)
                      DiseaseResultView(result: _result!, photo: _imageBytes),
                    if (!_loading) ...[
                      const SizedBox(height: 16),
                      ..._pickButtons(),
                      TextButton(
                        onPressed: _reset,
                        child: const Text('Back to photo tips'),
                      ),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 260,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: bytes == null ? null : Image.memory(bytes!, fit: BoxFit.cover),
      ),
    );
  }
}
