import 'package:flutter/widgets.dart';

/// Tracks route coverage for player pages.
///
/// A player page can remain mounted below another root route. Route disposal is
/// therefore not a sufficient signal to stop media playback.
final playerRouteObserver = RouteObserver<ModalRoute<dynamic>>();
