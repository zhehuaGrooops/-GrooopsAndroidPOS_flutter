# admin_desktopda

# Build apk

flutter build apk --flavor dev --dart-define=FLAVOR=dev --release
flutter build apk --flavor uat --dart-define=FLAVOR=uat --release
flutter build apk --flavor prod --dart-define=FLAVOR=prod --release

# Local run

flutter run --flavor dev --dart-define=FLAVOR=dev
flutter run --flavor uat --dart-define=FLAVOR=uat
flutter run --flavor prod --dart-define=FLAVOR=prod
