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
    'noPendingLoads': 'No pending loads',
    'noActiveLoad': 'No active load',
    'noCompletedLoads': 'No completed loads yet',
    'pickupLocation': 'Pickup location',
    'dropoffLocation': 'Dropoff location',
    'buffer': 'Buffer',
    'gpsWaiting': 'GPS: Waiting...',

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

    // Bottom nav
    'loads': 'Loads',

    // Load statuses
    'statusCreated': 'Created',
    'statusAssigned': 'Assigned',
    'statusAccepted': 'Accepted',
    'statusInTransit': 'In Transit',
    'statusCompleted': 'Completed',
    'statusConfirmed': 'Confirmed',
    'statusCancelled': 'Cancelled',

    // Errors (from store)
    'loginError': 'Login error',
    'registrationError': 'Registration error',
    'networkError': 'Network error',
    'failedToSaveProfile': 'Failed to save profile',
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
    'noPendingLoads': 'Нет ожидающих грузов',
    'noActiveLoad': 'Нет активного груза',
    'noCompletedLoads': 'Завершённых грузов пока нет',
    'pickupLocation': 'Место загрузки',
    'dropoffLocation': 'Место разгрузки',
    'buffer': 'Буфер',
    'gpsWaiting': 'GPS: Ожидание...',

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

    // Bottom nav
    'loads': 'Грузы',

    // Load statuses
    'statusCreated': 'Создан',
    'statusAssigned': 'Назначен',
    'statusAccepted': 'Принят',
    'statusInTransit': 'В пути',
    'statusCompleted': 'Завершён',
    'statusConfirmed': 'Подтверждён',
    'statusCancelled': 'Отменён',

    // Errors
    'loginError': 'Ошибка входа',
    'registrationError': 'Ошибка регистрации',
    'networkError': 'Ошибка сети',
    'failedToSaveProfile': 'Не удалось сохранить профиль',
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
    'createAccount': 'Hisob yaratish',
    'email': 'Elektron pochta',
    'password': 'Parol',
    'firstName': 'Ism',
    'lastName': 'Familiya',
    'enterEmailAndPassword': 'Pochta va parolni kiriting',
    'alreadyHaveAccount': 'Hisobingiz bormi? Kirish',
    'dontHaveAccount': "Hisobingiz yo'qmi? Ro'yxatdan o'ting",

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
    'noPendingLoads': 'Kutilayotgan yuklar yo\'q',
    'noActiveLoad': 'Faol yuk yo\'q',
    'noCompletedLoads': 'Tugallangan yuklar hali yo\'q',
    'pickupLocation': 'Yuklash joyi',
    'dropoffLocation': 'Tushirish joyi',
    'buffer': 'Bufer',
    'gpsWaiting': 'GPS: Kutilmoqda...',

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

    // Bottom nav
    'loads': 'Yuklar',

    // Load statuses
    'statusCreated': 'Yaratilgan',
    'statusAssigned': 'Tayinlangan',
    'statusAccepted': 'Qabul qilingan',
    'statusInTransit': 'Yo\'lda',
    'statusCompleted': 'Tugallangan',
    'statusConfirmed': 'Tasdiqlangan',
    'statusCancelled': 'Bekor qilingan',

    // Errors
    'loginError': 'Kirish xatosi',
    'registrationError': 'Ro\'yxatdan o\'tish xatosi',
    'networkError': 'Tarmoq xatosi',
    'failedToSaveProfile': 'Profilni saqlash amalga oshmadi',
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
