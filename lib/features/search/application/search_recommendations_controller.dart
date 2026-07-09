import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/runtime/api_lang_provider.dart';
import '../../player/data/mapper/player_feed_mapper.dart';
import '../../player/data/player_remote_data_source_provider.dart';
import '../../player/domain/player_feed.dart';

final searchRecommendationsProvider =
    FutureProvider.autoDispose<List<PlayerFeedItem>>((ref) async {
      ref.watch(apiLangProvider);
      final response = await ref
          .watch(playerRemoteDataSourceProvider)
          .listForYouFeed();
      const mapper = PlayerFeedMapper();
      return response.items.map(mapper.mapForYouItem).toList(growable: false);
    });
