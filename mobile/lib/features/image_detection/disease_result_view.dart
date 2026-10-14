import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'disease_result.dart';

/// Below this confidence the user is asked to try a better photo.
const lowConfidence = 0.6;

String _percent(double value) => '${(value * 100).toStringAsFixed(1)}%';

/// Shows the response of the disease identification API.
class DiseaseResultView extends StatelessWidget {
  const DiseaseResultView({super.key, required this.result, this.photo});

  final DiseaseResult result;

  /// The uploaded photo, shown next to the highlighted area.
  final Uint8List? photo;

  @override
  Widget build(BuildContext context) {
    if (!result.isCattle || result.predictions.isEmpty) {
      return const _NotCattleCard();
    }

    final theme = Theme.of(context);
    final top = result.predictions.first;
    final others = result.predictions.skip(1).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Most likely',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(top.disease, style: theme.textTheme.headlineSmall),
                if (top.severity != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Stage'),
                      const SizedBox(width: 8),
                      _StageChip(stage: top.severity!),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Text(top.info),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Confidence'),
                    const Spacer(),
                    Text(
                      _percent(top.confidence),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: top.confidence,
                    minHeight: 8,
                  ),
                ),
                if (top.confidence < lowConfidence) ...[
                  const SizedBox(height: 12),
                  Text(
                    'The model is not very sure about this photo. Try a '
                    'closer, well-lit picture of the affected area.',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (result.gradcamPng != null) ...[
          const SizedBox(height: 12),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'Affected area',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    'Red areas influenced the prediction most. This is not an '
                    'exact outline of a lesion.',
                  ),
                ),
                if (photo == null)
                  Image.memory(result.gradcamPng!, fit: BoxFit.contain)
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _LabelledImage(bytes: photo!, label: 'Photo'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _LabelledImage(
                            bytes: result.gradcamPng!,
                            label: 'Highlighted area',
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (others.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      'Other possibilities',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  for (final p in others)
                    ListTile(
                      title: Text(p.disease),
                      subtitle: p.severity == null
                          ? null
                          : Text('Stage: ${p.severity}'),
                      trailing: Text(_percent(p.confidence)),
                    ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'This is a pre-screening aid, not a diagnosis. Please consult a '
          'veterinarian.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Disease stage from the model: "High" or "Low".
class _StageChip extends StatelessWidget {
  const _StageChip({required this.stage});

  final String stage;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final high = stage.toLowerCase() == 'high';

    return Chip(
      label: Text(stage),
      backgroundColor: high ? colors.errorContainer : colors.tertiaryContainer,
      labelStyle: TextStyle(
        color: high ? colors.onErrorContainer : colors.onTertiaryContainer,
      ),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _LabelledImage extends StatelessWidget {
  const _LabelledImage({required this.bytes, required this.label});

  final Uint8List bytes;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(bytes, fit: BoxFit.contain),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _NotCattleCard extends StatelessWidget {
  const _NotCattleCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "This doesn't look like cattle",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'No cow, bull or calf was found in this photo, so no disease '
              'check was done. Please use a photo of the animal or a close-up '
              'of the affected area (skin, udder, hoof or mouth).',
            ),
          ],
        ),
      ),
    );
  }
}
