import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:memories_through_lenses/components/group_card.dart';
import 'package:memories_through_lenses/providers/user_provider.dart';
import 'package:provider/provider.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  List<GroupCard> groups = [
    GroupCard(name: 'Group 1', groupID: '1', type: GroupCardType.notification),
    GroupCard(name: 'Group 2', groupID: '2', type: GroupCardType.notification),
    GroupCard(
        name: 'Group Derek', groupID: '3', type: GroupCardType.notification),
    GroupCard(name: 'Group 4', groupID: '4', type: GroupCardType.notification),
    GroupCard(name: 'Group 5', groupID: '5', type: GroupCardType.notification),
  ];

  void getGroupRequests(UserProvider provider) {
    groups.clear(); // Clear the existing groups
    // Fetch group requests from the user data in provider
    print("TESTING: ${provider.userData?['group_invites']}");
    if (provider.userData?['group_invites'] == null ||
        provider.userData!['group_invites'].isEmpty) {
      return;
    }
    provider.userData!['group_invites'].forEach((key, value) {
      groups.add(GroupCard(
          name: value, groupID: key, type: GroupCardType.notification));
    });
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    final provider = Provider.of<UserProvider>(context, listen: false);
    getGroupRequests(provider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 0,
        title: Text(
          'Manage Groups',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Actions Section
                Text(
                  'Quick Actions',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),

                // Action Cards
                _buildActionCard(
                  context,
                  icon: Icons.add_circle_outline,
                  title: 'Create Group',
                  description: 'Start a new group with your friends',
                  color: Colors.blue,
                  onTap: () => Navigator.pushNamed(context, '/create_group'),
                ),
                const SizedBox(height: 12),

                _buildActionCard(
                  context,
                  icon: Icons.group_add,
                  title: 'Join Group',
                  description: 'Find and join existing groups',
                  color: Colors.green,
                  onTap: () => Navigator.pushNamed(context, '/join_group'),
                ),
                const SizedBox(height: 12),

                _buildActionCard(
                  context,
                  icon: Icons.edit,
                  title: 'Edit Group',
                  description: 'Manage your existing groups',
                  color: Colors.orange,
                  onTap: () => Navigator.pushNamed(context, '/edit_group'),
                ),

                const SizedBox(height: 32),

                // Group Invites Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Group Invites',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    if (groups.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${groups.length}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[300]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  height: SizeConfig.blockSizeVertical! * 40,
                  child: groups.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.mail_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No Group Invites',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'You have no pending group invitations',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: groups.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            return groups[index];
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
