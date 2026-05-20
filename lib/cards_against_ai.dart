import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:rich_stdout/rich_stdout.dart';

final terminal = Terminal();

class WhiteCard {
  final String body;

  WhiteCard(this.body);

  @override
  String toString() {
    return body;
  }
}

class BlackCard {
  int numberOfRequiredCards = 0;
  final String content;

  BlackCard(this.content) {
    int pnt = 0;
    while (pnt < content.length - 1) {
      if (content.substring(pnt, pnt + 2) == '{}') {
        numberOfRequiredCards++;
      }

      pnt++;
    }
  }

  @override
  String toString() {
    return renderWithBlanks();
  }

  String renderWithWhite(List<WhiteCard> whiteCards) {
    if (whiteCards.length != numberOfRequiredCards) {
      return '[Invalid number of white cards]';
    }

    String rendered = content;

    for (var card in whiteCards) {
      rendered = rendered.replaceFirst('{}', card.body);
    }

    return rendered;
  }

  String renderWithBlanks() {
    return renderWithWhite(
        List.generate(numberOfRequiredCards, (_) => WhiteCard('_____')));
  }
}

class ClientWrapper {
  final int minimumPlayers = 3;
  final int maximumPlayers = 20;
  final WebSocket socket;
  final String id;
  final Server manager;
  String name = '';
  List<String> winnings = [];
  List<WhiteCard> hand = [];
  List<WhiteCard> selected = [];
  String pickedBest = '';
  bool isReader = false;

  ClientWrapper(this.socket, this.id, this.manager) {
    logSuccess('Connected');

    socket.listen((data) {
      logInfo('Received', data: jsonDecode(data));
      handleIncoming(data);
    }, onDone: () {
      logWarn('Disconnected');
      removeSelf();
    }, onError: (socketError) {
      logError('Socket Error: $socketError');
      removeSelf();
    });
  }

  void handleIncoming(dynamic data) {
    final String rawString =
        data is String ? data : utf8.decode(data as List<int>);
    Map? jsonData;

    try {
      jsonData = jsonDecode(rawString);
    } catch (_) {
      logError('Sent non-JSON data');
      return;
    }
    if (jsonData is! Map) {
      logError('Sent an unexpected format');
      return;
    }

    if (!jsonData.containsKey('request') || !jsonData.containsKey('id')) {
      logError('Sent json without id and/or request params');
      return;
    }

    if (jsonData['id'] != id) {
      logError('Sent data with without their id');
      return;
    }

    if (!manager.clients.containsKey(jsonData['id'])) {
      logError('Sent an id "$id", is not a valid id');
      return;
    }

    requestSwitch(jsonData);
  }

  void requestSwitch(Map jsonData) {
    switch (jsonData['request']) {
      case 'join-game':
        if (manager.clients.length > maximumPlayers) {
          sendToClient('join-game', HttpStatus.badRequest,
              message: "Too many player to be able to join");
          return;
        }

        if (!jsonData.containsKey('name')) {
          sendToClient('join-game', HttpStatus.badRequest,
              message: 'Please provide a name');
          break;
        }

        name = jsonData['name'].toString().toLowerCase();

        for (var client in manager.clients.values) {
          if (client.name == name && client.id != id) {
            sendToClient('join-game', HttpStatus.badRequest,
                message: 'Name "$name" already taken');
            return;
          }
        }

        name = name;

        sendToClient('join-game', HttpStatus.ok);
        sendToAll('joined-game', HttpStatus.ok, data: {'name': name});
        break;

      case 'start-game':
        if (manager.clients.length < minimumPlayers) {
          sendToClient('start-game', HttpStatus.badRequest,
              message: "Too few player to start");
          return;
        }

        if (manager.clients.length > maximumPlayers) {
          sendToClient('start-game', HttpStatus.badRequest,
              message: "Too many player to start");
          return;
        }

        if (manager.isGameInMotion) {
          logError('Attempted to start game when already in motion');
          return;
        }

        manager.beginGame();
        break;

      case 'submit-cards':
        if (isReader) {
          sendToClient('submit-cards', HttpStatus.badRequest,
              message: 'The card reader cannot submit white cards.');
          return;
        }

        if (selected.isNotEmpty) {
          sendToClient('submit-cards', HttpStatus.badRequest,
              message: 'You have already submitted cards for this round.');
          return;
        }

        if (jsonData['selected-cards'] is! List) {
          sendToClient('submit-cards', HttpStatus.badRequest,
              message: 'Invalid cards format.');
          return;
        }

        if ((jsonData['selected-cards'] as List).length !=
            manager.currentCardTarget) {
          sendToClient('submit-cards', HttpStatus.badRequest,
              message:
                  'Incorrect number of cards, only submit ${manager.currentCardTarget} card(s)');
          return;
        }

        final submittedCardBodies = (jsonData['selected-cards'] as List)
            .map((e) => e.toString())
            .toList();

        for (var body in submittedCardBodies) {
          bool hasCard = hand.any((card) => card.body == body);
          if (!hasCard) {
            sendToClient('submit-cards', HttpStatus.badRequest,
                message:
                    'You tried to play a card ("$body") that is not in your hand.');
            return;
          }
        }

        for (var body in submittedCardBodies) {
          final matchingCard = hand.firstWhere((card) => card.body == body);
          hand.remove(matchingCard);
          selected.add(matchingCard);
        }

        logSuccess('Submitted cards successfully: $submittedCardBodies');
        sendToClient('submit-cards', HttpStatus.ok,
            message: 'Cards submitted!');

        sendToAll('player-submitted', HttpStatus.ok, data: {'name': name});
        break;

      case 'pick-winner':
        if (!isReader) {
          sendToClient('pick-winner', HttpStatus.badRequest,
              message: 'Only the card reader can pick the winning card.');
          return;
        }

        if (!jsonData.containsKey('winning-card')) {
          sendToClient('pick-winner', HttpStatus.badRequest,
              message: 'Missing "winning-card" parameter.');
          return;
        }

        final chosenCardString = jsonData['winning-card'].toString();

        pickedBest = chosenCardString;

        logSuccess('Reader picked the winning card: "$chosenCardString"');
        sendToClient('pick-winner', HttpStatus.ok, message: 'Winner selected!');
        break;

      default:
        logWarn('Sent unknown request "${jsonData['request']}"');
        break;
    }
  }

  void sendToClient(String request, int statusCode,
      {String message = '', Map data = const {}}) {
    manager.sendToSpecific(
        id,
        jsonEncode({
          'request': request,
          'status-code': statusCode,
          'message': message,
          ...data
        }));
  }

  void sendToAll(String request, int statusCode,
      {String message = '', Map data = const {}}) {
    manager.broadcast(jsonEncode({
      'request': request,
      'status-code': statusCode,
      'message': message,
      ...data
    }));
  }

  void removeSelf() {
    if (isReader) {
      manager.endGame('Reader left');
    }
    manager.clients.remove(id);
    manager.numberOfPlayersToSubmit--;
  }

  void logSuccess(String message, {dynamic data}) {
    terminal.success(
        '[Client ${id.substring(0, 5)}...${id.substring(id.length - 5)}] $message');
    if (data != null) {
      terminal.success(':', newLine: false);
      terminal.table(data);
      terminal.print('');
    }
  }

  void logInfo(String message, {dynamic data}) {
    terminal.info(
        '[Client ${id.substring(0, 5)}...${id.substring(id.length - 5)}] $message');
    if (data != null) {
      terminal.info(':', newLine: false);
      terminal.table(data);
      terminal.print('');
    }
  }

  void logWarn(String message, {dynamic data}) {
    terminal.warning(
        '[Client ${id.substring(0, 5)}...${id.substring(id.length - 5)}] $message');
    if (data != null) {
      terminal.warning(':', newLine: false);
      terminal.table(data);
      terminal.print('');
    }
  }

  void logError(String message, {dynamic data}) {
    terminal.error(
        '[Client ${id.substring(0, 5)}...${id.substring(id.length - 5)}] $message');
    if (data != null) {
      terminal.error(':', newLine: false);
      terminal.table(data);
      terminal.print('');
    }
  }
}

class Server {
  static const String letters =
      'AEIOUBCDFGHJKLMNPQRSTVXZWYaeioubcdfghjklmnpqrstvxzwy0123456789';

  final Map<String, ClientWrapper> clients = {};
  late HttpServer server;
  List<WhiteCard> whiteCards = [];
  List<BlackCard> blackCards = [];
  bool isGameInMotion = false;
  int currentCardTarget = 100;
  int numberOfPlayersToSubmit = 0;

  void start(bool ansi) async {
    server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);

    terminal
      ..print(
          '================================================================')
      ..print(
          ' Server running. Open http://localhost:8080 in your web browser ')
      ..print(
          '================================================================')
      ..print('');

    server.listen((HttpRequest request) {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        () async {
          final socket = await WebSocketTransformer.upgrade(request);
          addClient(socket);
        }();
      } else {
        () async {
          String path =
              request.uri.path == '/' ? '/index.html' : request.uri.path;
          File file = File('web$path');

          if (file.path == 'web/reset') {
            logInfo('Restarting game');
            endGame('restarting game...');
          }

          logInfo('Request for ${file.path}');

          if (await file.exists()) {
            if (path.endsWith('.html')) {
              request.response.headers.contentType = ContentType.html;
            } else if (path.endsWith('.css')) {
              request.response.headers.contentType = ContentType('text', 'css');
            } else if (path.endsWith('.js')) {
              request.response.headers.contentType =
                  ContentType('application', 'javascript');
            }

            await request.response.addStream(file.openRead());
            await request.response.close();
            logSuccess('Sent file ${file.path}');
          } else {
            logError('${file.path} does not exist');
            request.response.statusCode = HttpStatus.notFound;
            request.response.close();
          }
        }();
      }
    });
  }

  void addClient(WebSocket socket) {
    final id = getRandomId();
    clients[id] = ClientWrapper(socket, id, this);
    clients[id]!.sendToClient('connection-established', HttpStatus.ok,
        data: {'assigned-id': id});
  }

  String getRandomId() {
    final random = Random();
    return List.generate(64, (_) {
      return Server.letters[random.nextInt(Server.letters.length)];
    }).join('');
  }

  bool broadcast(String message) {
    for (var client in clients.values) {
      client.socket.add(message);
    }
    logInfo('Broadcasted message', data: jsonDecode(message));

    return true;
  }

  void sendToAll(String request, int statusCode,
      {String message = '', Map data = const {}}) {
    broadcast(jsonEncode({
      'request': request,
      'status-code': statusCode,
      'message': message,
      ...data
    }));
  }

  bool sendToSpecific(String id, String message) {
    final client = clients[id];
    if (client != null) {
      client.socket.add(message);
      logInfo('Sent', data: jsonDecode(message));
      return true;
    } else {
      logError('Does not exist');
      return false;
    }
  }

  Map getPublicClientData() {
    Map data = {};

    data['players'] = [];

    for (var client in clients.values) {
      data['players']
          .add({'name': client.name, 'won-cards': client.winnings.length});
    }

    return data;
  }

  void beginGame() async {
    if (isGameInMotion) {
      return;
    }

    isGameInMotion = true;

    sendToAll('start-game', HttpStatus.ok,
        message: 'Starting game', data: getPublicClientData());

    logInfo('Loading white cards');
    whiteCards = getWhiteCards();
    logSuccess('Loaded white cards');

    logInfo('Loading black cards');
    blackCards = getBlackCards();
    logSuccess('Loaded black cards');

    if (whiteCards.length < clients.length * 5) {
      endGame('Too few white to start cards');
    }

    whiteCards.shuffle();
    blackCards.shuffle();

    List<String> order = clients.keys.toList();
    order.shuffle();
    int currentIndex = 0;
    String currentReader = order[currentIndex];

    for (var blackCard in blackCards) {
      currentCardTarget = blackCard.numberOfRequiredCards;

      currentIndex = (currentIndex + 1) % order.length;
      currentReader = order[currentIndex];

      for (var client in clients.values) {
        client.isReader = false;
        client.selected = [];
        client.pickedBest = '';

        while (client.hand.length < 5) {
          client.hand.add(whiteCards.removeLast());
        }

        if (client.id == currentReader) {
          client.isReader = true;
          client.sendToClient('round-start-reader', HttpStatus.ok,
              data: {'black-card': blackCard.renderWithBlanks()});
          continue;
        }

        client.sendToClient('set-hand', HttpStatus.ok, data: {
          'cards': jsonEncode(client.hand.map((card) => card.body).toList())
        });

        client.sendToClient('round-start', HttpStatus.ok, data: {
          'black-card': blackCard.renderWithBlanks(),
          'hand': client.hand.map((card) => card.body).toList()
        });
      }

      numberOfPlayersToSubmit = clients.length - 1;

      while (clients.values
              .where((client) => client.id != currentReader)
              .where((client) => client.selected.isNotEmpty)
              .length <
          numberOfPlayersToSubmit) {
        await Future.delayed(Duration(milliseconds: 100));
      }

      Map<String, String> cardAnsToClient = {};
      List<Map<String, dynamic>> structuredOptions = [];

      for (var client in clients.values) {
        if (client.id == currentReader) {
          continue;
        }

        String renderedText = blackCard.renderWithWhite(client.selected);
        cardAnsToClient[renderedText] = client.id;

        structuredOptions.add({
          'key': renderedText,
          'cards': client.selected.map((card) => card.body).toList()
        });
      }

      sendToAll('round-midway', HttpStatus.ok,
          message: 'Time for ${clients[currentReader]!.name} to read',
          data: {'options': structuredOptions});

      while (true) {
        clients[currentReader]!.sendToClient('read-out', HttpStatus.ok,
            data: {'options': structuredOptions});

        while (clients[currentReader]!.pickedBest.isEmpty) {
          await Future.delayed(Duration(milliseconds: 100));
        }

        if (!cardAnsToClient.containsKey(clients[currentReader]!.pickedBest)) {
          clients[currentReader]!.sendToClient('redraw', HttpStatus.badRequest,
              message: 'Invalid option');
          continue;
        }

        break;
      }

      var winner = clients[cardAnsToClient[clients[currentReader]!.pickedBest]];
      winner!.winnings.add(blackCard.renderWithWhite(winner.selected));

      sendToAll('round-end', HttpStatus.ok,
          message: '${clients[currentReader]!.name} has picked ${winner.name}',
          data: getPublicClientData());
    }

    var sortedClients = clients.values.toList();
    sortedClients
        .sort((a, b) => b.winnings.length.compareTo(a.winnings.length));

    sendToAll('game-end', HttpStatus.ok, message: 'End of game', data: {
      'leader-board': sortedClients
          .map((client) => {
                'name': client.name,
                'amount-of-winnings': client.winnings.length
              })
          .toList(),
    });

    endGame('');
  }

  List<WhiteCard> getWhiteCards() {
    final file = File('assets/white_cards.txt');

    final rows = file.readAsLinesSync();

    return rows
        .map((row) => WhiteCard(row))
        .where((card) => card.body != '')
        .toList();
  }

  List<BlackCard> getBlackCards() {
    final file = File('assets/black_cards.txt');

    final rows = file.readAsLinesSync();

    return rows
        .map((row) => BlackCard(row))
        .where(((card) => card.numberOfRequiredCards > 0))
        .toList();
  }

  void endGame(String message) {
    sendToAll('end-of-game', HttpStatus.internalServerError, message: message);
    for (var client in clients.values) {
      client.removeSelf();
    }
    isGameInMotion = false;
  }

  void logSuccess(String message, {dynamic data}) {
    terminal.success('[Server] $message');
    if (data != null) {
      terminal.success(':', newLine: false);
      terminal.table(data);
      terminal.print('');
    }
  }

  void logInfo(String message, {dynamic data}) {
    terminal.info('[Server] $message');
    if (data != null) {
      terminal.info(':', newLine: false);
      terminal.table(data);
      terminal.print('');
    }
  }

  void logWarn(String message, {dynamic data}) {
    terminal.warning('[Server] $message');
    if (data != null) {
      terminal.warning(':', newLine: false);
      terminal.table(data);
      terminal.print('');
    }
  }

  void logError(String message, {dynamic data}) {
    terminal.error('[Server] $message');
    if (data != null) {
      terminal.error(':', newLine: false);
      terminal.table(data);
      terminal.print('');
    }
  }
}
