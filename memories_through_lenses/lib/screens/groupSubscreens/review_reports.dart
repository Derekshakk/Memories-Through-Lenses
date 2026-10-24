import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memories_through_lenses/services/database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:memories_through_lenses/providers/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:memories_through_lenses/theme/app_colors.dart';

class ReviewReportsScreen extends StatefulWidget {
  const ReviewReportsScreen({super.key});

  @override
  State<ReviewReportsScreen> createState() => _ReviewReportsScreenState();
}

class _ReviewReportsScreenState extends State<ReviewReportsScreen> {
  List<Map<String, dynamic>> reports = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadReports();
  }

  Future<void> loadReports() async {
    setState(() {
      isLoading = true;
    });

    try {
      final fetchedReports = await Database().getReportsForMyGroups();
      if (mounted) {
        setState(() {
          reports = fetchedReports;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading reports: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  static bool _isComment(Map<String, dynamic> report) =>
      report['type'] == 'comment' && report['comment_id'] is String;

  Future<void> handleApprove(Map<String, dynamic> report, int index) async {
    final String reportId = report['id'];
    final String postId = report['post_id'];
    final isComment = _isComment(report);
    try {
      if (isComment) {
        // Only the comment is removed; the post stays.
        await Database()
            .approveCommentReport(reportId, postId, report['comment_id']);
      } else {
        await Database().approveReport(reportId, postId);
      }
      if (mounted) {
        setState(() {
          reports.removeAt(index);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isComment
                  ? 'Report approved. Comment has been deleted.'
                  : 'Report approved. Post has been deleted.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error approving report: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> handleReject(Map<String, dynamic> report, int index) async {
    final String reportId = report['id'];
    try {
      await Database().rejectReport(reportId);

      // Refresh user data to update reported_posts list
      if (mounted) {
        final provider = Provider.of<UserProvider>(context, listen: false);
        await provider.loadUserData();

        setState(() {
          reports.removeAt(index);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isComment(report)
                    ? 'Report dismissed. The comment remains visible.'
                    : 'Report dismissed. The post remains visible in the feed.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error rejecting report: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDateTime(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 0,
        title: Text(
          'Review Reports',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : reports.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Reports to Review',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted(context, Colors.grey[700]!),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'All clear! No pending reports for your groups.',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: loadReports,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: reports.length,
                      itemBuilder: (context, index) {
                        final report = reports[index];
                        final postData = report['post_data'];
                        final isComment = _isComment(report);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.red[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.flag,
                                        color: Colors.red[700],
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Reported by ${report['reporter_name']}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.muted(context, Colors.grey[800]!),
                                            ),
                                          ),
                                          Text(
                                            _formatDateTime(
                                                report['created_at']),
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),
                                const Divider(height: 1),
                                const SizedBox(height: 16),

                                if (report['reason'] is String) ...[
                                  Text(
                                    'Reason: ${report['reason']}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red[700],
                                    ),
                                  ),
                                  if (report['details'] is String)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        report['details'],
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          color: AppColors.muted(
                                              context, Colors.grey[700]!),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 12),
                                ],

                                if (isComment) ...[
                                  Text(
                                    'Reported Comment',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.muted(
                                          context, Colors.grey[700]!),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.subtle(context),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border(
                                        left: BorderSide(
                                            color: Colors.red[300]!, width: 3),
                                      ),
                                    ),
                                    child: Text(
                                      (report['comment_data']?['description'] ??
                                              report['comment_text'] ??
                                              '')
                                          .toString(),
                                      style: GoogleFonts.poppins(fontSize: 14),
                                    ),
                                  ),
                                  if (report['comment_data'] == null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'This comment has already been deleted.',
                                        style: GoogleFonts.poppins(
                                            fontSize: 12, color: Colors.grey),
                                      ),
                                    ),
                                  const SizedBox(height: 16),
                                ],

                                // Post Preview
                                Text(
                                  isComment ? 'On Post' : 'Reported Post',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.muted(context, Colors.grey[700]!),
                                  ),
                                ),
                                const SizedBox(height: 8),

                                if (postData != null) ...[
                                  // Image
                                  if (postData['image_url'] != null)
                                    InkWell(
                                      onTap: () {
                                        // Show full-screen image
                                        showDialog(
                                          context: context,
                                          builder: (context) => Dialog(
                                            backgroundColor: Colors.black,
                                            child: Stack(
                                              children: [
                                                Center(
                                                  child: InteractiveViewer(
                                                    child: Image.network(
                                                      postData['image_url'],
                                                      fit: BoxFit.contain,
                                                    ),
                                                  ),
                                                ),
                                                Positioned(
                                                  top: 10,
                                                  right: 10,
                                                  child: IconButton(
                                                    icon: const Icon(
                                                      Icons.close,
                                                      color: Colors.white,
                                                      size: 30,
                                                    ),
                                                    onPressed: () {
                                                      Navigator.pop(context);
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          postData['image_url'],
                                          height: 200,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return Container(
                                              height: 200,
                                              color: Colors.grey[300],
                                              child: const Center(
                                                child: Icon(Icons.broken_image,
                                                    size: 50),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),

                                  const SizedBox(height: 12),

                                  // Caption
                                  if (postData['caption'] != null &&
                                      postData['caption'].toString().isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.subtle(context),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        postData['caption'],
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: AppColors.muted(context, Colors.grey[800]!),
                                        ),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ] else
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Post no longer available',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ),

                                const SizedBox(height: 16),

                                // Action Buttons
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          final confirmed =
                                              await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              title: Text(
                                                isComment
                                                    ? 'Delete Comment?'
                                                    : 'Delete Post?',
                                                style: GoogleFonts.poppins(
                                                    fontWeight:
                                                        FontWeight.w600),
                                              ),
                                              content: Text(
                                                isComment
                                                    ? 'This will permanently delete the reported comment and its replies. The post stays. This action cannot be undone.'
                                                    : 'This will permanently delete the reported post. This action cannot be undone.',
                                                style: GoogleFonts.poppins(),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, false),
                                                  child: Text(
                                                    'Cancel',
                                                    style: GoogleFonts.poppins(
                                                        color: Colors.grey),
                                                  ),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, true),
                                                  child: Text(
                                                    'Delete',
                                                    style: GoogleFonts.poppins(
                                                        color: Colors.red,
                                                        fontWeight:
                                                            FontWeight.w600),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirmed == true) {
                                            await handleApprove(report, index);
                                          }
                                        },
                                        icon:
                                            const Icon(Icons.delete, size: 18),
                                        label: Text(
                                          isComment
                                              ? 'Delete Comment'
                                              : 'Delete Post',
                                          style:
                                              GoogleFonts.poppins(fontSize: 14),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          await handleReject(report, index);
                                        },
                                        icon: const Icon(Icons.check, size: 18),
                                        label: Text(
                                          isComment
                                              ? 'Keep Comment'
                                              : 'Keep Post',
                                          style:
                                              GoogleFonts.poppins(fontSize: 14),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
