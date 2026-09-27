import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/features/social/domain/entities/creator_profile_entity.dart';
import 'package:hums_mobile/features/social/presentation/providers/follow_notifier.dart';

final creatorProfileProvider =
    FutureProvider.family<CreatorDetailEntity, String>((ref, creatorId) async {
  final repository = ref.watch(creatorRepositoryProvider);
  final profile = await repository.getCreatorProfile(creatorId);

  // Synchronize follow notifier with initial loaded creator profile
  final followNotifier = ref.read(followNotifierProvider(creatorId).notifier);
  followNotifier.initialize(
    isFollowing: profile.isFollowing ?? false,
    followersCount: profile.followersCount,
  );

  return profile;
});
