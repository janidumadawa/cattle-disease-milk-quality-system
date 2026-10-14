/// Signs to look for for each disease the model knows.
class DiseaseGuide {
  const DiseaseGuide({required this.signs});

  /// Signs the farmer can check on the animal.
  final List<String> signs;
}

const _guides = {
  'LSD': DiseaseGuide(
    signs: [
      'Firm skin nodules',
      'Fever',
      'Swollen lymph nodes',
      'Reduced appetite',
      'Drop in milk yield',
      'Watery eyes and nose',
    ],
  ),
  'FMD': DiseaseGuide(
    signs: [
      'Blisters in the mouth',
      'Drooling',
      'Blisters on the feet',
      'Lameness',
      'Fever',
      'Drop in milk yield',
    ],
  ),
  'Mastitis': DiseaseGuide(
    signs: [
      'Swollen udder',
      'Hot or painful udder',
      'Clots or flakes in milk',
      'Watery or discoloured milk',
      'Reduced milk yield',
      'Fever',
    ],
  ),
  'Ringworm': DiseaseGuide(
    signs: [
      'Round, hairless patches',
      'Grey-white crusty skin',
      'Patches on the head and neck',
      'Mild itching',
    ],
  ),
};

/// The guide for a class id such as "LSD_High", or null for Healthy.
DiseaseGuide? guideFor(String classId) => _guides[classId.split('_').first];
