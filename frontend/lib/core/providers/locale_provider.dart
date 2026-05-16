import 'package:flutter_riverpod/flutter_riverpod.dart';

final localeProvider = StateNotifierProvider<LocaleNotifier, String>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<String> {
  LocaleNotifier() : super('ru'); // default to 'ru'

  void setLocale(String lang) {
    if (state != lang) {
      state = lang;
    }
  }
}
