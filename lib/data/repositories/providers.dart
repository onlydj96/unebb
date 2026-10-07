import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unebb/data/repositories/supabase_error_pattern_repository.dart';
import 'package:unebb/data/repositories/supabase_memory_state_repository.dart';
import 'package:unebb/data/repositories/supabase_review_repository.dart';
import 'package:unebb/data/repositories/supabase_vocabulary_repository.dart';
import 'package:unebb/data/services/ai_evaluation_service.dart';
import 'package:unebb/data/services/ai_explanation_service.dart';
import 'package:unebb/data/services/ai_question_service.dart';
import 'package:unebb/domain/repositories/error_pattern_repository.dart';
import 'package:unebb/domain/repositories/memory_state_repository.dart';
import 'package:unebb/domain/repositories/review_repository.dart';
import 'package:unebb/domain/repositories/vocabulary_repository.dart';
import 'package:unebb/domain/services/memory_service.dart';

final supabaseClientProvider = Provider<SupabaseClient>(
  (_) => Supabase.instance.client,
);

final vocabularyRepositoryProvider = Provider<VocabularyRepository>((ref) {
  return SupabaseVocabularyRepository(ref.read(supabaseClientProvider));
});

final memoryStateRepositoryProvider = Provider<MemoryStateRepository>((ref) {
  return SupabaseMemoryStateRepository(ref.read(supabaseClientProvider));
});

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return SupabaseReviewRepository(ref.read(supabaseClientProvider));
});

final memoryServiceProvider = Provider<MemoryService>(
  (_) => const MemoryService(),
);

final aiExplanationServiceProvider = Provider<AiExplanationService>((ref) {
  return AiExplanationService(ref.read(supabaseClientProvider));
});

final aiEvaluationServiceProvider = Provider<AiEvaluationService>((ref) {
  return AiEvaluationService(ref.read(supabaseClientProvider));
});

final aiQuestionServiceProvider = Provider<AiQuestionService>((ref) {
  return AiQuestionService(ref.read(supabaseClientProvider));
});

final errorPatternRepositoryProvider = Provider<ErrorPatternRepository>((ref) {
  return SupabaseErrorPatternRepository(ref.read(supabaseClientProvider));
});
