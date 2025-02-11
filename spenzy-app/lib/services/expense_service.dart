import 'package:grpc/grpc.dart';
import 'package:spenzy_app/generated/proto/expense/expense.pbgrpc.dart' as expense;
import 'service_auth.dart';

class ExpenseService {
  static final ExpenseService _instance = ExpenseService._internal();
  factory ExpenseService() => _instance;

  ExpenseService._internal() {
    _channel = ClientChannel(
      ServiceAuth.grpcHost,
      port: ServiceAuth.expenseServicePort,
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
      ),
    );
    _client = expense.ExpenseServiceClient(_channel);
  }

  late final ClientChannel _channel;
  late final expense.ExpenseServiceClient _client;
  final _serviceAuth = ServiceAuth();

  Future<void> dispose() async {
    await _channel.shutdown();
  }

  Future<List<expense.Expense>> listExpenses({
    int page = 1,
    int pageSize = 20,
    String? sortBy,
    bool ascending = true,
    Map<String, String>? filters,
  }) async {
    try {
      final token = await _serviceAuth.getServiceToken('spenzy-expense.service');
      if (token == null) throw Exception('Not authenticated');

      final request = expense.ListExpensesRequest()
        ..page = page
        ..pageSize = pageSize;
      
      if (sortBy != null) {
        request.sortBy = sortBy;
        request.ascending = ascending;
      }

      if (filters != null) {
        request.filters.addAll(filters);
      }

      final response = await _client.listExpenses(
        request,
        options: CallOptions(metadata: {
          'authorization': 'Bearer $token',
        }),
      );
      return response.expenses;
    } catch (e) {
      throw Exception('Failed to list expenses: $e');
    }
  }

  Future<expense.Expense> createExpense(expense.CreateExpenseRequest request) async {
    try {
      final token = await _serviceAuth.getServiceToken('spenzy-expense.service');
      if (token == null) throw Exception('Not authenticated');

      final response = await _client.createExpense(
        request,
        options: CallOptions(metadata: {
          'authorization': 'Bearer $token',
        }),
      );
      return response.expense;
    } catch (e) {
      throw Exception('Failed to create expense: $e');
    }
  }

  Future<expense.ExpenseResponse> updateExpense(expense.UpdateExpenseRequest request) async {
    try {
      final token = await _serviceAuth.getServiceToken('spenzy-expense.service');
      if (token == null) throw Exception('Not authenticated');

      final response = await _client.updateExpense(
        request,
        options: CallOptions(metadata: {
          'authorization': 'Bearer $token',
        }),
      );
      return response;
    } catch (e) {
      throw Exception('Failed to update expense: $e');
    }
  }

  Future<void> deleteExpense(int id) async {
    try {
      final token = await _serviceAuth.getServiceToken('spenzy-expense.service');
      if (token == null) throw Exception('Not authenticated');

      final request = expense.DeleteExpenseRequest()
        ..id = id;

      await _client.deleteExpense(
        request,
        options: CallOptions(metadata: {
          'authorization': 'Bearer $token',
        }),
      );
    } catch (e) {
      throw Exception('Failed to delete expense: $e');
    }
  }

  Future<expense.Expense> getExpense(int id) async {
    try {
      final token = await _serviceAuth.getServiceToken('spenzy-expense.service');
      if (token == null) throw Exception('Not authenticated');

      final request = expense.GetExpenseRequest()
        ..id = id;

      final response = await _client.getExpense(
        request,
        options: CallOptions(metadata: {
          'authorization': 'Bearer $token',
        }),
      );
      return response.expense;
    } catch (e) {
      throw Exception('Failed to get expense: $e');
    }
  }
} 