import 'package:fk_user_agent/fk_user_agent.dart';
import 'package:live_sensors/logger/logger.dart';
import 'package:live_sensors/session_storage/session_storage.dart';
import 'package:live_sensors/utils/state.dart';
import 'entities/session.dart';
import 'http_client/errors.dart';
import 'http_client/open_id_api.dart';
import 'http_client/open_id_client.dart';
import 'entities/tokens.dart';
import 'sensors/sensors.dart';
import 'entities/user.dart';
import 'api/api_client.dart';
import 'geolocator/geolocator.dart';
import 'geolocator/base_flow_geolocator.dart';
import 'queue/queue.dart';
import 'storage/storage.dart';

import 'sender.dart';
import 'tracker.dart';

class LoginFailedException implements Exception {
  final String? message;
  const LoginFailedException([this.message]);
}

// TODO Inject auti in api? or api in auth? How to refresh token
class AppControllerState {
  // Enabled tracking or not
  bool isTracking = false;
  // Application ready for work or not
  bool isBooted = false;
  // User authorized or not
  bool isAuthorized = false;
}

class AppController extends SimpleState<AppControllerState> {
  final Logger logger = Logger();
  /* Store snapshots on hard drive */
  final Storage storage = Storage();
  final GeoLocator geoLocator;
  final Sensors sensors;

  late ApiClient api;
  late OpenIdClient openIdClient;

  final SnapshotsQueue queue;
  /* Listen sensors and position, and creates new snapshots in queue */
  final Tracker tracker;

  /* Sends snapshots from queue */
  final Sender sender;

  AppController()
      : sensors = Sensors(),
        geoLocator = BaseFlowGeolocator(),
        queue = SnapshotsQueue(),
        tracker = Tracker(),
        sender = Sender();

  @override
  initState() {
    return AppControllerState();
  }

  // Create common application structure
  init() async {
    await logger.init();
    SessionStorage sessionStorage = SessionStorage();
    Session session = Session();

    openIdClient = OpenIdClient(
      OpenIdApi(
        refreshPath: Uri.parse(
          'https://keycloak01.kontur.io/realms/kontur/protocol/openid-connect/token',
        ),
      ),
      postLogin: (tokens) {
        _postLogin(tokens);
        session.tokens = tokens;
        sessionStorage.saveSession(session);
      },
      postRefresh: (tokens) {
        session.tokens = tokens;
        sessionStorage.saveSession(session);
      },
      postLogout: () {
        _postLogout();
        sessionStorage.dropSession();
      },
    );

    api = ApiClient(openIdClient);

    session = await sessionStorage.restoreLast();
    Tokens? lastTokens = session.tokens;
    if (lastTokens != null) {
      try {
        await openIdClient.loginByTokens(lastTokens);
      } catch (e) {
        logger.info('Tokens expired, re-logout ($e)');
      }
    }
    setState(() {
      state.isBooted = true;
    });
  }

  login(String login, String password) async {
    try {
      await openIdClient.loginByPassword(email: login, password: password);
    } on BadCredentialsException catch (e) {
      throw LoginFailedException(e.message);
    }
  }

  _postLogin(Tokens tokens) async {
    User user = User(id: tokens.sessionId);
    try {
      setState(() {
        state.isAuthorized = true;
      });
      await setup(user);
      start();
    } catch (e) {
      logger.error('Failed to start. Reason: ${e.toString()}');
    }
  }

  setup(User user) async {
    try {
      await geoLocator.requestPermissions();
      sender.setup(
        api: api,
        storage: storage,
        queue: queue,
      );

      await FkUserAgent.init();
      String userAgent = FkUserAgent.userAgent ?? 'Unknown';

      tracker.setup(
        user: user,
        userAgent: userAgent,
        queue: queue,
        sensors: sensors.stream,
        position: geoLocator.getPositionStream(),
      );
    } catch (e) {
      logger.error(e.toString());
    }
  }

  logout() {
    openIdClient.logout();
  }

  _postLogout() {
    stop();
    setState(() {
      state.isAuthorized = false;
    });
  }

  start() {
    tracker.track();
    sender.run();
    setState(() {
      state.isTracking = true;
    });
  }

  stop() {
    tracker.dispose();
    queue.clear();
    sender.stop();
    setState(() {
      state.isTracking = false;
    });
  }

  pause() {
    tracker.pause();
    setState(() {
      state.isTracking = false;
    });
  }

  resume() {
    tracker.resume();
    setState(() {
      state.isTracking = true;
    });
  }
}
