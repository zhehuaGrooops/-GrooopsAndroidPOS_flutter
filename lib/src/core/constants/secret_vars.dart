class SecretVars {
  SecretVars._();

  static const _flavor = String.fromEnvironment('FLAVOR', defaultValue: 'prod');

  static String get flavor => _flavor;

  static String get baseUrl {
    switch (_flavor) {
      case 'uat':
        return 'https://api.pos.grooops.com.my';
      case 'dev':
        return 'http://10.216.96.45:8000';
      default:
        return 'https://api.odera.com.my';
    }
  }

  static String get webUrl {
    switch (_flavor) {
      case 'uat':
        return 'https://grooops.com.my';
      case 'dev':
        return 'http://10.0.2.2:3000';
      default:
        return 'https://odera.com.my';
    }
  }
}
