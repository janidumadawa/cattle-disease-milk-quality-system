import 'package:flutter/material.dart';

/// What the user is about to photograph. Changes the tips shown.
enum PhotoSubject { wholeAnimal, closeUp }

/// "Take a good photo" guide shown before the user picks a photo.
class PhotoGuide extends StatelessWidget {
  const PhotoGuide({
    super.key,
    required this.subject,
    required this.onSubjectChanged,
  });

  final PhotoSubject subject;
  final ValueChanged<PhotoSubject> onSubjectChanged;

  static const _tips = {
    PhotoSubject.wholeAnimal: [
      'Use good daylight, avoid harsh shadows',
      'Photograph the whole animal from the side',
      'Hold the camera steady',
      'Get as close as the animal allows without blur',
    ],
    PhotoSubject.closeUp: [
      'Use good daylight, avoid harsh shadows',
      'Fill the frame with the affected part',
      'Hold the camera steady and tap to focus',
      'Keep the affected area sharp and in the centre',
    ],
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tips = _tips[subject]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Take a good photo',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Example: Lumpy Skin Disease (LSD) nodules',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.4,
          children: [
            const _ExampleTile(
              image: 'good_light.jpg',
              label: 'Good light',
              good: true,
            ),
            subject == PhotoSubject.wholeAnimal
                ? const _ExampleTile(
                    image: 'whole_animal.jpg',
                    label: 'Whole animal',
                    good: true,
                  )
                : const _ExampleTile(
                    image: 'close_up.jpg',
                    label: 'Close and sharp',
                    good: true,
                  ),
            const _ExampleTile(
              image: 'too_dark.jpg',
              label: 'Too dark',
              good: false,
            ),
            const _ExampleTile(
              image: 'too_far.jpg',
              label: 'Too far',
              good: false,
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Required by the CC BY-SA licence; see assets/photo_guide/CREDITS.md.
        Text(
          'Photos: Pavanaja, Monica Commandeur, CC BY-SA 4.0, Wikimedia Commons',
          textAlign: TextAlign.right,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < tips.length; i++)
          _TipRow(number: i + 1, text: tips[i]),
        const SizedBox(height: 12),
        Text('What are you photographing?', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SubjectCard(
                icon: Icons.pets,
                title: 'Whole animal',
                selected: subject == PhotoSubject.wholeAnimal,
                onTap: () => onSubjectChanged(PhotoSubject.wholeAnimal),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SubjectCard(
                icon: Icons.photo_camera_outlined,
                title: 'Close-up',
                subtitle: 'Skin, mouth, udder, hoof',
                selected: subject == PhotoSubject.closeUp,
                onTap: () => onSubjectChanged(PhotoSubject.closeUp),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ExampleTile extends StatelessWidget {
  const _ExampleTile({
    required this.image,
    required this.label,
    required this.good,
  });

  /// File name in assets/photo_guide/.
  final String image;
  final String label;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: ColoredBox(
        color: colors.surfaceContainerHighest,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/photo_guide/$image',
              fit: BoxFit.cover,
              semanticLabel: label,
            ),
            Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                radius: 11,
                backgroundColor: good ? colors.primary : colors.error,
                child: Icon(
                  good ? Icons.check : Icons.close,
                  size: 14,
                  color: good ? colors.onPrimary : colors.onError,
                ),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: colors.primaryContainer,
            child: Text(
              '$number',
              style: TextStyle(
                color: colors.onPrimaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? colors.primaryContainer : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(
            height: 92,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: colors.primary),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
