import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hums_mobile/core/network/api_client.dart';
import 'package:hums_mobile/core/network/api_endpoints.dart';
import 'package:hums_mobile/core/observability/telemetry_service.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient mockApiClient;
  late TelemetryService telemetryService;

  setUp(() {
    mockApiClient = MockApiClient();
    telemetryService = TelemetryService(mockApiClient);

    when(() => mockApiClient.post(any(), data: any(named: 'data')))
        .thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: ApiEndpoints.telemetryEvents),
              statusCode: 200,
            ));
  });

  tearDown(() {
    telemetryService.dispose();
  });

  test('recordPlaybackEvent queues event and flushes on error', () async {
    telemetryService.recordPlaybackEvent(
      eventType: 'playback_error',
      trackType: 'track',
      errorCategory: 'source_unavailable',
      httpStatus: 409,
    );

    // Give microtask queue time to run flush
    await Future.delayed(Duration.zero);

    verify(() => mockApiClient.post(
          ApiEndpoints.telemetryEvents,
          data: any(named: 'data'),
        )).called(1);
  });

  test('recordClientError sanitizes and flushes immediately', () async {
    final longMessage = 'A' * 300;
    telemetryService.recordClientError(
      errorType: 'UI_RENDER_EXCEPTION',
      errorMessage: longMessage,
      screen: '/profile',
    );

    await Future.delayed(Duration.zero);

    verify(() => mockApiClient.post(
          ApiEndpoints.telemetryEvents,
          data: any(named: 'data'),
        )).called(1);
  });

  test('flush fails open gracefully without throwing exception when API fails', () async {
    when(() => mockApiClient.post(any(), data: any(named: 'data')))
        .thenThrow(DioException(requestOptions: RequestOptions(path: '/telemetry')));

    telemetryService.recordClientError(
      errorType: 'NETWORK_ERROR',
      errorMessage: 'Network timeout',
    );

    // Must not throw an unhandled exception
    await expectLater(telemetryService.flush(), completes);
  });
}
