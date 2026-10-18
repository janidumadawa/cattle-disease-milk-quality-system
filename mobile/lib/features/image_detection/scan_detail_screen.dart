import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'disease_api.dart';
import 'disease_result.dart';
import 'disease_result_view.dart';
import 'scan_history.dart';

/// Formats a scan time like "Oct 18, 2026 · 9:41 AM".
String formatScanTime(BuildContext context, DateTime time) {
  final l = MaterialLocalizations.of(context);
  return '${l.formatMediumDate(time)} · '
      '${l.formatTimeOfDay(TimeOfDay.fromDateTime(time))}';
}

/// One saved scan, shown the same way as a fresh result.
///
/// Pops with `true` when the scan was deleted.
class ScanDetailScreen extends StatefulWidget {
  const ScanDetailScreen({super.key, required this.api, required this.scanId});

  final DiseaseApi api;
  final int scanId;

  @override
  State<ScanDetailScreen> createState() => _ScanDetailScreenState();
}

class _ScanDetailScreenState extends State<ScanDetailScreen> {
  late Future<_LoadedScan> _scan = _load();
  bool _deleting = false;

  Future<_LoadedScan> _load() async {
    final detail = await widget.api.scan(widget.scanId);
    final gradcamPath = detail.gradcamPath;
    final images = await Future.wait([
      widget.api.image(detail.photoPath),
      if (gradcamPath != null) widget.api.image(gradcamPath),
    ]);
    return _LoadedScan(
      detail: detail,
      photo: images.first,
      result: DiseaseResult(
        isCattle: true, // only cattle scans are saved
        cattleScore: detail.cattleScore,
        predictions: detail.predictions,
        gradcamPng: images.length > 1 ? images[1] : null,
      ),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this scan?'),
        content: const Text('The photo and its result will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _deleting = true);
    try {
      await widget.api.deleteScan(widget.scanId);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on DiseaseApiException catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan result'),
        actions: [
          IconButton(
            tooltip: 'Delete scan',
            onPressed: _deleting ? null : _delete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: FutureBuilder(
            future: _scan,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _LoadError(
                  message: snapshot.error.toString(),
                  onRetry: () => setState(() => _scan = _load()),
                );
              }
              final scan = snapshot.data!;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Scanned ${formatScanTime(context, scan.detail.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  DiseaseResultView(result: scan.result, photo: scan.photo),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LoadedScan {
  const _LoadedScan({
    required this.detail,
    required this.photo,
    required this.result,
  });

  final ScanDetail detail;
  final Uint8List photo;
  final DiseaseResult result;
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
