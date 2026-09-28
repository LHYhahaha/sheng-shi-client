import 'package:flutter/foundation.dart';

/// The effective foreground ownership of a playback experience.
enum PlaybackExperienceVisibility {
  hidden,
  visible,
  coveredByRoute,
  backgrounded,
}

/// Health of the desired playback target, derived from media and surface
/// signals rather than from widget visibility alone.
enum PlaybackExperienceHealth {
  idle,
  opening,
  decoding,
  awaitingPresentation,
  healthy,
  failed,
}

@immutable
class PlaybackExperienceTarget {
  const PlaybackExperienceTarget({
    required this.itemId,
    required this.episodeId,
    required this.feedRevision,
  });

  final String itemId;
  final String episodeId;
  final int feedRevision;

  @override
  bool operator ==(Object other) {
    return other is PlaybackExperienceTarget &&
        other.itemId == itemId &&
        other.episodeId == episodeId &&
        other.feedRevision == feedRevision;
  }

  @override
  int get hashCode => Object.hash(itemId, episodeId, feedRevision);
}

@immutable
class ForYouHandoffTicket {
  const ForYouHandoffTicket({
    required this.ticketId,
    required this.target,
    required this.revision,
  });

  final String ticketId;
  final PlaybackExperienceTarget target;
  final int revision;

  @override
  bool operator ==(Object other) {
    return other is ForYouHandoffTicket &&
        other.ticketId == ticketId &&
        other.target == target &&
        other.revision == revision;
  }

  @override
  int get hashCode => Object.hash(ticketId, target, revision);
}

@immutable
class PlaybackExperienceState {
  const PlaybackExperienceState({
    this.visibility = PlaybackExperienceVisibility.hidden,
    this.health = PlaybackExperienceHealth.idle,
    this.target,
    this.handoffTicket,
    this.commandGeneration = 0,
  });

  final PlaybackExperienceVisibility visibility;
  final PlaybackExperienceHealth health;
  final PlaybackExperienceTarget? target;
  final ForYouHandoffTicket? handoffTicket;
  final int commandGeneration;

  PlaybackExperienceState copyWith({
    PlaybackExperienceVisibility? visibility,
    PlaybackExperienceHealth? health,
    PlaybackExperienceTarget? target,
    ForYouHandoffTicket? handoffTicket,
    int? commandGeneration,
    bool clearTarget = false,
    bool clearHandoffTicket = false,
  }) {
    return PlaybackExperienceState(
      visibility: visibility ?? this.visibility,
      health: health ?? this.health,
      target: clearTarget ? null : target ?? this.target,
      handoffTicket: clearHandoffTicket
          ? null
          : handoffTicket ?? this.handoffTicket,
      commandGeneration: commandGeneration ?? this.commandGeneration,
    );
  }
}
