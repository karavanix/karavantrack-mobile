import 'package:flutter/widgets.dart';

/// Lightweight localization — no codegen, no ARB files.
/// Supports: English (en), Russian (ru), Uzbek (uz).
class AppLocalizations extends InheritedWidget {
  const AppLocalizations({
    super.key,
    required this.locale,
    required super.child,
  });

  final String locale;

  static AppLocalizations of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppLocalizations>()!;
  }

  String tr(String key) {
    final map = _translations[locale] ?? _translations['en']!;
    return map[key] ?? _translations['en']![key] ?? key;
  }

  @override
  bool updateShouldNotify(AppLocalizations oldWidget) =>
      locale != oldWidget.locale;

  // ─── Translation maps ──────────────────────────────────────────────────

  static const Map<String, Map<String, String>> _translations = {
    'en': _en,
    'ru': _ru,
    'uz': _uz,
  };

  // ── English ────────────────────────────────────────────────────────────
  static const _en = <String, String>{
    // General
    'appName': 'YoolLive',
    'driver': 'Driver',
    'refresh': 'Refresh',
    'online': 'Online',
    'offline': 'Offline',
    'saving': 'Saving...',
    'save': 'Save',

    // Login
    'signIn': 'Sign in',
    'createAccount': 'Create account',
    'email': 'Email',
    'password': 'Password',
    'firstName': 'First name',
    'lastName': 'Last name',
    'enterEmailAndPassword': 'Enter email and password',
    'alreadyHaveAccount': 'Already have an account? Sign in',
    'dontHaveAccount': "Don't have an account? Sign up",
    'continueWithApple': 'Continue with Apple',
    'continueWithTelegram': 'Continue with Telegram',
    'orContinueWith': 'or continue with',
    'tagline': 'Move loads. Get paid.',
    'showPassword': 'Show password',
    'hidePassword': 'Hide password',
    'byCreatingAccount': 'By creating an account, you agree to our',
    'termsOfService': 'Terms of Service',
    'privacyPolicy': 'Privacy Policy',
    'and': 'and',
    'chooseYourLanguage': 'Choose your language',
    'continueButton': 'Continue',
    'skip': 'Skip',
    'next': 'Next',
    'getStarted': 'Get started',
    'onboardTitle1': 'Loads at your fingertips',
    'onboardBody1': 'Browse available loads and accept the ones that fit your route.',
    'onboardTitle2': 'Track every mile',
    'onboardBody2': 'Built-in GPS keeps shippers updated so you can focus on the road.',
    'onboardTitle3': 'Get paid faster',
    'onboardBody3': 'Confirm delivery in-app and close the loop the moment you drop off.',
    'verifyEmail': 'Verify Email',
    'verificationCodeSent': 'A verification code was sent to',
    'enterVerificationCode': 'Please enter the verification code',
    'verificationCodeLabel': 'Verification Code',
    'verify': 'Verify',

    // Profile setup
    'completeProfile': 'Complete Profile',
    'setUpYourProfile': 'Set up your profile',
    'enterNameToContinue': 'Enter your name to continue.',
    'firstNameRequired': 'First name *',
    'saveAndContinue': 'Save & Continue',

    // Home tabs
    'pending': 'Pending',
    'active': 'Active',
    'history': 'History',
    'statusHistory': 'Status History',
    'noPendingLoads': 'No pending loads',
    'endOfList': 'End of list',
    'noActiveLoad': 'No active load',
    'noActiveLoadSubtitle': 'Accept a load from the list below to start working',
    'noCompletedLoads': 'No completed loads yet',
    'pickupLocation': 'Pickup location',
    'dropoffLocation': 'Dropoff location',
    'buffer': 'Buffer',
    'gpsWaiting': 'GPS: Waiting...',
    'gpsActive': 'GPS active',
    'gpsSearching': 'GPS searching',
    'acceptBlockedHint': 'Finish your active load to accept a new one',
    'noActiveLoadSubtitleNew': 'New loads will appear here',

    // Load details
    'load': 'Load',
    'loadNotFound': 'Load not found',
    'details': 'Details',
    'pickup': 'Pickup',
    'dropoff': 'Dropoff',
    'description': 'Description',
    'pickupTime': 'Pickup time',
    'dropoffTime': 'Dropoff time',
    'created': 'Created',
    'acceptLoad': 'Accept Load',
    'loadAccepted': 'Load accepted!',
    'actionBeginPickup': 'Begin Pickup',
    'actionConfirmPickup': 'Confirm Cargo Loaded',
    'actionStartTransit': 'Start Transit',
    'actionBeginDropoff': 'Begin Dropoff',
    'actionConfirmDropoff': 'Confirm Delivery',

    // Active load
    'activeLoad': 'Active Load',
    'loadNotFoundOrInactive': 'Load not found or no longer active',
    'tracking': 'Tracking',
    'gpsPosition': 'GPS Position',
    'waitingForGps': 'Waiting for GPS...',
    'actions': 'Actions',
    'startTransit': 'Start Transit',
    'complete': 'Complete',

    // Settings
    'settings': 'Settings',
    'editProfile': 'Edit Profile',
    'saveChanges': 'Save Changes',
    'profileUpdated': 'Profile updated successfully',
    'support': 'Support',
    'signOut': 'Sign out',
    'language': 'Language',
    'firstNameIsRequired': 'First name is required',
    'theme': 'Theme',
    'darkMode': 'Dark',
    'lightMode': 'Light',
    'preferences': 'Preferences',
    'account': 'Account',
    'edit': 'Edit',
    'contactSupport': 'Contact support',
    'copied': 'Copied to clipboard',
    'selectLanguage': 'Select language',
    'selectTheme': 'Select theme',
    'cancel': 'Cancel',
    'maybeLater': 'Maybe Later',
    'deleteAccount': 'Delete Account',
    'deleteAccountConfirmTitle': 'Delete Account?',
    'deleteAccountConfirmMessage':
        'This action is permanent and cannot be undone. All your data will be deleted.',
    'deleteAccountButton': 'Delete Account',
    'deleteAccountError': 'Failed to delete account. Please try again.',

    // Bottom nav
    'loads': 'Loads',

    // Load statuses
    'statusCreated': 'Created',
    'statusAssigned': 'Assigned',
    'statusAccepted': 'Accepted',
    'statusPickingUp': 'Picking Up',
    'statusPickedUp': 'Picked Up',
    'statusInTransit': 'In Transit',
    'statusDroppingOff': 'Dropping Off',
    'statusDroppedOff': 'Dropped Off',
    'statusCompleted': 'Completed',
    'statusConfirmed': 'Confirmed',
    'statusCancelled': 'Cancelled',
    'awaitingShipperConfirmation': 'Awaiting shipper confirmation',
    'awaitingConfirmationDetail':
        'Your delivery has been confirmed. Waiting for the shipper to verify and close the load.',

    // Errors (from store)
    'loginError': 'Login error',
    'registrationError': 'Registration error',
    'networkError': 'Network error',
    'failedToSaveProfile': 'Failed to save profile',

    // Connectivity banner
    'connecting': 'Connecting',
    'onlineStatus': 'Online',

    // Relative time
    'justNow': 'Just now',
    'minutesAgoShort': 'm ago',
    'hoursAgoShort': 'h ago',
    'daysAgoShort': 'd ago',

    // GPS dialog
    'gpsOffTitle': 'GPS is Off',
    'gpsOffMessage':
        'Location services are disabled. Please turn on GPS so your position can be tracked.',
    'turnOnGps': 'Turn On GPS',

    // Always-location permission dialog
    'alwaysLocationTitle': 'Background Location Required',
    'alwaysLocationMessage':
        'This app needs "Allow all the time" location access to track your position even when the app is closed or in the background.',
    'alwaysLocationStep1': 'Tap "Open Settings" below',
    'alwaysLocationStep2': 'Select "Permissions" → "Location"',
    'alwaysLocationStep3': 'Choose "Allow all the time"',
    'alwaysLocationIosStep1': 'Tap "Open Settings" below',
    'alwaysLocationIosStep2': 'Select "Location"',
    'alwaysLocationIosStep3': 'Choose "Always"',
    'openAppSettings': 'Open Settings',

    // Stepper labels (short)
    'stepAccepted': 'Accepted',
    'stepPickup': 'Pickup',
    'stepLoaded': 'Loaded',
    'stepTransit': 'Transit',
    'stepDropoff': 'Dropoff',
    'stepDelivered': 'Delivered',
  };

  // ── Russian ────────────────────────────────────────────────────────────
  static const _ru = <String, String>{
    // General
    'appName': 'YoolLive',
    'driver': 'Водитель',
    'refresh': 'Обновить',
    'online': 'В сети',
    'offline': 'Не в сети',
    'saving': 'Сохранение...',
    'save': 'Сохранить',

    // Login
    'signIn': 'Войти',
    'createAccount': 'Создать аккаунт',
    'email': 'Эл. почта',
    'password': 'Пароль',
    'firstName': 'Имя',
    'lastName': 'Фамилия',
    'enterEmailAndPassword': 'Введите почту и пароль',
    'alreadyHaveAccount': 'Уже есть аккаунт? Войти',
    'dontHaveAccount': 'Нет аккаунта? Зарегистрироваться',
    'continueWithApple': 'Войти через Apple',
    'continueWithTelegram': 'Войти через Telegram',
    'orContinueWith': 'или продолжить через',
    'tagline': 'Возите грузы. Получайте оплату.',
    'showPassword': 'Показать пароль',
    'hidePassword': 'Скрыть пароль',
    'byCreatingAccount': 'Создавая аккаунт, вы соглашаетесь с',
    'termsOfService': 'Условиями использования',
    'privacyPolicy': 'Политикой конфиденциальности',
    'and': 'и',
    'chooseYourLanguage': 'Выберите язык',
    'continueButton': 'Продолжить',
    'skip': 'Пропустить',
    'next': 'Далее',
    'getStarted': 'Начать',
    'onboardTitle1': 'Грузы под рукой',
    'onboardBody1': 'Просматривайте доступные грузы и принимайте те, что подходят вашему маршруту.',
    'onboardTitle2': 'Каждый километр на виду',
    'onboardBody2': 'Встроенный GPS держит грузоотправителей в курсе, а вы сосредоточены на дороге.',
    'onboardTitle3': 'Получайте оплату быстрее',
    'onboardBody3': 'Подтверждайте доставку в приложении и закрывайте груз сразу после разгрузки.',
    'verifyEmail': 'Подтверждение почты',
    'verificationCodeSent': 'Код подтверждения отправлен на',
    'enterVerificationCode': 'Введите код подтверждения',
    'verificationCodeLabel': 'Код подтверждения',
    'verify': 'Подтвердить',

    // Profile setup
    'completeProfile': 'Заполнить профиль',
    'setUpYourProfile': 'Настройте свой профиль',
    'enterNameToContinue': 'Введите ваше имя для продолжения.',
    'firstNameRequired': 'Имя *',
    'saveAndContinue': 'Сохранить и продолжить',

    // Home tabs
    'pending': 'Ожидающие',
    'active': 'Активные',
    'history': 'История',
    'statusHistory': 'История статусов',
    'noPendingLoads': 'Нет ожидающих грузов',
    'endOfList': 'Конец списка',
    'noActiveLoad': 'Нет активного груза',
    'noActiveLoadSubtitle': 'Примите груз из списка ниже, чтобы начать работу',
    'noCompletedLoads': 'Завершённых грузов пока нет',
    'pickupLocation': 'Место загрузки',
    'dropoffLocation': 'Место разгрузки',
    'buffer': 'Буфер',
    'gpsWaiting': 'GPS: Ожидание...',
    'gpsActive': 'GPS активен',
    'gpsSearching': 'GPS поиск',
    'acceptBlockedHint': 'Завершите активный груз, чтобы принять новый',
    'noActiveLoadSubtitleNew': 'Новые грузы появятся здесь',

    // Load details
    'load': 'Груз',
    'loadNotFound': 'Груз не найден',
    'details': 'Детали',
    'pickup': 'Загрузка',
    'dropoff': 'Разгрузка',
    'description': 'Описание',
    'pickupTime': 'Время загрузки',
    'dropoffTime': 'Время разгрузки',
    'created': 'Создан',
    'acceptLoad': 'Принять груз',
    'loadAccepted': 'Груз принят!',
    'actionBeginPickup': 'Начать забор',
    'actionConfirmPickup': 'Груз загружен',
    'actionStartTransit': 'Начать перевозку',
    'actionBeginDropoff': 'Начать разгрузку',
    'actionConfirmDropoff': 'Подтвердить доставку',

    // Active load
    'activeLoad': 'Активный груз',
    'loadNotFoundOrInactive': 'Груз не найден или больше не активен',
    'tracking': 'Отслеживание',
    'gpsPosition': 'Позиция GPS',
    'waitingForGps': 'Ожидание GPS...',
    'actions': 'Действия',
    'startTransit': 'Начать перевозку',
    'complete': 'Завершить',

    // Settings
    'settings': 'Настройки',
    'editProfile': 'Редактировать профиль',
    'saveChanges': 'Сохранить изменения',
    'profileUpdated': 'Профиль обновлён',
    'support': 'Поддержка',
    'signOut': 'Выйти',
    'language': 'Язык',
    'firstNameIsRequired': 'Имя обязательно',
    'theme': 'Тема',
    'darkMode': 'Тёмная',
    'lightMode': 'Светлая',
    'preferences': 'Настройки',
    'account': 'Аккаунт',
    'edit': 'Изменить',
    'contactSupport': 'Связаться с поддержкой',
    'copied': 'Скопировано',
    'selectLanguage': 'Выберите язык',
    'selectTheme': 'Выберите тему',
    'cancel': 'Отмена',
    'maybeLater': 'Позже',
    'deleteAccount': 'Удалить аккаунт',
    'deleteAccountConfirmTitle': 'Удалить аккаунт?',
    'deleteAccountConfirmMessage':
        'Это действие необратимо. Все ваши данные будут удалены.',
    'deleteAccountButton': 'Удалить',
    'deleteAccountError': 'Не удалось удалить аккаунт. Попробуйте ещё раз.',

    // Bottom nav
    'loads': 'Грузы',

    // Load statuses
    'statusCreated': 'Создан',
    'statusAssigned': 'Назначен',
    'statusAccepted': 'Принят',
    'statusPickingUp': 'Забор',
    'statusPickedUp': 'Загружен',
    'statusInTransit': 'В пути',
    'statusDroppingOff': 'Разгрузка',
    'statusDroppedOff': 'Доставлен',
    'statusCompleted': 'Завершён',
    'statusConfirmed': 'Подтверждён',
    'statusCancelled': 'Отменён',
    'awaitingShipperConfirmation': 'Ожидание подтверждения грузоотправителя',
    'awaitingConfirmationDetail':
        'Доставка подтверждена. Ожидаем подтверждения от грузоотправителя.',

    // Errors
    'loginError': 'Ошибка входа',
    'registrationError': 'Ошибка регистрации',
    'networkError': 'Ошибка сети',
    'failedToSaveProfile': 'Не удалось сохранить профиль',

    // Connectivity banner
    'connecting': 'Подключение',
    'onlineStatus': 'В сети',

    // Relative time
    'justNow': 'Только что',
    'minutesAgoShort': ' мин назад',
    'hoursAgoShort': ' ч назад',
    'daysAgoShort': ' дн назад',

    // GPS dialog
    'gpsOffTitle': 'GPS выключен',
    'gpsOffMessage':
        'Службы геолокации отключены. Включите GPS, чтобы ваше местоположение отслеживалось.',
    'turnOnGps': 'Включить GPS',

    // Always-location permission dialog
    'alwaysLocationTitle': 'Требуется фоновая геолокация',
    'alwaysLocationMessage':
        'Приложению необходим доступ «Разрешить всё время» к местоположению, чтобы отслеживать вашу позицию даже при закрытом приложении.',
    'alwaysLocationStep1': 'Нажмите «Открыть настройки» ниже',
    'alwaysLocationStep2': 'Выберите «Разрешения» → «Местоположение»',
    'alwaysLocationStep3': 'Выберите «Разрешить всё время»',
    'alwaysLocationIosStep1': 'Нажмите «Открыть настройки» ниже',
    'alwaysLocationIosStep2': 'Выберите «Геолокация»',
    'alwaysLocationIosStep3': 'Выберите «Всегда»',
    'openAppSettings': 'Открыть настройки',

    // Stepper labels (short)
    'stepAccepted': 'Принят',
    'stepPickup': 'Погрузка',
    'stepLoaded': 'Загружен',
    'stepTransit': 'В пути',
    'stepDropoff': 'Разгрузка',
    'stepDelivered': 'Доставлен',
  };

  // ── Uzbek ──────────────────────────────────────────────────────────────
  static const _uz = <String, String>{
    // General
    'appName': 'YoolLive',
    'driver': 'Haydovchi',
    'refresh': 'Yangilash',
    'online': 'Onlayn',
    'offline': 'Oflayn',
    'saving': 'Saqlanmoqda...',
    'save': 'Saqlash',

    // Login
    'signIn': 'Kirish',
    'createAccount': 'Akkaunt yaratish',
    'email': 'Elektron pochta',
    'password': 'Parol',
    'firstName': 'Ism',
    'lastName': 'Familiya',
    'enterEmailAndPassword': 'Pochta va parolni kiriting',
    'alreadyHaveAccount': 'Akkaunt bormi? Kirish',
    'dontHaveAccount': "Akkaunt yo'qmi? Ro'yxatdan o'ting",
    'continueWithApple': 'Apple orqali kirish',
    'continueWithTelegram': 'Telegram orqali kirish',
    'orContinueWith': 'yoki orqali davom eting',
    'tagline': 'Yuk tashing. Pul ishlang.',
    'showPassword': 'Parolni ko\'rsatish',
    'hidePassword': 'Parolni yashirish',
    'byCreatingAccount': 'Akkaunt yaratish orqali siz bizning',
    'termsOfService': 'Foydalanish shartlarimizga',
    'privacyPolicy': 'Maxfiylik siyosatimizga',
    'and': 've',
    'chooseYourLanguage': 'Tilingizni tanlang',
    'continueButton': 'Davom etish',
    'skip': 'O\'tkazib yuborish',
    'next': 'Keyingi',
    'getStarted': 'Boshlash',
    'onboardTitle1': 'Yuklar qo\'l ostida',
    'onboardBody1': 'Mavjud yuklarni ko\'ring va o\'z yo\'nalishingizga mosini qabul qiling.',
    'onboardTitle2': 'Har bir kilometr nazoratda',
    'onboardBody2': 'O\'rnatilgan GPS jo\'natuvchilarni xabardor qiladi, siz esa yo\'lga e\'tibor qaratasiz.',
    'onboardTitle3': 'Tezroq pul oling',
    'onboardBody3': 'Yetkazib berishni ilovada tasdiqlang va tushirgan zahoti yukni yoping.',
    'verifyEmail': 'Emailni tasdiqlash',
    'verificationCodeSent': 'Tasdiqlash kodi yuborildi:',
    'enterVerificationCode': 'Tasdiqlash kodini kiriting',
    'verificationCodeLabel': 'Tasdiqlash kodi',
    'verify': 'Tasdiqlash',

    // Profile setup
    'completeProfile': 'Profilni to\'ldirish',
    'setUpYourProfile': 'Profilingizni sozlang',
    'enterNameToContinue': 'Davom etish uchun ismingizni kiriting.',
    'firstNameRequired': 'Ism *',
    'saveAndContinue': 'Saqlash va davom etish',

    // Home tabs
    'pending': 'Kutilmoqda',
    'active': 'Faol',
    'history': 'Tarix',
    'statusHistory': 'Status tarixi',
    'noPendingLoads': 'Kutilayotgan yuklar yo\'q',
    'endOfList': 'Ro\'yxat oxiri',
    'noActiveLoad': 'Faol yuk yo\'q',
    'noActiveLoadSubtitle': 'Ishlashni boshlash uchun quyidagi ro\'yxatdan yukni qabul qiling',
    'noCompletedLoads': 'Tugallangan yuklar hali yo\'q',
    'pickupLocation': 'Yuklash joyi',
    'dropoffLocation': 'Tushirish joyi',
    'buffer': 'Bufer',
    'gpsWaiting': 'GPS: Kutilmoqda...',
    'gpsActive': 'GPS faol',
    'gpsSearching': 'GPS qidirilmoqda',
    'acceptBlockedHint': 'Yangi yuk qabul qilish uchun faol yukni tugating',
    'noActiveLoadSubtitleNew': 'Yangi yuklar shu yerda paydo bo\'ladi',

    // Load details
    'load': 'Yuk',
    'loadNotFound': 'Yuk topilmadi',
    'details': 'Tafsilotlar',
    'pickup': 'Yuklash',
    'dropoff': 'Tushirish',
    'description': 'Tavsif',
    'pickupTime': 'Yuklash vaqti',
    'dropoffTime': 'Tushirish vaqti',
    'created': 'Yaratilgan',
    'acceptLoad': 'Yukni qabul qilish',
    'loadAccepted': 'Yuk qabul qilindi!',
    'actionBeginPickup': 'Yuklashni boshlash',
    'actionConfirmPickup': 'Yuk yuklandi',
    'actionStartTransit': 'Tashishni boshlash',
    'actionBeginDropoff': 'Tushirishni boshlash',
    'actionConfirmDropoff': 'Yetkazishni tasdiqlash',

    // Active load
    'activeLoad': 'Faol yuk',
    'loadNotFoundOrInactive': 'Yuk topilmadi yoki faol emas',
    'tracking': 'Kuzatuv',
    'gpsPosition': 'GPS joylashuvi',
    'waitingForGps': 'GPS kutilmoqda...',
    'actions': 'Amallar',
    'startTransit': 'Tashishni boshlash',
    'complete': 'Yakunlash',

    // Settings
    'settings': 'Sozlamalar',
    'editProfile': 'Profilni tahrirlash',
    'saveChanges': 'O\'zgarishlarni saqlash',
    'profileUpdated': 'Profil muvaffaqiyatli yangilandi',
    'support': 'Qo\'llab-quvvatlash',
    'signOut': 'Chiqish',
    'language': 'Til',
    'firstNameIsRequired': 'Ism kiritish shart',
    'theme': 'Mavzu',
    'darkMode': 'Qoʻngʻir',
    'lightMode': 'Yorqin',
    'preferences': 'Sozlamalar',
    'account': 'Akkaunt',
    'edit': 'Tahrirlash',
    'contactSupport': 'Yordam bilan bog\'lanish',
    'copied': 'Nusxalandi',
    'selectLanguage': 'Tilni tanlang',
    'selectTheme': 'Mavzuni tanlang',
    'cancel': 'Bekor qilish',
    'maybeLater': 'Keyinroq',
    'deleteAccount': "Akkauntni o'chirish",
    'deleteAccountConfirmTitle': "Akkauntni o'chirasizmi?",
    'deleteAccountConfirmMessage':
        "Bu amalni qaytarib bo'lmaydi. Barcha ma'lumotlaringiz o'chiriladi.",
    'deleteAccountButton': "O'chirish",
    'deleteAccountError': "Akkauntni o'chirib bo'lmadi. Qayta urinib ko'ring.",

    // Bottom nav
    'loads': 'Yuklar',

    // Load statuses
    'statusCreated': 'Yaratilgan',
    'statusAssigned': 'Tayinlangan',
    'statusAccepted': 'Qabul qilingan',
    'statusPickingUp': 'Yuklanmoqda',
    'statusPickedUp': 'Yuklandi',
    'statusInTransit': 'Yo\'lda',
    'statusDroppingOff': 'Tushirilmoqda',
    'statusDroppedOff': 'Yetkazildi',
    'statusCompleted': 'Tugallangan',
    'statusConfirmed': 'Tasdiqlangan',
    'statusCancelled': 'Bekor qilingan',
    'awaitingShipperConfirmation': "Jo'natuvchi tasdig'ini kutmoqda",
    'awaitingConfirmationDetail':
        "Yetkazib berish tasdiqlandi. Jo'natuvchi yopishini kutmoqdamiz.",

    // Errors
    'loginError': 'Kirish xatosi',
    'registrationError': 'Ro\'yxatdan o\'tish xatosi',
    'networkError': 'Tarmoq xatosi',
    'failedToSaveProfile': 'Profilni saqlash amalga oshmadi',

    // Connectivity banner
    'connecting': 'Ulanmoqda',
    'onlineStatus': 'Onlayn',

    // Relative time
    'justNow': 'Hozir',
    'minutesAgoShort': ' daq oldin',
    'hoursAgoShort': ' soat oldin',
    'daysAgoShort': ' kun oldin',

    // GPS dialog
    'gpsOffTitle': 'GPS o\'chiq',
    'gpsOffMessage':
        'Joylashuv xizmatlari o\'chirilgan. GPS ni yoqing, shunda joylashuvingiz kuzatiladi.',
    'turnOnGps': 'GPS ni yoqish',

    // Always-location permission dialog
    'alwaysLocationTitle': 'Fon joylashuvi kerak',
    'alwaysLocationMessage':
        'Ilova yopilgan yoki fonda bo\'lganda ham joylashuvingizni kuzatish uchun "Har doim ruxsat berish" kerak.',
    'alwaysLocationStep1': 'Quyidagi "Sozlamalarni ochish" tugmasini bosing',
    'alwaysLocationStep2': '"Ruxsatlar" → "Joylashuv" ni tanlang',
    'alwaysLocationStep3': '"Har doim ruxsat berish" ni tanlang',
    'alwaysLocationIosStep1': 'Quyidagi "Sozlamalarni ochish" tugmasini bosing',
    'alwaysLocationIosStep2': '"Joylashuv" ni tanlang',
    'alwaysLocationIosStep3': '"Doim" ni tanlang',
    'openAppSettings': 'Sozlamalarni ochish',

    // Stepper labels (short)
    'stepAccepted': 'Qabul',
    'stepPickup': 'Yuklash',
    'stepLoaded': 'Yuklandi',
    'stepTransit': 'Yo\'lda',
    'stepDropoff': 'Tushirish',
    'stepDelivered': 'Yetkazildi',
  };

  /// Language display names for the language picker.
  static const Map<String, String> languageNames = {
    'en': 'English',
    'ru': 'Русский',
    'uz': 'O\'zbek',
  };

  /// Supported locale codes.
  static const List<String> supportedLocales = ['en', 'ru', 'uz'];
}
