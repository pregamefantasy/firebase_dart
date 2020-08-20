import '../auth_provider.dart';
import 'oauth.dart';

/// This class should be used to either create a new Facebook credential with an
/// access code, or use the provider to trigger user authentication flows.
///
/// For example, on web based platforms pass the provider to a Firebase method
/// (such as [signInWithPopup]):
///
/// ```dart
/// FacebookAuthProvider facebookProvider = FacebookAuthProvider();
/// facebookProvider.addScope('user_birthday');
/// facebookProvider.setCustomParameters({
///   'display': 'popup',
/// });
///
/// FirebaseAuth.instance.signInWithPopup(facebookProvider)
///   .then(...);
/// ```
///
/// If authenticating with Facebook via a 3rd party, use the returned
/// `accessToken` to sign-in or link the user with the created credential,
/// for example:
///
/// ```dart
/// String accessToken = '...'; // From 3rd party provider
/// FacebookAuthCredential facebookAuthCredential = FacebookAuthProvider.credential(accessToken);
///
/// FirebaseAuth.instance.signInWithCredential(facebookAuthCredential)
///   .then(...);
/// ```
class FacebookAuthProvider extends AuthProvider {
  /// Creates a new instance.
  FacebookAuthProvider() : super(PROVIDER_ID);

  static const String PROVIDER_ID = 'facebook.com';

  /// This corresponds to the sign-in method identifier.
  static String get FACEBOOK_SIGN_IN_METHOD => PROVIDER_ID;

  final List<String> _scopes = [];
  Map<dynamic, dynamic> _parameters = {};

  /// Returns the currently assigned scopes to this provider instance.
  List<String> get scopes {
    return _scopes;
  }

  /// Returns the parameters for this provider instance.
  Map<dynamic, dynamic> get parameters {
    return _parameters;
  }

  /// Adds Facebook OAuth scope.
  FacebookAuthProvider addScope(String scope) {
    assert(scope != null);
    _scopes.add(scope);
    return this;
  }

  /// Sets the OAuth custom parameters to pass in a Facebook OAuth
  /// request for popup and redirect sign-in operations.
  FacebookAuthProvider setCustomParameters(
      Map<dynamic, dynamic> customOAuthParameters) {
    assert(customOAuthParameters != null);
    _parameters = customOAuthParameters;
    return this;
  }

  /// Create a new [FacebookAuthCredential] from a provided [accessToken];
  static OAuthCredential credential(String accessToken) {
    assert(accessToken != null);
    return FacebookAuthCredential._(
      accessToken,
    );
  }
}

/// The auth credential returned from calling
/// [FacebookAuthProvider.credential].
class FacebookAuthCredential extends OAuthCredential {
  FacebookAuthCredential._(String accessToken)
      : super(
            providerId: FacebookAuthProvider.PROVIDER_ID,
            signInMethod: FacebookAuthProvider.FACEBOOK_SIGN_IN_METHOD,
            accessToken: accessToken);
}
