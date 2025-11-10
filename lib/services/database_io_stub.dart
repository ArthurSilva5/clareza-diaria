// Stub para Platform quando rodando na web
// dart:io não está disponível na web

class Platform {
  static bool get isWindows => false;
  static bool get isLinux => false;
  static bool get isMacOS => false;
}

