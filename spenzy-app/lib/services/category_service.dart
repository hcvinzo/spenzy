import 'package:grpc/grpc.dart';
import 'package:spenzy_app/generated/proto/expense/expense.pbgrpc.dart' as expense;
import 'service_auth.dart';

class CategoryService {
  static final CategoryService _instance = CategoryService._internal();
  factory CategoryService() => _instance;

  CategoryService._internal() {
    _channel = ClientChannel(
      ServiceAuth.grpcHost,
      port: ServiceAuth.expenseServicePort,
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
      ),
    );
    _client = expense.CategoryServiceClient(_channel);
  }

  late final ClientChannel _channel;
  late final expense.CategoryServiceClient _client;
  final _serviceAuth = ServiceAuth();

  Future<void> dispose() async {
    await _channel.shutdown();
  }

  Future<List<expense.Category>> listCategories() async {
    try {
      final token = await _serviceAuth.getServiceToken('spenzy-expense.service');
      if (token == null) throw Exception('Not authenticated');

      final request = expense.ListCategoriesRequest();

      final response = await _client.listCategories(
        request,
        options: CallOptions(metadata: {
          'authorization': 'Bearer $token',
        }),
      );
      return response.categories;
    } catch (e) {
      throw Exception('Failed to list categories: $e');
    }
  }

  Future<expense.Category> createCategory(expense.CreateCategoryRequest request) async {
    try {
      final token = await _serviceAuth.getServiceToken('spenzy-expense.service');
      if (token == null) throw Exception('Not authenticated');

      final response = await _client.createCategory(
        request,
        options: CallOptions(metadata: {
          'authorization': 'Bearer $token',
        }),
      );
      return response.category;
    } catch (e) {
      throw Exception('Failed to create category: $e');
    }
  }
} 