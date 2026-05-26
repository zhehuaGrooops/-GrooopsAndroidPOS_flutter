class SecretVars {
  SecretVars._();

  /// api variables
  // static const String baseUrl = "https://api.pos.grooops.com.my";
  // static const String webUrl = "https://grooops.com.my";
  // static const String baseUrl = "https://api.odera.com.my";
  // static const String webUrl = "https://odera.com.my";
  // static const String baseUrl = "https://grooops-api.dev-rmaict.com";
  // static const String webUrl = "https://grooops.dev-rmaict.com";
  // static const String baseUrl = "https://api.pos.grooops.com.my";
  // static const String webUrl = "https://admin.pos.grooops.com.my";

  // static const String baseUrl = "http://192.168.100.206:29001";
  // static const String webUrl = "http://192.168.100.206:3000";

  static const _flavor = String.fromEnvironment('FLAVOR', defaultValue: 'prod');

  static String get flavor => _flavor;

  static String get baseUrl {
    switch (_flavor) {
      case 'uat':
        return 'https://api.pos.grooops.com.my';
      case 'dev':
        return 'http://192.168.100.206:29001';
      default:
        return 'https://api.odera.com.my';
    }
  }

  static String get webUrl {
    switch (_flavor) {
      case 'uat':
        return 'https://grooops.com.my';
      case 'dev':
        return 'http://192.168.100.206:3000';
      default:
        return 'https://odera.com.my';
    }
  }
}

