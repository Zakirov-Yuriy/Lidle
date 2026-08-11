part of '../../library_vkid.dart';

/// A scenario for the One Tap authentication process.
enum OneTapBottomSheetScenario {
  /// The standard scenario for entering a service.
  enterService,

  /// The scenario for event registration.
  registrationForTheEvent,

  /// The scenario for application-related authentication.
  application,

  /// The scenario for ordering within a service.
  orderInService,

  /// The scenario for general order-related authentication.
  order,

  /// The scenario for general entering into an account.
  enterToAccount,
}
