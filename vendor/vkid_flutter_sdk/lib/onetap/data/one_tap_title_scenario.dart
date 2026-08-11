part of '../../library_vkid.dart';

/// A scenario that modifies One Tap title.
enum OneTapTitleScenario {
  /// Default auth scenario.
  signIn,

  /// A scenario for service sector and educational services.
  signUp,

  /// A scenario for cases with a discount or bonus.
  get,

  /// A scenario for the financial sector (account, card, deposit).
  open,

  /// A scenario for the financial sector and complex products (project cost, mortgage).
  calculate,

  /// A scenario for e-commerce carts with text "order as {user}".
  order,

  /// A scenario for e-commerce carts with text "place order as {user}".
  placeOrder,

  /// A scenario for e-commerce and services where you need to submit a request for participation.
  sendRequest,

  /// A scenario for educational projects and participation in tenders.
  participate,
}
