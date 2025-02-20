import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:spenzy_app/providers/loading_provider.dart';
import 'package:spenzy_app/screens/expense/expense_list_screen.dart';
import 'package:spenzy_app/screens/home/home_content_screen.dart';
import 'package:spenzy_app/screens/expense/add_expense_screen.dart';
import 'package:spenzy_app/utils/document_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:spenzy_app/widgets/loading_overlay.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late final DocumentPicker _documentPicker;

  static const List<Widget> _screens = [
    HomeContentScreen(),
    ExpenseListScreen(),
    Center(child: Text('Profile')),
  ];

  @override
  void initState() {
    super.initState();

    final loadingProvider =
        Provider.of<LoadingProvider>(context, listen: false);

    _documentPicker = DocumentPicker(
      onLoadingChanged: (loading) {
        // Handle loading state if needed
        if (loading) {
          loadingProvider.show();
        } else {
          loadingProvider.hide();
        }
      },
      onError: (error) {
        loadingProvider.hide();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error)),
          );
        }
      },
      onDocumentProcessed: (response, file) async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddExpenseScreen(documentResponse: response),
          ),
        );

        if (result == true) {
          // Refresh data if needed
        }
      },
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2c2c34),
      body: Stack(
        children: [
          _screens[_selectedIndex],
          const LoadingOverlay(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: const Color(0xFF1e2027),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) => Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit, color: Colors.white),
                    title: const Text('Add Manually',
                        style: TextStyle(color: Colors.white)),
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const AddExpenseScreen()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.upload_file, color: Colors.white),
                    title: const Text('Upload Document',
                        style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      _documentPicker.pickAndProcessFile();
                    },
                  ),
                  ListTile(
                    leading:
                        const Icon(Icons.photo_library, color: Colors.white),
                    title: const Text('Choose from Gallery',
                        style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      _documentPicker.pickAndProcessImage(ImageSource.gallery);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.camera_alt, color: Colors.white),
                    title: const Text('Take Photo',
                        style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      _documentPicker.pickAndProcessImage(ImageSource.camera);
                    },
                  ),
                ],
              ),
            ),
          );
        },
        backgroundColor: Colors.teal,
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFF1e2027),
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        height: 60,
        shadowColor: Colors.white,
        elevation: 10,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Icon(Icons.home,
                  color: _selectedIndex == 0 ? Colors.teal : Colors.white54),
              onPressed: () => _onItemTapped(0),
            ),
            IconButton(
              icon: Icon(Icons.receipt_long,
                  color: _selectedIndex == 1 ? Colors.teal : Colors.white54),
              onPressed: () => _onItemTapped(1),
            ),
            const SizedBox(width: 40), // Space for FAB
            IconButton(
              icon: Icon(Icons.person,
                  color: _selectedIndex == 2 ? Colors.teal : Colors.white54),
              onPressed: () => _onItemTapped(2),
            ),
          ],
        ),
      ),
    );
  }
}
