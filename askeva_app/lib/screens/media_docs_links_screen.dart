import 'package:flutter/material.dart';
import '../api/dto.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class MediaDocsLinksScreen extends StatefulWidget {
  final String name;
  final List<MessageDto> messages;

  const MediaDocsLinksScreen({
    super.key,
    required this.name,
    required this.messages,
  });

  @override
  State<MediaDocsLinksScreen> createState() => _MediaDocsLinksScreenState();
}

class _MediaDocsLinksScreenState extends State<MediaDocsLinksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Filter actual docs and links from conversation messages
    final docs = widget.messages.where((m) => m.type.contains('document') || m.type.contains('file')).toList();
    final links = widget.messages.where((m) => m.text.contains('http://') || m.text.contains('https://')).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E7036),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Media, links and docs',
              style: AppText.poppins(size: 17.5, weight: FontWeight.w800, color: Colors.white),
            ),
            const SizedBox(height: 2),
            Text(
              widget.name,
              style: AppText.poppins(size: 13, weight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _tabButton(0, 'Media'),
                _tabButton(1, 'Docs'),
                _tabButton(2, 'Links'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _mediaGrid(),
                _docsList(docs),
                _linksList(links),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(int index, String label) {
    final isSelected = _tabController.index == index;
    return GestureDetector(
      onTap: () => _tabController.animateTo(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEBF6ED) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: AppText.poppins(
            size: 14.5,
            weight: FontWeight.w700,
            color: isSelected ? const Color(0xFF1E7036) : const Color(0xFF757575),
          ),
        ),
      ),
    );
  }

  Widget _mediaGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: const Color(0xFFB1C4B6)),
              CustomPaint(painter: StripePainter()),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(color: Color(0x1F000000), blurRadius: 4, offset: Offset(0, 2))
                    ],
                  ),
                  child: Text(
                    'IMG ${index + 1}',
                    style: AppText.poppins(size: 11, weight: FontWeight.w800, color: AppColors.ink3),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _docsList(List<MessageDto> docs) {
    if (docs.isEmpty) {
      return Center(
        child: Text(
          'No documents shared yet',
          style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink3),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final doc = docs[index];
        return ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFEBF6ED),
            child: Icon(Icons.description_rounded, color: Color(0xFF1E7036)),
          ),
          title: Text(
            doc.text.isEmpty ? 'Document.pdf' : doc.text,
            style: AppText.poppins(size: 14.5, weight: FontWeight.w600, color: AppColors.ink),
          ),
          subtitle: Text(
            'PDF · 1.2 MB',
            style: AppText.poppins(size: 12, color: AppColors.ink3),
          ),
        );
      },
    );
  }

  Widget _linksList(List<MessageDto> links) {
    if (links.isEmpty) {
      return Center(
        child: Text(
          'No links shared yet',
          style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink3),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: links.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final link = links[index];
        return ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFEBF6ED),
            child: Icon(Icons.link_rounded, color: Color(0xFF1E7036)),
          ),
          title: Text(
            link.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.poppins(size: 14, weight: FontWeight.w600, color: const Color(0xFF0077E6)),
          ),
          subtitle: Text(
            'Link',
            style: AppText.poppins(size: 12, color: AppColors.ink3),
          ),
        );
      },
    );
  }
}

class StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC0D5C5)
      ..strokeWidth = 10;
    for (double i = -size.height; i < size.width; i += 24) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
