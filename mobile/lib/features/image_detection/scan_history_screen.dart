import 'package:flutter/material.dart';

import 'disease_api.dart';
import 'scan_detail_screen.dart';
import 'scan_history.dart';

/// Past cattle scans, newest first.
class ScanHistoryScreen extends StatefulWidget {
  const ScanHistoryScreen({super.key, required this.api});

  final DiseaseApi api;

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  static const _pageSize = 20;

  final List<ScanSummary> _scans = [];
  int _total = 0;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// Reloads from the first page.
  Future<void> _refresh() => _loadPage(reset: true);

  Future<void> _loadPage({bool reset = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.api.history(
        limit: _pageSize,
        offset: reset ? 0 : _scans.length,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        if (reset) {
          _scans.clear();
        }
        _scans.addAll(page.items);
        _total = page.total;
      });
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

  Future<void> _open(ScanSummary scan) async {
    final deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ScanDetailScreen(api: widget.api, scanId: scan.id),
      ),
    );
    if (deleted == true && mounted) {
      _removeFromList(scan);
    }
  }

  /// Asks, then deletes the scan on the server. Returns true when it is gone.
  Future<bool> _delete(ScanSummary scan) async {
    if (!await confirmDeleteScan(context)) {
      return false;
    }
    try {
      await widget.api.deleteScan(scan.id);
      return true;
    } on DiseaseApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      return false;
    }
  }

  void _removeFromList(ScanSummary scan) {
    setState(() {
      _scans.remove(scan);
      _total--;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Scan history')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              // Lets pull-to-refresh work when the list is short or empty.
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : () => _loadPage(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_scans.isEmpty && !_loading && _error == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Text(
                      'No scans yet. Results of your cattle photos will '
                      'appear here.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                for (final scan in _scans)
                  // Swipe left to delete; the row only goes once the server
                  // has deleted the scan.
                  Dismissible(
                    key: ValueKey(scan.id),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) => _delete(scan),
                    onDismissed: (_) => _removeFromList(scan),
                    background: const _DeleteBackground(),
                    child: _ScanTile(
                      scan: scan,
                      onTap: () => _open(scan),
                      onDelete: () async {
                        if (await _delete(scan) && mounted) {
                          _removeFromList(scan);
                        }
                      },
                    ),
                  ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_scans.length < _total && _error == null)
                  TextButton(
                    onPressed: () => _loadPage(),
                    child: const Text('Show older scans'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.errorContainer,
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Icon(Icons.delete_outline, color: colors.onErrorContainer),
        ),
      ),
    );
  }
}

class _ScanTile extends StatelessWidget {
  const _ScanTile({
    required this.scan,
    required this.onTap,
    required this.onDelete,
  });

  final ScanSummary scan;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = scan.topPrediction;
    final stage = top.severity == null ? '' : ' · ${top.severity} stage';
    final confidence = '${(top.confidence * 100).toStringAsFixed(0)}%';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox.square(
            dimension: 56,
            child: Image.network(
              DiseaseApi.url(scan.photoPath).toString(),
              fit: BoxFit.cover,
              cacheWidth: 168,
              errorBuilder: (_, _, _) => ColoredBox(
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.image_not_supported_outlined),
              ),
            ),
          ),
        ),
        title: Text('${top.disease}$stage'),
        subtitle: Text(formatScanTime(context, scan.createdAt)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(confidence, style: theme.textTheme.titleSmall),
            IconButton(
              tooltip: 'Delete scan',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}
