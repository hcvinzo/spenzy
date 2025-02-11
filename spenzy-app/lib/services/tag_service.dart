import 'package:grpc/grpc.dart';
import 'package:spenzy_app/generated/proto/expense/expense.pbgrpc.dart' as expense_pb;
import 'service_auth.dart';

class TagService {
  static final TagService _instance = TagService._internal();
  factory TagService() => _instance;

  TagService._internal() {
    _channel = ClientChannel(
      ServiceAuth.grpcHost,
      port: ServiceAuth.expenseServicePort,
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
      ),
    );
    _client = expense_pb.TagServiceClient(_channel);
  }

  late final ClientChannel _channel;
  late final expense_pb.TagServiceClient _client;
  final _serviceAuth = ServiceAuth();

  Future<void> dispose() async {
    await _channel.shutdown();
  }

  Future<List<expense_pb.Tag>> listTags({String? query}) async {
    try {
      final token = await _serviceAuth.getServiceToken('spenzy-expense.service');
      if (token == null) throw Exception('Not authenticated');

      final request = expense_pb.ListTagsRequest();
      if (query != null) {
        request.query = query;
      }

      final response = await _client.listTags(
        request,
        options: CallOptions(metadata: {
          'authorization': 'Bearer $token',
        }),
      );

      if (!response.success) {
        throw Exception(response.errorMessage);
      }

      return response.tags;
    } catch (e) {
      throw Exception('Failed to list tags: $e');
    }
  }

  Future<expense_pb.Tag> createTag(String name) async {
    try {
      final token = await _serviceAuth.getServiceToken('spenzy-expense.service');
      if (token == null) throw Exception('Not authenticated');

      final request = expense_pb.CreateTagRequest()
        ..name = name;

      final response = await _client.createTag(
        request,
        options: CallOptions(metadata: {
          'authorization': 'Bearer $token',
        }),
      );

      if (!response.success) {
        throw Exception(response.errorMessage);
      }

      return response.tag;
    } catch (e) {
      throw Exception('Failed to create tag: $e');
    }
  }

  Future<void> deleteTag(int tagId) async {
    try {
      final token = await _serviceAuth.getServiceToken('spenzy-expense.service');
      if (token == null) throw Exception('Not authenticated');

      final request = expense_pb.DeleteTagRequest()
        ..tagId = tagId;

      final response = await _client.deleteTag(
        request,
        options: CallOptions(metadata: {
          'authorization': 'Bearer $token',
        }),
      );

      if (!response.success) {
        throw Exception(response.errorMessage);
      }
    } catch (e) {
      throw Exception('Failed to delete tag: $e');
    }
  }
} 