import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/ml_kit_ocr_service.dart';
// import '../../services/ocr_service.dart'; // Keeping for reference but unused
import '../../widgets/app_drawer.dart';
import '../../widgets/drawer_menu_icon.dart';
import '../leads/leads_section_page.dart';
import '../whatsapp_chat/whatsapp_chat_list_page.dart';

import '../../theme/app_colors.dart';
import 'dashboard_overview.dart';
import 'lead_preview_screen.dart';
import 'widgets/custom_crop_screen.dart';

class DashboardPage extends StatefulWidget {
  final String? token;
  final String? email;
  final String? name;
  final int initialIndex;

  const DashboardPage({
    super.key,
    this.token,
    this.email,
    this.name,
    this.initialIndex = 0,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late int _selectedIndex;
  late final PageController _pageController;
  final ImagePicker _picker = ImagePicker();
  bool _isOcrLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int idx) => setState(() => _selectedIndex = idx);

  void _onItemTapped(int idx) {
    setState(() => _selectedIndex = idx);
    _pageController.jumpToPage(idx);
  }

  Future<void> _pickAndScanCard() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.camera_alt, color: Theme.of(context).colorScheme.primary),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: Theme.of(context).colorScheme.primary),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 100,
      );

      if (image == null) return;

      // Use Custom Crop Screen (Flutter-based to avoid native overlapping)
      final Uint8List? croppedData = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CustomCropScreen(imageFile: File(image.path)),
        ),
      );

      if (croppedData == null) return;

      setState(() => _isOcrLoading = true);

      // Save cropped bytes to temp file for OCR service
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/cropped_image.png');
      await tempFile.writeAsBytes(croppedData);

      // USE ML KIT LOCALLY
      final result = await MLKitOCRService.processImage(tempFile.path);

      if (!mounted) return;
      setState(() => _isOcrLoading = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LeadPreviewScreen(
            parsedData: result['parsed'],
            rawText: result['rawText'],
            userName: widget.name,
            onSuccess: () {
              // Optionally refresh leads or show success
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isOcrLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final drawer = AppDrawer(email: widget.email, name: widget.name);

    return Scaffold(
      drawer: drawer,
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Tab 0: Dashboard
          Scaffold(
            drawer: drawer,
            appBar: AppBar(
              leading: const DrawerMenuIcon(),
              title: const Text('Dashboard'),
              centerTitle: true,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: AppColors.signatureGradient,
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
              foregroundColor: Colors.white,
            ),
            body: DashboardOverview(email: widget.email, name: widget.name),
          ),

          // Tab 1: Leads → screen with tabs Dashboard, Leads, Settings
          LeadsSectionPage(
            drawer: drawer,
            email: widget.email,
            name: widget.name,
          ),

          // Tab 2: Chat
          WhatsAppChatListPage(drawer: drawer),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: FloatingActionButton.extended(
                onPressed: _isOcrLoading ? null : _pickAndScanCard,
                backgroundColor: cs.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                elevation: 4,
                highlightElevation: 6,
                icon: _isOcrLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.onPrimary,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.document_scanner),
                label: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Text(_isOcrLoading ? 'Scanning...' : 'Scan Card'),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(
            top: BorderSide(
              color: AppColors.tintBorder.withOpacity(0.3),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: cs.onSurfaceVariant,
          type: BottomNavigationBarType.fixed,
          backgroundColor: cs.surface,
          elevation: 0,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people_alt),
              label: 'Leads',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Chat',
            ),
          ],
        ),
      ),
    );
  }
}
