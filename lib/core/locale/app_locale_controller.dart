import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appLocaleControllerProvider =
    NotifierProvider<AppLocaleController, Locale>(AppLocaleController.new);

class AppLocaleController extends Notifier<Locale> {
  @override
  Locale build() => const Locale('en');

  void select(Locale locale) {
    state = locale;
  }
}
