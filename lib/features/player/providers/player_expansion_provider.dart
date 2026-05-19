import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Contrôle l'état expanded/collapsed du lecteur unifié.
/// true = plein écran, false = mini barre.
final playerExpandedProvider = StateProvider<bool>((ref) => false);
