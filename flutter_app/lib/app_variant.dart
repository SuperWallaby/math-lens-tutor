/// 앱 변형: full(우열) | lite(우열 라이트)
enum AppVariant { full, lite }

const _variantRaw = String.fromEnvironment('APP_VARIANT', defaultValue: 'full');

AppVariant get appVariant =>
    _variantRaw.trim().toLowerCase() == 'lite' ? AppVariant.lite : AppVariant.full;

bool get isLiteApp => appVariant == AppVariant.lite;

String get appDisplayName => isLiteApp ? '우열 라이트' : '우열';

String get appVariantHeader => isLiteApp ? 'lite' : 'full';

String get deviceIdPrefsKey =>
    isLiteApp ? 'anonymous_device_id_lite' : 'anonymous_device_id';
