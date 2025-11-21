/// Secrets helper.
/// 
/// Create a `.env` file in the project root with:
///   REPLICATE_API_TOKEN=your_replicate_api_token_here
/// 
/// After that you can simply run `flutter run` without passing --dart-define.
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Secrets {
  const Secrets._();

  static String get replicateToken =>
      dotenv.env['REPLICATE_API_TOKEN'] ?? '';

  static bool get hasReplicateToken => replicateToken.isNotEmpty;
}



