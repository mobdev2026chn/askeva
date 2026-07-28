import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/app_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/dashboard_sheets.dart' show appToast;
import '../widgets/common.dart';
import '../shell/app_nav.dart';
import 'package:video_player/video_player.dart';

class VideoNotesScreen extends StatefulWidget {
  const VideoNotesScreen({super.key});

  @override
  State<VideoNotesScreen> createState() => _VideoNotesScreenState();
}

class _VideoNotesScreenState extends State<VideoNotesScreen> {
  bool _loading = false;
  List<Map<String, dynamic>> _videoNotes = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _snack(String msg, {bool err = false}) {
    appToast(context, msg);
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final repo = AppScope.of(context).ticketing;
      final data = await repo.fetchVideoNotes();
      if (mounted) {
        setState(() {
          _videoNotes = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack('Failed to load video notes: $e', err: true);
      }
    }
  }

  Future<void> _deleteNote(Map<String, dynamic> note) async {
    final id = note['id'] ?? note['_id'] ?? '';
    final title = note['title'] ?? 'Video Note';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Video Note', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
        content: Text('Are you sure you want to delete "$title"?', style: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: AppColors.ink2)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Cancel', style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink3))),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final repo = AppScope.of(context).ticketing;
      await repo.deleteVideoNote(id);
      _snack('Video note deleted successfully');
      _loadData();
    } catch (e) {
      _snack('Failed to delete video note: $e', err: true);
    }
  }

  Future<void> _playVideo(String url) async {
    if (url.isEmpty) {
      _snack('Video URL is empty', err: true);
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _snack('Invalid video URL', err: true);
      return;
    }
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _snack('Could not launch video URL', err: true);
      }
    } catch (e) {
      _snack('Failed to play video: $e', err: true);
    }
  }

  void _showFormSheet([Map<String, dynamic>? note]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _VideoNoteFormSheet(
        note: note,
        onSaved: _loadData,
      ),
    );
  }

  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;
      
      int hour = dt.hour;
      final min = dt.minute.toString().padLeft(2, '0');
      final ampm = hour >= 12 ? 'PM' : 'AM';
      hour = hour % 12;
      if (hour == 0) hour = 12;
      
      return '$day/$month/$year $hour:$min $ampm';
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final nav = AppNav.maybeOf(context);
    final totalNotes = _videoNotes.length;

    return Scaffold(
      backgroundColor: AppColors.surface2,
      body: GreenHeaderScaffold(
        title: 'Ticketing',
        onMenu: nav?.openDrawer,
        headerChild: GreenSegmented(
          items: const ['Dashboard', 'Tickets', 'Settings'],
          selected: 2, // Settings
          onChanged: (i) {
            if (i != 2) {
              Navigator.of(context).pop(i);
            }
          },
        ),
        sheet: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.evaGreen))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button row
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                            color: AppColors.evaGreen,
                            borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_back_ios_new_rounded,
                                size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Text('Back',
                                style: AppText.poppins(
                                    size: 13,
                                    weight: FontWeight.w700,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Screen Title
                    Text('Video Note Configuration',
                        style: AppText.poppins(
                            size: 20,
                            weight: FontWeight.w800,
                            color: AppColors.ink)),
                    const SizedBox(height: 14),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.line),
                        boxShadow: AppColors.shadowSm,
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // Card Header Row with title and count badge
                        Row(children: [
                          Expanded(
                            child: Text('Video Note Configuration', style: AppText.poppins(size: 15, weight: FontWeight.w800, color: AppColors.ink)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFE8F2FF), borderRadius: BorderRadius.circular(6)),
                            child: Text(
                              '$totalNotes video notes',
                              style: AppText.poppins(size: 11, weight: FontWeight.w700, color: const Color(0xFF1E3A8A)),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 16),

                        // Add Video Note green button
                        SizedBox(
                          height: 38,
                          child: ElevatedButton.icon(
                            onPressed: () => _showFormSheet(),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Add Video Note'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.evaGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Divider(height: 1, color: AppColors.line),
                        const SizedBox(height: 16),

                        // List of video notes
                        if (totalNotes == 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Center(child: Text('No video notes configured.', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink4))),
                          )
                        else
                          ..._videoNotes.map((note) {
                            final title = note['title']?.toString() ?? 'Video Note';
                            final desc = note['description']?.toString() ?? '';
                            final videoUrl = note['videoUrl']?.toString() ?? '';
                            final createdStr = _formatDate(note['createdAt']?.toString() ?? note['created_at']?.toString() ?? '');

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                border: Border(bottom: BorderSide(color: AppColors.line)),
                              ),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                // Text contents
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(
                                      title,
                                      style: AppText.poppins(
                                        size: 14,
                                        weight: FontWeight.w800,
                                        color: const Color(0xFF1E88E5), // bold blue title
                                      ),
                                    ),
                                    if (desc.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        desc,
                                        style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3, height: 1.3),
                                      ),
                                    ],
                                    if (createdStr.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        createdStr,
                                        style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink4),
                                      ),
                                    ],
                                  ]),
                                ),
                                const SizedBox(width: 8),

                                // Play button (green icon in thin border box)
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppColors.line),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () => _playVideo(videoUrl),
                                    icon: const Icon(Icons.play_circle_outline_rounded, size: 20, color: AppColors.evaGreenDeep),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Edit button
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.line),
                                  ),
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () => _showFormSheet(note),
                                    icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.ink3),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Delete button
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFFEE2E2)),
                                  ),
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () => _deleteNote(note),
                                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.danger),
                                  ),
                                ),
                              ]),
                            );
                          }),
                      ]),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _VideoNoteFormSheet extends StatefulWidget {
  final Map<String, dynamic>? note;
  final VoidCallback onSaved;
  const _VideoNoteFormSheet({super.key, this.note, required this.onSaved});

  @override
  State<_VideoNoteFormSheet> createState() => _VideoNoteFormSheetState();
}

class _VideoNoteFormSheetState extends State<_VideoNoteFormSheet> {
  late TextEditingController titleCtrl;
  late TextEditingController descCtrl;
  String videoUrl = '';
  String pickedFileName = '';
  bool uploading = false;
  bool saving = false;

  VideoPlayerController? _videoController;
  bool _isPlayerInitialized = false;
  bool _isLoadingVideo = false;

  @override
  void initState() {
    super.initState();
    titleCtrl = TextEditingController(text: widget.note?['title']?.toString() ?? '');
    descCtrl = TextEditingController(text: widget.note?['description']?.toString() ?? '');
    videoUrl = widget.note?['videoUrl']?.toString() ?? '';
    pickedFileName = videoUrl.isNotEmpty ? 'Uploaded Video' : '';
  }

  void _initAndPlayVideo() async {
    if (videoUrl.isEmpty) return;
    setState(() {
      _isLoadingVideo = true;
    });

    try {
      final oldController = _videoController;
      if (oldController != null) {
        await oldController.dispose();
      }

      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      _videoController = controller;
      await controller.initialize();
      if (mounted) {
        setState(() {
          _isPlayerInitialized = true;
          _isLoadingVideo = false;
        });
        _videoController!.play();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingVideo = false;
        });
      }
      debugPrint('Error initializing video: $e');
      _snack('Failed to load video preview', err: true);
    }
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool err = false}) {
    appToast(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              Text(
                widget.note == null ? 'Add New Video Note' : 'Edit Video Note',
                style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 16),

              // Title Input
              RichText(text: TextSpan(children: [
                TextSpan(text: 'Title', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2)),
                TextSpan(text: ' *', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.danger)),
              ])),
              const SizedBox(height: 6),
              Container(
                height: 40,
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.line)),
                child: TextField(
                  controller: titleCtrl,
                  style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Enter video note title',
                    hintStyle: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink4),
                    prefixIcon: const Icon(Icons.local_offer_outlined, size: 16, color: AppColors.ink4),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Description Input
              Text('Description', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      maxLength: 500,
                      style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Enter description (optional)',
                        hintStyle: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink4),
                        contentPadding: EdgeInsets.zero,
                        counterText: '',
                        border: InputBorder.none,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${descCtrl.text.length}/500',
                      style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Video Upload Selection
              RichText(text: TextSpan(children: [
                TextSpan(text: 'Upload Video', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2)),
                TextSpan(text: ' *', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.danger)),
              ])),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: uploading ? null : () async {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.video,
                    allowMultiple: false,
                  );
                  if (result == null || result.files.isEmpty) return;

                  final file = result.files.first;
                  if (file.size > 100 * 1024 * 1024) {
                    _snack('Video size must be less than 100MB', err: true);
                    return;
                  }

                  final bytes = file.bytes;
                  final path = file.path;
                  if (bytes == null && path == null) {
                    _snack('Unable to read selected file', err: true);
                    return;
                  }

                  setState(() => uploading = true);
                  try {
                    final repo = AppScope.of(context).ticketing;
                    late List<int> fileBytes;
                    if (bytes != null) {
                      fileBytes = bytes;
                    } else {
                      final ioFile = io.File(path!);
                      fileBytes = await ioFile.readAsBytes();
                    }

                    final res = await repo.client.uploadFile(
                      '/filehandler/upload/chat',
                      field: 'file',
                      bytes: fileBytes,
                      filename: file.name,
                    );

                    final uploadedUrl = res['fileUrl'] ?? res['url'] ?? '';
                    if (uploadedUrl.isNotEmpty) {
                      setState(() {
                        videoUrl = uploadedUrl;
                        pickedFileName = file.name;
                        _isPlayerInitialized = false;
                        _isLoadingVideo = false;
                      });
                      _snack('Video uploaded successfully');
                    } else {
                      _snack('Failed to parse uploaded video URL', err: true);
                    }
                  } catch (e) {
                    _snack('Upload failed: $e', err: true);
                  } finally {
                    setState(() => uploading = false);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (uploading)
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink2))
                    else
                      const Icon(Icons.cloud_upload_outlined, size: 18, color: AppColors.ink2),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pickedFileName.isNotEmpty ? pickedFileName : 'Click to Upload Video',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink2),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Supported formats: MP4, MOV, AVI, WMV, FLV, WebM, MKV (Max 100MB)',
                style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink4),
              ),

              if (videoUrl.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.videocam_outlined, size: 16, color: AppColors.evaGreenDeep),
                    const SizedBox(width: 6),
                    Text('Current Video', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink)),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Video Preview', style: AppText.poppins(size: 12, weight: FontWeight.w800, color: AppColors.ink)),
                      const SizedBox(height: 4),
                      Text(
                        'Video URL: $videoUrl',
                        style: AppText.poppins(size: 11, weight: FontWeight.w500, color: AppColors.ink3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AspectRatio(
                          aspectRatio: _isPlayerInitialized ? _videoController!.value.aspectRatio : 16 / 9,
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              _isPlayerInitialized
                                  ? VideoPlayer(_videoController!)
                                  : _isLoadingVideo
                                      ? Container(
                                          color: Colors.black12,
                                          child: const Center(child: CircularProgressIndicator(color: AppColors.evaGreen)),
                                        )
                                      : Container(
                                          color: Colors.black12,
                                          child: Center(
                                            child: IconButton(
                                              iconSize: 42,
                                              icon: const Icon(Icons.play_circle_fill_rounded, color: AppColors.evaGreenDeep),
                                              onPressed: _initAndPlayVideo,
                                            ),
                                          ),
                                        ),
                              if (_isPlayerInitialized) ...[
                                Center(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (_videoController!.value.isPlaying) {
                                          _videoController!.pause();
                                        } else {
                                          _videoController!.play();
                                        }
                                      });
                                    },
                                    child: Container(
                                      decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                                      padding: const EdgeInsets.all(10),
                                      child: Icon(
                                        _videoController!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                ),
                                VideoProgressIndicator(
                                  _videoController!,
                                  allowScrubbing: true,
                                  colors: const VideoProgressColors(
                                    playedColor: AppColors.evaGreen,
                                    bufferedColor: Colors.white24,
                                    backgroundColor: Colors.black12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Actions Footer Row (Cancel & OK)
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ink2,
                      side: const BorderSide(color: AppColors.line),
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Cancel', style: AppText.poppins(size: 13.5, weight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: (saving || uploading) ? null : () async {
                        final title = titleCtrl.text.trim();
                        final desc = descCtrl.text.trim();

                        if (title.isEmpty) {
                          _snack('Title is required', err: true);
                          return;
                        }
                        if (videoUrl.isEmpty) {
                          _snack('Video upload is required', err: true);
                          return;
                        }

                        final payload = {
                          'title': title,
                          'description': desc,
                          'videoUrl': videoUrl,
                        };

                        setState(() => saving = true);
                        try {
                          final repo = AppScope.of(context).ticketing;
                          if (widget.note == null) {
                            await repo.createVideoNote(payload);
                            _snack('Video note created successfully');
                          } else {
                            final id = widget.note!['id'] ?? widget.note!['_id'] ?? '';
                            await repo.updateVideoNote(id, payload);
                            _snack('Video note updated successfully');
                          }
                          if (context.mounted) Navigator.of(context).pop();
                          widget.onSaved();
                        } catch (e) {
                          _snack('Failed to save video note: $e', err: true);
                          setState(() => saving = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.evaGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: saving
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('OK', style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
