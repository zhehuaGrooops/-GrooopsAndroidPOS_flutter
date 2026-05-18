import 'package:admin_desktop/src/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SingleShopResponse parses current user shop payload', () {
    final response = SingleShopResponse.fromJson({
      'timestamp': '2026-03-12T02:07:14.055611Z',
      'status': true,
      'message': 'Successfully',
      'data': {
        'id': 502,
        'uuid': '7361ad98-47ab-436d-90c8-71bcb2b232f8',
        'user_id': 103,
        'tax': 0,
        'phone': '123456789',
        'show_type': 1,
        'open': true,
        'visibility': 0,
        'background_img': 'background.webp',
        'logo_img': 'logo.webp',
        'min_amount': 1,
        'status': 'approved',
        'status_note': 'Johny Restaurant',
        'created_at': '2026-01-07 02:31:56Z',
        'updated_at': '2026-03-11 06:15:06Z',
        'location': {
          'latitude': '47.4143302506288',
          'longitude': '8.532059477976883',
        },
        'translation': {
          'id': 21,
          'locale': 'en',
          'title': 'Johny Restaurant',
          'description': 'Ali Restaurant',
          'address': 'test',
        },
        'seller': {
          'id': 103,
          'firstname': 'John',
          'lastname': 'Cena',
          'role': 'seller',
        },
      },
    });

    expect(response.status, isTrue);
    expect(response.data?.id, 502);
    expect(response.data?.translation?.title, 'Johny Restaurant');
    expect(response.data?.seller?.role, 'seller');
  });
}