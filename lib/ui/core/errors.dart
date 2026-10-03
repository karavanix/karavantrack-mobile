import '../../data/services/api/api_exception.dart';
import 'l10n/l10n.dart';

/// What to tell the driver about a failed request. Known server codes get
/// a translated sentence; anything else falls back to the server's own
/// message, and failing that to a generic one. Screens handle the codes
/// that mean something specific to them before calling this.
String errorText(AppLocalizations l10n, Exception error) => switch (error) {
  NetworkException() => l10n.errorNetwork,
  HttpException(code: 'OTP_MISMATCH') => l10n.errorCodeWrong,
  HttpException(code: 'OTP_EXPIRED' || 'OTP_NOT_FOUND') =>
    l10n.errorCodeExpired,
  HttpException(code: 'OTP_TOO_MANY_ATTEMPTS') => l10n.errorCodeTooMany,
  HttpException(code: 'TOO_MANY_REQUESTS') => l10n.errorTooManyRequests,
  HttpException(code: 'CARRIER_HAS_ACTIVE_LOAD') =>
    l10n.inviteCarrierHasActiveLoad,
  HttpException(statusCode: >= 500) => l10n.errorServer,
  HttpException(:final message) when message.isNotEmpty => message,
  _ => l10n.errorServer,
};
