import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:multicloud/pages/state/models.dart';
import 'package:multicloud/pages/widgets/bouncing_dots.dart';
import 'package:multicloud/pages/widgets/widgets.dart';
import 'package:multicloud/storageproviders/github/github.dart';
import 'package:provider/provider.dart';

class GithubSignIn extends StatelessWidget {
  static const String _clientId = 'Ov23liYRYQKHDr7iaWvJ';
  static const String _clientSecret =
      '015799f12d3999f97a120287480c35b5ad7b680d';
  static const String _redirectUrl = 'altrcloud://callback';
  static const String _authorizeUrl =
      'https://github.com/login/oauth/authorize';
  static const String _tokenUrl = 'https://github.com/login/oauth/access_token';
  static const List<String> _scopes = ['openapi', 'repo', 'user', 'admin:org'];

  final FlutterAppAuth _appAuth = const FlutterAppAuth();

  const GithubSignIn({super.key});

  Future<void> _signIn(BuildContext context) async {
    StorageProviderModel storageProvider = context.read<StorageProviderModel>();
    ContentModel contents = context.read<ContentModel>();

    if (contents.isLoading) {
      return;
    }

    try {
      final AuthorizationTokenResponse? result =
          await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _clientId,
          _redirectUrl,
          clientSecret: _clientSecret,
          serviceConfiguration: const AuthorizationServiceConfiguration(
            authorizationEndpoint: _authorizeUrl,
            tokenEndpoint: _tokenUrl,
          ),
          scopes: _scopes,
        ),
      );

      if (result != null) {
        if (kDebugMode) {
          print(
              'GithubSignIn._signIn => Access token: ${result.accessToken}, expired at: ${result.accessTokenExpirationDateTime}');
        }

        contents.startLoading();
        try {
          final newGithubStorage = await Github.connect(
            accessToken: result.accessToken ?? 'UNAVAILABLE_TOKEN',
            accessTokenExpiryDate:
                result.accessTokenExpirationDateTime ?? DateTime.now(),
          );

          await storageProvider.saveProvider(
            newGithubStorage,
          );
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$e'),
              ),
            );
          }

          if (kDebugMode) {
            print('GithubSignIn._signIn => failed : $e');
          }
        } finally {
          contents.finishLoading();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error signing to github: $e');
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ContentModel>(builder: (context, contents, child) {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
        onPressed: () => _signIn(context),
        icon: contents.isLoading
            ? const BouncingDots()
            : const FaIcon(FontAwesomeIcons.github),
        label: const Text('Github'),
      );
    });
  }
}
