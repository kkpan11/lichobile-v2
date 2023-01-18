import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:logging/logging.dart';

import 'package:lichess_mobile/src/constants.dart';
import 'package:lichess_mobile/src/common/models.dart';
import 'package:lichess_mobile/src/common/http.dart';
import 'package:lichess_mobile/src/features/game/data/game_repository.dart';
import 'package:lichess_mobile/src/features/game/data/game_event.dart';
import 'package:lichess_mobile/src/features/game/data/api_event.dart';
import '../../../utils.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockLogger extends Mock implements Logger {}

const gameIdTest = GameId('5IrD6Gzz');

void main() {
  final mockLogger = MockLogger();
  final mockApiClient = MockApiClient();
  final repo = GameRepository(mockLogger, apiClient: mockApiClient);

  setUpAll(() {
    reset(mockApiClient);
  });

  group('GameRepository.getUserGamesTask', () {
    test('json read, full example', () async {
      const response = '''
{"id":"rfBxF2P5","rated":false,"variant":"standard","speed":"blitz","perf":"blitz","createdAt":1672074461465,"lastMoveAt":1672074683485,"status":"mate","players":{"white":{"user":{"name":"testUser","patron":true,"id":"testUser"},"rating":1178},"black":{"user":{"name":"maia1","title":"BOT","id":"maia1"},"rating":1397}},"winner":"white","moves":"e4 e5 Nf3 d6 Bc4 Nf6 Nc3 Nc6 O-O Be7 d3 O-O Nh4 Bg4 Qd2 Nd4 Nf5 Bxf5 exf5 Nxf5 Nd5 Nxd5 Bxd5 c6 Be4 Nd4 c3 Ne6 d4 exd4 cxd4 d5 Bc2 Bg5 Qd3 Bxc1 Qxh7#","clock":{"initial":300,"increment":3,"totalTime":420}}
{"id":"msAKIkqp","rated":false,"variant":"standard","speed":"blitz","perf":"blitz","createdAt":1671791341158,"lastMoveAt":1671791589063,"status":"resign","players":{"white":{"user":{"name":"maia1","title":"BOT","id":"maia1"},"rating":1399},"black":{"user":{"name":"testUser","patron":true,"id":"testUser"},"rating":1178}},"winner":"white","moves":"e4 e5 Nf3 Nc6 Bb5 Nf6 Bxc6 dxc6 Nxe5 Qd4 Nf3 Qxe4+ Qe2 Bc5 Qxe4+ Nxe4 O-O O-O d3 Nf6 Bg5 Nh5 Nc3 Bg4 Ne5 f5 Nd7 Rf7 Nxc5 Raf8 Nxb7 f4 f3 Bc8 Nc5 Rf5 N5e4 Nf6 Bxf6 gxf6 Rae1","clock":{"initial":300,"increment":3,"totalTime":420}}
{"id":"7Jxi9mBF","rated":false,"variant":"standard","speed":"blitz","perf":"blitz","createdAt":1671100908073,"lastMoveAt":1671101322211,"status":"mate","players":{"white":{"user":{"name":"testUser","patron":true,"id":"testUser"},"rating":1178},"black":{"user":{"name":"maia1","title":"BOT","id":"maia1"},"rating":1410}},"winner":"white","moves":"e4 e5 Nf3 Nc6 Nc3 Nf6 Bb5 d6 O-O Bd7 Bxc6 Bxc6 d4 exd4 Nxd4 Bxe4 Nxe4 Nxe4 Re1 d5 f3 Bc5 fxe4 dxe4 Rxe4+ Be7 Bg5 f6 Bf4 O-O Ne6 Qxd1+ Rxd1 Rfe8 Bxc7 Rac8 c4 Bc5+ Kh1 b6 Bd6 Bxd6 Rxd6 f5 Rf4 g6 g3 Kf7 Ng5+ Kg7 Rd7+ Kh6 h4 Re1+ Kg2 Re2+ Kf3 Rxb2 Rxh7#","clock":{"initial":300,"increment":3,"totalTime":420}}
''';

      when(() => mockApiClient.get(
            Uri.parse('$kLichessHost/api/games/user/testUser?max=10'),
            headers: {'Accept': 'application/x-ndjson'},
          )).thenReturn(TaskEither.right(http.Response(response, 200)));

      final result = await repo.getUserGamesTask('testUser').run();

      expect(result.isRight(), true);
    });
  });

  group('GameRepository.events', () {
    test('can read all supported types of events', () async {
      when(() =>
              mockApiClient.stream(Uri.parse('$kLichessHost/api/stream/event')))
          .thenAnswer((_) => mockHttpStreamFromIterable([
                '''
{
  "type": "gameStart",
  "game": {
    "gameId": "rCRw1AuO",
    "fullId": "rCRw1AuOvonq",
    "color": "black",
    "fen": "r1bqkbnr/pppp2pp/2n1pp2/8/8/3PP3/PPPB1PPP/RN1QKBNR w KQkq - 2 4",
    "hasMoved": true,
    "isMyTurn": false,
    "lastMove": "b8c6",
    "opponent": {
      "id": "philippe",
      "rating": 1790,
      "username": "Philippe"
    },
    "perf": "correspondence",
    "rated": false,
    "secondsLeft": 1209600,
    "source": "friend",
    "speed": "correspondence",
    "variant": {
      "key": "standard",
      "name": "Standard"
    },
    "compat": {
      "bot": false,
      "board": true
    }
  }
}
'''
              ]));

      expect(
          repo.events(),
          emitsInOrder([
            predicate((value) => value is GameStartEvent),
          ]));
    });

    test('filter out unsupported types of events', () async {
      when(() =>
              mockApiClient.stream(Uri.parse('$kLichessHost/api/stream/event')))
          .thenAnswer((_) => mockHttpStreamFromIterable([
                '{ "type": "challenge", "challenge": {}}',
              ]));

      expect(repo.events(), emitsInOrder([emitsDone]));
    });
  });

  group('GameRepository.gameStateEvents', () {
    test('can read all supported types of events', () async {
      when(() => mockApiClient.stream(
              Uri.parse('$kLichessHost/api/board/game/stream/$gameIdTest')))
          .thenAnswer((_) => mockHttpStreamFromIterable([
                '{ "type": "gameFull", "id": "$gameIdTest", "initialFen": "startPos", "state": { "type": "gameState", "moves": "e2e4 c7c5 f2f4 d7d6 g1f3", "wtime": 7598040, "btime": 8395220, "status": "started" }}',
                '{ "type": "gameState", "moves": "e2e4 c7c5 f2f4 d7d6 g1f3 b8c6", "wtime": 7598140, "btime": 8395220, "status": "started" }',
                '{ "type": "gameState", "moves": "e2e4 c7c5 f2f4 d7d6 g1f3 b8c6 f1c4", "wtime": 7598140, "btime": 8398220, "status": "started" }',
              ]));

      expect(
          repo.gameStateEvents(gameIdTest),
          emitsInOrder([
            predicate((value) => value is GameFullEvent),
            predicate((value) => value is GameStateEvent),
            predicate((value) => value is GameStateEvent),
          ]));
    });

    test('filter out unsupported types of events', () async {
      when(() => mockApiClient.stream(
              Uri.parse('$kLichessHost/api/board/game/stream/$gameIdTest')))
          .thenAnswer((_) => mockHttpStreamFromIterable([
                '{ "type": "gameState", "moves": "e2e4 c7c5 f2f4 d7d6 g1f3 b8c6", "wtime": 7598140, "btime": 8395220, "status": "started" }',
                '{ "type": "chatLine", "username": "testUser", "message": "oops" }',
              ]));

      expect(
          repo.gameStateEvents(gameIdTest),
          emitsInOrder([
            predicate((value) => value is GameStateEvent),
          ]));
    });
  });

  group('GameRepository.getGame', () {
    test('minimal example game', () async {
      const testResponse = '''
{
  "id": "5IrD6Gzz",
  "rated": true,
  "variant": "standard",
  "speed": "blitz",
  "perf": "blitz",
  "createdAt": 1514505150384,
  "lastMoveAt": 1514505592843,
  "status": "draw",
  "players": {
    "white": {
      "user": {
        "name": "Lance5500",
        "title": "LM",
        "patron": true,
        "id": "lance5500"
      },
      "rating": 2389,
      "ratingDiff": 4
    },
    "black": {
      "user": {
        "name": "TryingHard87",
        "id": "tryinghard87"
      },
      "rating": 2498,
      "ratingDiff": -4
    }
  },
  "opening": {
    "eco": "D31",
    "name": "Semi-Slav Defense: Marshall Gambit",
    "ply": 7
  },
  "moves": "d4 d5 c4 c6 Nc3 e6 e4 Nd7 exd5 cxd5 cxd5 exd5 Nxd5 Nb6 Bb5+ Bd7 Qe2+ Ne7 Nxb6 Qxb6 Bxd7+ Kxd7 Nf3 Qa6 Ne5+ Ke8 Qf3 f6 Nd3 Qc6 Qe2 Kf7 O-O Kg8 Bd2 Re8 Rac1 Nf5 Be3 Qe6 Rfe1 g6 b3 Bd6 Qd2 Kf7 Bf4 Qd7 Bxd6 Nxd6 Nc5 Rxe1+ Rxe1 Qc6 f3 Re8 Rxe8 Nxe8 Kf2 Nc7 Qb4 b6 Qc4+ Nd5 Nd3 Qe6 Nb4 Ne7 Qxe6+ Kxe6 Ke3 Kd6 g3 h6 Kd3 h5 Nc2 Kd5 a3 Nc6 Ne3+ Kd6 h4 Nd8 g4 Ne6 Ke4 Ng7 Nc4+ Ke6 d5+ Kd7 a4 g5 gxh5 Nxh5 hxg5 fxg5 Kf5 Nf4 Ne3 Nh3 Kg4 Ng1 Nc4 Kc7 Nd2 Kd6 Kxg5 Kxd5 f4 Nh3+ Kg4 Nf2+ Kf3 Nd3 Ke3 Nc5 Kf3 Ke6 Ke3 Kf5 Kd4 Ne6+ Kc4",
  "clock": {
    "initial": 300,
    "increment": 3,
    "totalTime": 420
  }
}
''';

      when(() => mockApiClient
              .get(Uri.parse('$kLichessHost/game/export/$gameIdTest')))
          .thenReturn(TaskEither.right(http.Response(testResponse, 200)));

      final result = await repo.getGameTask(gameIdTest).run();

      expect(result.isRight(), true);
    });

    test('game with analysis', () async {
      const testResponse = '''
{"id":"NchH5KBj","rated":true,"variant":"standard","speed":"blitz","perf":"blitz","createdAt":1647115605598,"lastMoveAt":1647116025236,"status":"resign","players":{"white":{"user":{"name":"matyizom","id":"matyizom"},"rating":1224,"ratingDiff":10,"analysis":{"inaccuracy":3,"mistake":2,"blunder":0,"acpl":60}},"black":{"user":{"name":"veloce","patron":true,"id":"veloce"},"rating":1147,"ratingDiff":-8,"analysis":{"inaccuracy":3,"mistake":1,"blunder":1,"acpl":105}}},"winner":"white","opening":{"eco":"B01","name":"Scandinavian Defense: Main Line, Mieses Variation","ply":8},"moves":"e4 d5 exd5 Qxd5 Nc3 Qa5 d4 Nf6 Nf3 c5 a3 e6 Bg5 Be7 Bb5+ Bd7 Bxd7+ Nbxd7 O-O O-O Ne5 cxd4 Nxd7 Nxd7 Bxe7 Rfe8 Bb4 Qf5 Qxd4 e5 Qe3 Qxc2 Ne4 Qxb2 Ng5 f6 Qh3 h6 Nf3 a5 Qxd7 Red8 Qxb7 axb4 Qxb4 Qxa3 Rxa3","analysis":[{"eval":28},{"eval":82,"best":"e7e5","variation":"e5 Nf3 Nc6 Bb5 Nf6 d3 Bc5 c3 O-O O-O"},{"eval":66},{"eval":80},{"eval":71},{"eval":63},{"eval":75},{"eval":60},{"eval":80},{"eval":136,"best":"g7g6","variation":"g6 Bc4 Bg7 O-O O-O Bd2 c5 Nd5 Qd8 Nxf6+"},{"eval":53,"best":"d4d5","variation":"d5 g6 Bc4 Bg7 O-O a6 Bd2 Qd8 a4 Nbd7","judgment":{"name":"Inaccuracy","comment":"Inaccuracy. d5 was best."}},{"eval":63},{"eval":-16,"best":"c1f4","variation":"Bf4 Nc6 Bb5 cxd4 Nxd4 Bd7 Nxc6 Bxc6 Bxc6+ bxc6","judgment":{"name":"Inaccuracy","comment":"Inaccuracy. Bf4 was best."}},{"eval":131,"best":"f6e4","variation":"Ne4","judgment":{"name":"Mistake","comment":"Mistake. Ne4 was best."}},{"eval":-10,"best":"d4c5","variation":"dxc5","judgment":{"name":"Mistake","comment":"Mistake. dxc5 was best."}},{"eval":-27},{"eval":-20},{"eval":-31},{"eval":-57},{"eval":20,"best":"c5d4","variation":"cxd4 Qxd4","judgment":{"name":"Inaccuracy","comment":"Inaccuracy. cxd4 was best."}},{"eval":-138,"best":"d4d5","variation":"d5 exd5 Nxd5 Bd8 Ne3 Qa6 Re1 Re8 Qd2 Ne5 Nxe5 Rxe5 Bxf6 Bxf6","judgment":{"name":"Mistake","comment":"Mistake. d5 was best."}},{"eval":-91},{"eval":-107},{"eval":538,"best":"a5g5","variation":"Qxg5 Qxd4","judgment":{"name":"Blunder","comment":"Blunder. Qxg5 was best."}},{"eval":506},{"eval":515},{"eval":515},{"eval":745,"best":"a5b6","variation":"Qb6 Ne4","judgment":{"name":"Inaccuracy","comment":"Inaccuracy. Qb6 was best."}},{"eval":739},{"eval":792},{"eval":753},{"eval":800},{"eval":745},{"eval":858},{"eval":575,"best":"a1d1","variation":"Rad1 Qd4","judgment":{"name":"Inaccuracy","comment":"Inaccuracy. Rad1 was best."}},{"eval":730},{"eval":685},{"eval":737},{"eval":621},{"eval":645},{"eval":578},{"eval":977,"best":"a5b4","variation":"axb4 axb4 Qxa1 Qxe8+ Rxe8 Rxa1 Rc8 Kf1 Rc4 Rb1 Kf7 Nd2 Rd4 Ke2","judgment":{"name":"Inaccuracy","comment":"Inaccuracy. axb4 was best."}},{"eval":700},{"eval":716},{"eval":730},{"eval":1054},{"eval":1014}],"clock":{"initial":180,"increment":2,"totalTime":260}}
''';

      const gameId = GameId('NchH5KBj');

      when(() =>
              mockApiClient.get(Uri.parse('$kLichessHost/game/export/$gameId')))
          .thenReturn(TaskEither.right(http.Response(testResponse, 200)));

      final result = await repo.getGameTask(gameId).run();

      expect(result.isRight(), true);
    });
  });
}
