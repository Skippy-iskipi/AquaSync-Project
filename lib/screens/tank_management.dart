import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/tank_provider.dart';
import '../models/tank.dart';
import 'add_edit_tank.dart';
import '../widgets/fish_info_dialog.dart';
import '../widgets/auth_required_dialog.dart';
import '../services/auth_service.dart';
import 'auth_screen.dart';

class TankManagement extends StatefulWidget {
  const TankManagement({super.key});

  @override
  State<TankManagement> createState() => _TankManagementState();
}

class _TankManagementState extends State<TankManagement> {
  bool _showArchived = false; // Track if showing archived tanks

  @override
  void initState() {
    super.initState();
    // Load tanks when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TankProvider>(context, listen: false).loadTanks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TankProvider>(
      builder: (context, tankProvider, child) {
        // Load archived data if showing archived and data is empty
        if (_showArchived && tankProvider.archivedTanks.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            tankProvider.loadArchivedTanks();
          });
        }

        final tanks = _showArchived ? tankProvider.archivedTanks : tankProvider.tanks;
        
        return Scaffold(
          backgroundColor: Colors.white,
          body: Column(
            children: [
              // Archived toggle button
              Container(
                margin: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _showArchived = !_showArchived;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: _showArchived ? const Color(0xFF00BFB3).withOpacity(0.08) : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _showArchived ? const Color(0xFF00BFB3) : Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _showArchived ? Icons.archive : Icons.archive_outlined,
                                size: 18,
                                color: _showArchived ? const Color(0xFF00BFB3) : Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _showArchived ? 'Show Active Tanks' : 'Show Archived Tanks',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: _showArchived ? const Color(0xFF00BFB3) : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Tank list
              Expanded(
                child: tanks.isEmpty
                    ? _buildEmptyState()
                    : _buildTankList(tanks),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 8),
          Text(
            _showArchived ? 'No archived tanks' : 'No tanks created yet',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const Text(
            'Create your first tank to start managing\nyour aquarium setup',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF00BFB3),
                  const Color(0xFF4DD0E1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00BFB3).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTankList(List<Tank> tanks) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tanks.length,
      itemBuilder: (context, index) {
        final tank = tanks[index];
        return _buildTankCard(tank);
      },
    );
  }



  Widget _buildTankCard(Tank tank) {
    return _showArchived ? _buildArchivedTankCard(tank) : _buildActiveTankCard(tank);
  }

  Widget _buildActiveTankCard(Tank tank) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFF006064).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => _navigateToTankDetails(context, tank),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with tank name and quick stats
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
          tank.name,
                            style: TextStyle(
                              fontSize: MediaQuery.of(context).size.width < 400 ? 16 : 20,
            fontWeight: FontWeight.bold,
                              color: const Color(0xFF006064),
          ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
        ),
                          const SizedBox(height: 4),
            Text(
              _getTankShapeLabel(tank.tankShape),
                            style: TextStyle(
                              fontSize: MediaQuery.of(context).size.width < 400 ? 12 : 14,
                color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                            maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                        ],
                      ),
                    ),
                    // Quick action menu
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                      color: Color(0xFF006064),
                        size: 20,
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'view':
                            _navigateToTankDetails(context, tank);
                            break;
                          case 'edit':
                            _navigateToEditTank(context, tank);
                            break;
                          case 'archive':
                            _showArchiveDialog(context, tank);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'view',
                          child: Row(
                            children: [
                              Icon(Icons.visibility, size: 16, color: Color(0xFF006064)),
                              SizedBox(width: 8),
                              Text('View Details'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 16, color: Color(0xFF006064)),
                              SizedBox(width: 8),
                              Text('Edit Tank'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'archive',
                          child: Row(
                            children: [
                              Icon(Icons.archive, size: 16, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('Archive Tank'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Tank stats in a grid layout
              Row(
                children: [
                    // Volume
                  Expanded(
                      child: _buildStatCard(
                        icon: Icons.water_drop,
                        label: 'Volume',
                        value: '${tank.volume.toStringAsFixed(1)}L',
                        color: const Color(0xFF00BCD4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Feed info
                    Expanded(
                      child: _buildFeedStatCard(tank),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Fish species preview (if any)
                if (tank.fishSelections.isNotEmpty) ...[
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F7FA),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF006064).withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        Text(
                          'Fish Species',
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).size.width < 400 ? 11 : 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF006064),
                          ),
                        ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: tank.fishSelections.entries.take(3).map((entry) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFF006064).withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '${entry.value}x ${entry.key}',
                                  style: TextStyle(
                                    fontSize: MediaQuery.of(context).size.width < 400 ? 10 : 11,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF006064),
                                  ),
                                ),
                              );
                            }).toList()
                              ..addAll(tank.fishSelections.length > 3 ? [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF006064).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '+${tank.fishSelections.length - 3} more',
                                    style: TextStyle(
                                      fontSize: MediaQuery.of(context).size.width < 400 ? 10 : 11,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF006064),
                                    ),
                                  ),
                                ),
                              ] : []),
                          ),
                        ],
                      ),
                    ),
          ),
          const SizedBox(height: 12),
        ],
                // Action buttons: Edit Fish and Edit Feeds
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _navigateToEditTank(context, tank, initialStep: 1, lockedMode: true),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: const Color(0xFF006064).withOpacity(0.4)),
                          foregroundColor: const Color(0xFF006064),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        label: const Text('Edit Fish'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _navigateToEditTank(context, tank, initialStep: 2, lockedMode: true),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: const Color(0xFF006064).withOpacity(0.4)),
                          foregroundColor: const Color(0xFF006064),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        label: const Text('Edit Feeds'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.width < 400 ? 13 : 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.width < 400 ? 10 : 11,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildFeedStatCard(Tank tank) {
    if (tank.availableFeeds.isEmpty) {
      return _buildStatCard(
        icon: Icons.restaurant,
        label: 'No Feeds',
        value: '0g',
        color: Colors.grey,
      );
    }

    // Calculate total feed grams
    final totalGrams = tank.availableFeeds.values.fold(0.0, (sum, grams) => sum + grams);
    
    // Calculate average days remaining across all feeds
    double totalDays = 0;
    int feedCount = 0;
    
    for (final feedName in tank.availableFeeds.keys) {
      final daysLeft = tank.getDaysUntilFeedRunsOut(feedName);
      if (daysLeft != null && daysLeft > 0) {
        totalDays += daysLeft;
        feedCount++;
      }
    }
    
    final avgDaysRemaining = feedCount > 0 ? (totalDays / feedCount).round() : 0;

    return _buildStatCard(
      icon: Icons.restaurant,
      label: 'Feeds',
      value: '${totalGrams.toStringAsFixed(0)}g/${avgDaysRemaining}days',
      color: const Color(0xFF00BCD4),
    );
  }

  Widget _buildArchivedTankCard(Tank tank) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFF006064).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => _navigateToTankDetails(context, tank),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                tank.name,
                                style: TextStyle(
                                  fontSize: MediaQuery.of(context).size.width < 400 ? 16 : 20,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF006064),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00BCD4).withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.archive,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Archived',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getTankShapeLabel(tank.tankShape),
                            style: TextStyle(
                              fontSize: MediaQuery.of(context).size.width < 400 ? 12 : 14,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Restore button
                    IconButton(
                      onPressed: () async {
                        await Provider.of<TankProvider>(context, listen: false).restoreTank(tank.id!);
                      },
                      icon: const Icon(
                        Icons.restore,
                        color: Color(0xFF00BCD4),
                        size: 24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Volume and Feed info
                Row(
                  children: [
                    // Volume
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00BCD4).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF00BCD4).withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.water_drop,
                              size: 16,
                              color: const Color(0xFF00BCD4),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${tank.volume.toStringAsFixed(1)}L',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF00BCD4),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Volume',
                              style: TextStyle(
                                fontSize: 12,
                                color: const Color(0xFF00BCD4).withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Feeds
                    Expanded(
                      child: _buildFeedStatCard(tank),
                    ),
                  ],
                ),
                // Fish list
                if (tank.fishSelections.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00BCD4).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF00BCD4).withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fish Species',
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).size.width < 400 ? 11 : 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF00BCD4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: tank.fishSelections.entries.take(3).map((entry) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFF00BCD4).withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '${entry.value}x ${entry.key}',
                                style: TextStyle(
                                  fontSize: MediaQuery.of(context).size.width < 400 ? 10 : 11,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF00BCD4),
                                ),
                              ),
                            );
                          }).toList()
                            ..addAll(tank.fishSelections.length > 3 ? [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00BCD4).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '+${tank.fishSelections.length - 3} more',
                                  style: TextStyle(
                                    fontSize: MediaQuery.of(context).size.width < 400 ? 10 : 11,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF00BCD4),
                                  ),
                                ),
                              ),
                            ] : []),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToEditTank(BuildContext context, Tank tank, {int? initialStep, bool lockedMode = false}) {
    // Check if user is authenticated before allowing tank editing
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) {
      _showAuthRequiredDialog(context, 'Edit Tank', 'You need to be logged in to edit and save tanks.');
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditTank(tank: tank, initialStep: initialStep, lockedMode: lockedMode),
      ),
    );
  }

  void _navigateToTankDetails(BuildContext context, Tank tank) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TankDetailsScreen(tank: tank),
      ),
    );
  }

  void _showArchiveDialog(BuildContext context, Tank tank) {
    // Check if user is authenticated before allowing tank archiving
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) {
      _showAuthRequiredDialog(context, 'Archive Tank', 'You need to be logged in to archive tanks.');
      return;
    }
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        title: Row(
          children: const [
            Icon(Icons.archive_outlined, color: Colors.orange, size: 22),
            SizedBox(width: 8),
            Text('Archive Tank'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will move "${tank.name}" to Archived. You can restore it anytime from the Archived list.',
              style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.info_outline, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Archived tanks are hidden from your active list but not deleted.',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await context.read<TankProvider>().archiveTank(tank.id!);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error archiving tank: $e'),
                      backgroundColor: const Color.fromARGB(255, 255, 17, 0),
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.archive, size: 16),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            label: const Text('Archive'),
          ),
        ],
      ),
    );
  }

  String _getTankShapeLabel(String shape) {
    try {
      switch (shape.toLowerCase()) {
        case 'rectangle':
          return 'Rectangle/Square Tank';
        case 'bowl':
          return 'Bowl Tank (10L)';
        case 'cylinder':
          return 'Cylinder Tank';
        default:
          return 'Rectangle/Square Tank';
      }
    } catch (e) {
      print('Error getting tank shape label: $e');
      return 'Unknown Tank';
    }
  }

  void _showAuthRequiredDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AuthRequiredDialog(
        title: title,
        message: message,
        actionButtonText: 'Sign In to Continue',
        onActionPressed: () {
          // Navigate to auth screen
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AuthScreen(showBackButton: true),
            ),
          );
        },
      ),
    );
  }


}

// Tank Details Screen
class TankDetailsScreen extends StatefulWidget {
  final Tank tank;

  const TankDetailsScreen({super.key, required this.tank});

  @override
  State<TankDetailsScreen> createState() => _TankDetailsScreenState();
}

class _TankDetailsScreenState extends State<TankDetailsScreen> {
  Map<String, dynamic> _fishDetails = {};
  bool _isLoadingFishDetails = true;

  @override
  void initState() {
    super.initState();
    _loadFishDetails();
  }

  Tank get tank => widget.tank;

  // Load fish details from database
  Future<void> _loadFishDetails() async {
    if (tank.fishSelections.isEmpty) {
      setState(() {
        _isLoadingFishDetails = false;
      });
      return;
    }

    try {
      final Map<String, dynamic> fishDetails = {};
      
      for (final fishName in tank.fishSelections.keys) {
        final fishDetail = await _fetchFishDetailsFromDatabase(fishName);
        if (fishDetail != null) {
          fishDetails[fishName] = fishDetail;
        }
      }
      
      setState(() {
        _fishDetails = fishDetails;
        _isLoadingFishDetails = false;
      });
    } catch (e) {
      print('Error loading fish details: $e');
      setState(() {
        _isLoadingFishDetails = false;
      });
    }
  }

  // Fetch fish details from database (same as add_edit_tank.dart)
  Future<Map<String, dynamic>?> _fetchFishDetailsFromDatabase(String fishName) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('fish_species')
          .select('common_name, portion_grams, feeding_frequency, preferred_food, "max_size_(cm)", temperament, water_type')
          .eq('active', true)
          .ilike('common_name', fishName)
          .maybeSingle();

      if (response != null) {
        final portionGrams = double.tryParse(response['portion_grams']?.toString() ?? '0') ?? 0.0;
        final feedingFreq = int.tryParse(response['feeding_frequency']?.toString() ?? '2') ?? 2;
        final maxSize = double.tryParse(response['max_size_(cm)']?.toString() ?? '0') ?? 0.0;
        
        return {
          'common_name': response['common_name']?.toString() ?? fishName,
          'portion_grams': portionGrams > 0 ? portionGrams : null,
          'feeding_frequency': feedingFreq > 0 ? feedingFreq : null,
          'preferred_food': _getStringValue(response['preferred_food']),
          'max_size_cm': maxSize > 0 ? maxSize : null,
          'temperament': _getStringValue(response['temperament']),
          'water_type': _getStringValue(response['water_type']),
        };
      }
    } catch (e) {
      print('Error fetching fish details from database: $e');
    }
    
    return null;
  }

  String _getStringValue(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          tank.name,
          style: const TextStyle(
            color: Color(0xFF006064),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF006064)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Color(0xFF006064)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddEditTank(tank: tank),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tank Information Card
            _buildSummaryCard(
              title: 'Tank Information',
              icon: Icons.water_drop,
              children: [
                _buildSummaryRow('Tank Name', tank.name),
                _buildSummaryRow('Tank Shape', tank.tankShape.toUpperCase()),
                if (tank.tankShape == 'rectangle') ...[
                  _buildSummaryRow('Length', '${tank.length} ${tank.unit.toLowerCase()}'),
                  _buildSummaryRow('Width', '${tank.width} ${tank.unit.toLowerCase()}'),
                  _buildSummaryRow('Height', '${tank.height} ${tank.unit.toLowerCase()}'),
                ] else if (tank.tankShape == 'cylinder') ...[
                  _buildSummaryRow('Diameter', '${tank.length} ${tank.unit.toLowerCase()}'),
                  _buildSummaryRow('Height', '${tank.height} ${tank.unit.toLowerCase()}'),
                ],
                _buildSummaryRow('Volume', '${tank.volume.toStringAsFixed(2)} L (${(tank.volume * 0.264172).toStringAsFixed(2)} US gallons)'),
              ],
            ),

            const SizedBox(height: 16),
            
            // Fish Selection Card
            if (tank.fishSelections.isNotEmpty) ...[
              _buildSummaryCard(
                title: 'Fish Selection (${tank.fishSelections.length} species)',
                icon: FontAwesomeIcons.fish,
                children: [
                  if (_isLoadingFishDetails) ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                          color: Color(0xFF00BCD4),
                        ),
                      ),
                    ),
                  ] else ...[
                    ...tank.fishSelections.entries.map((entry) {
                      final fishName = entry.key;
                      final quantity = entry.value;
                      final fishDetail = _getFishDetail(fishName);
                      
                      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                            padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                              color: const Color(0xFF006064).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF006064).withOpacity(0.2)),
                            ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                  children: [
                    Text(
                                      '$fishName (x$quantity)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => _showFishInfo(context, fishName),
                                      child: const Icon(
                                        Icons.visibility,
                                        color: Color(0xFF00BCD4),
                                        size: 20,
                      ),
                    ),
                  ],
                ),
                                if (fishDetail != null) ...[
                                  const SizedBox(height: 8),
                                  if (fishDetail['feeding_frequency'] != null)
                                    _buildSummaryRow('Feeding frequency', '${fishDetail['feeding_frequency']} times/day'),
                                  if (fishDetail['preferred_food'] != null) 
                                    _buildSummaryRow('Preferred food', fishDetail['preferred_food']),
                                  if (fishDetail['portion_grams'] != null)
                                    _buildSummaryRow('Portion per feeding', '${fishDetail['portion_grams']}g'),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      );
                    }).toList(),
                  ],
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Feed Inventory Card
            if (tank.availableFeeds.isNotEmpty) ...[
              _buildSummaryCard(
                title: 'Feed Inventory (${tank.availableFeeds.length} types)',
                icon: Icons.restaurant,
                children: [
                  ...tank.availableFeeds.entries.map((entry) {
                    final feedName = entry.key;
                    final quantity = entry.value;
                    final daysLeft = tank.getDaysUntilFeedRunsOut(feedName);
                    final isLowStock = daysLeft != null && daysLeft <= 14;
                    final isCritical = daysLeft != null && daysLeft <= 7;
                    
    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
                        color: isCritical ? Colors.red.shade50 : 
                               isLowStock ? Colors.orange.shade50 : 
                               const Color(0xFF006064).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isCritical ? Colors.red.shade300 : 
                                 isLowStock ? Colors.orange.shade300 : 
                                 const Color(0xFF006064).withOpacity(0.2),
                        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
                              Icon(
                                Icons.restaurant,
                                color: isCritical ? Colors.red.shade700 : 
                                       isLowStock ? Colors.orange.shade700 : 
                                       const Color(0xFF006064),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                feedName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isCritical ? Colors.red.shade700 : 
                                         isLowStock ? Colors.orange.shade700 : 
                                         const Color(0xFF006064),
                                  fontSize: 16,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${quantity.toStringAsFixed(0)}g',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                                  color: isCritical ? Colors.red.shade700 : 
                                         isLowStock ? Colors.orange.shade700 : 
                                         const Color(0xFF006064),
                                  fontSize: 14,
                ),
              ),
            ],
          ),
                          if (daysLeft != null) ...[
                            const SizedBox(height: 8),
                            _buildSummaryRow('Daily consumption', '${_getDailyConsumption(feedName).toStringAsFixed(2)}g/day'),
                            _buildSummaryRow('Days remaining', '$daysLeft days'),
                            _buildSummaryRow('Status', isCritical ? 'Critical - Reorder soon!' : 
                                                  isLowStock ? 'Low stock - Consider reordering' : 
                                                  'Good stock'),
                            // Show consumption by fish
                            if (_getFishConsumption(feedName).isNotEmpty) ...[
                              const SizedBox(height: 4),
            const Text(
                                'Consumption by fish:',
              style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                  fontSize: 12,
                                ),
                              ),
                              ..._getFishConsumption(feedName).entries.map((fishEntry) {
              return Padding(
                                  padding: const EdgeInsets.only(left: 8, top: 2),
                child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                                      Flexible(
                      child: Text(
                                          '${fishEntry.key}:',
                                          style: const TextStyle(color: Color(0xFF006064), fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Flexible(
                      child: Text(
                                          '${fishEntry.value.toStringAsFixed(2)}g/day',
                                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: Color(0xFF006064)),
                                          textAlign: TextAlign.right,
                                          overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
                            ],
                          ] else ...[
                            const SizedBox(height: 8),
                            _buildSummaryRow('Status', 'No consumption data available'),
                          ],
        ],
      ),
    );
                  }).toList(),
            ],
          ),
          const SizedBox(height: 16),
            ],

            // Compatibility Analysis Card
            if (tank.fishSelections.length > 1) ...[
              _buildSummaryCard(
                title: 'Compatibility Analysis',
                icon: Icons.analytics,
                        children: [
                  _buildCompatibilityAnalysis(tank),
                ],
              ),
              const SizedBox(height: 16),
                ],
              ],
            ),
      ),
    );
  }



  // Helper methods for summary display
  Map<String, dynamic>? _getFishDetail(String fishName) {
    // Use the fetched fish details from database
    return _fishDetails[fishName];
  }


  void _showFishInfo(BuildContext context, String fishName) {
    showDialog(
      context: context,
      builder: (BuildContext context) => FishInfoDialog(fishName: fishName),
    );
  }



  double _getDailyConsumption(String feedName) {
    try {
      // Calculate daily consumption using fish details from database
      double totalDailyConsumption = 0.0;
      
      for (final fishEntry in tank.fishSelections.entries) {
        final fishName = fishEntry.key;
        final fishQuantity = fishEntry.value;
        final fishDetail = _fishDetails[fishName];
        
        if (fishDetail != null) {
          final portionGrams = fishDetail['portion_grams'] as double?;
          final feedingFrequency = fishDetail['feeding_frequency'] as int?;
          final preferredFood = fishDetail['preferred_food'] as String?;
          
          // Check if this fish eats this feed type
          if (portionGrams != null && feedingFrequency != null && preferredFood != null) {
            final isCompatibleFeed = _isFeedTypeCompatible(feedName.toLowerCase(), preferredFood.toLowerCase());
            
            if (isCompatibleFeed) {
              // Calculate daily consumption: portion_grams * feeding_frequency * quantity
              final dailyConsumptionPerFish = portionGrams * feedingFrequency;
              final totalConsumptionForThisFish = dailyConsumptionPerFish * fishQuantity;
              totalDailyConsumption += totalConsumptionForThisFish;
            }
          }
        }
      }
      
      return totalDailyConsumption;
    } catch (e) {
      print('Error getting daily consumption for $feedName: $e');
      return 0.0;
    }
  }

  // Check if feed type is compatible with fish's preferred food
  bool _isFeedTypeCompatible(String feedType, String preferredFood) {
    if (preferredFood.isEmpty) return true; // If no preference, assume compatible
    
    final feedTypeLower = feedType.toLowerCase();
    final preferredFoodLower = preferredFood.toLowerCase();
    
    // Direct match
    if (preferredFoodLower.contains(feedTypeLower) || feedTypeLower.contains(preferredFoodLower)) {
      return true;
    }
    
    // Check feed type mappings with more comprehensive matching
    final Map<String, List<String>> feedMappings = {
      'pellets': ['pellet', 'dry food', 'commercial', 'omnivore', 'carnivore', 'herbivore'],
      'flakes': ['flake', 'dry food', 'commercial', 'omnivore', 'carnivore', 'herbivore'],
      'bloodworms': ['bloodworm', 'live food', 'protein', 'meat', 'carnivore', 'insect', 'frozen'],
      'brine shrimp': ['brine shrimp', 'live food', 'protein', 'meat', 'carnivore', 'crustacean', 'frozen'],
      'daphnia': ['daphnia', 'live food', 'protein', 'meat', 'carnivore', 'crustacean', 'frozen'],
      'tubifex': ['tubifex', 'live food', 'protein', 'meat', 'carnivore', 'worm', 'frozen'],
      'freeze-dried': ['freeze-dried', 'freeze dried', 'protein', 'meat', 'carnivore', 'frozen'],
      'spirulina': ['spirulina', 'algae', 'vegetable', 'plant', 'herbivore', 'omnivore'],
      'vegetable': ['vegetable', 'plant', 'algae', 'herbivore', 'omnivore'],
      'live food': ['live food', 'live', 'protein', 'meat', 'carnivore'],
      'frozen': ['frozen', 'live food', 'protein', 'meat', 'carnivore'],
    };

    final feedVariations = feedMappings[feedTypeLower] ?? [feedTypeLower];
    
    for (final variation in feedVariations) {
      if (preferredFoodLower.contains(variation)) {
        return true;
      }
    }
    
    // Additional compatibility checks for common aquarium scenarios
    // If fish is omnivore, most feeds should be compatible
    if (preferredFoodLower.contains('omnivore')) {
      return true;
    }
    
    // If fish is carnivore, protein-based feeds should be compatible
    if (preferredFoodLower.contains('carnivore') && 
        (feedTypeLower.contains('bloodworm') || 
         feedTypeLower.contains('brine') || 
         feedTypeLower.contains('live') || 
         feedTypeLower.contains('frozen') ||
         feedTypeLower.contains('protein'))) {
      return true;
    }
    
    // If fish is herbivore, plant-based feeds should be compatible
    if (preferredFoodLower.contains('herbivore') && 
        (feedTypeLower.contains('spirulina') || 
         feedTypeLower.contains('vegetable') || 
         feedTypeLower.contains('algae') ||
         feedTypeLower.contains('plant'))) {
      return true;
    }
    
    return false;
  }

  Map<String, double> _getFishConsumption(String feedName) {
    try {
      final Map<String, double> fishConsumption = {};
      
      // Calculate consumption for each fish using database details
      for (final fishEntry in tank.fishSelections.entries) {
        final fishName = fishEntry.key;
        final fishQuantity = fishEntry.value;
        final fishDetail = _fishDetails[fishName];
        
        if (fishDetail != null) {
          final portionGrams = fishDetail['portion_grams'] as double?;
          final feedingFrequency = fishDetail['feeding_frequency'] as int?;
          final preferredFood = fishDetail['preferred_food'] as String?;
          
          // Check if this fish eats this feed type
          if (portionGrams != null && feedingFrequency != null && preferredFood != null) {
            final isCompatibleFeed = _isFeedTypeCompatible(feedName.toLowerCase(), preferredFood.toLowerCase());
            
            if (isCompatibleFeed) {
              // Calculate daily consumption: portion_grams * feeding_frequency * quantity
              final dailyConsumptionPerFish = portionGrams * feedingFrequency;
              final totalConsumptionForThisFish = dailyConsumptionPerFish * fishQuantity;
              fishConsumption[fishName] = totalConsumptionForThisFish;
            }
          }
        }
      }
      
      return fishConsumption;
    } catch (e) {
      print('Error getting fish consumption for $feedName: $e');
      return {};
    }
  }

  Widget _buildSummaryCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF006064).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F7FA),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: const Color(0xFF006064), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
              return Padding(
      padding: const EdgeInsets.only(bottom: 6),
                child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
          Flexible(
            flex: 2,
                      child: Text(
              '$label:',
                        style: const TextStyle(
                color: Colors.black87,
                        fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
          Flexible(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompatibilityAnalysis(Tank tank) {
    // Use the existing compatibility results from the API
    final incompatiblePairs = <Map<String, dynamic>>[];
    final conditionalPairs = <Map<String, dynamic>>[];
    final compatiblePairs = <List<String>>[];

    // Get incompatible pairs from API results
    if (tank.compatibilityResults['incompatible_pairs'] is List) {
      incompatiblePairs.addAll(
        (tank.compatibilityResults['incompatible_pairs'] as List).cast<Map<String, dynamic>>()
      );
    }

    // Get conditional pairs from API results
    if (tank.compatibilityResults['conditional_pairs'] is List) {
      conditionalPairs.addAll(
        (tank.compatibilityResults['conditional_pairs'] as List).cast<Map<String, dynamic>>()
      );
    }

    // Find compatible pairs (pairs not in incompatible or conditional lists)
    final fishList = tank.fishSelections.keys.toList();
    final allAnalyzedPairs = <String>{};
    
    // Add pairs from API results
    for (final pair in [...incompatiblePairs, ...conditionalPairs]) {
      if (pair['pair'] is List) {
        final pairList = (pair['pair'] as List).map((e) => e.toString()).toList();
        if (pairList.length == 2) {
          final sortedPair = [pairList[0], pairList[1]]..sort();
          allAnalyzedPairs.add(sortedPair.join('|'));
        }
      }
    }
    
    // Find remaining compatible pairs
    for (int i = 0; i < fishList.length; i++) {
      for (int j = i + 1; j < fishList.length; j++) {
        final fish1 = fishList[i];
        final fish2 = fishList[j];
        final sortedPair = [fish1, fish2]..sort();
        final pairKey = sortedPair.join('|');
        
        if (!allAnalyzedPairs.contains(pairKey)) {
          compatiblePairs.add([fish1, fish2]);
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
            children: [
        // Summary status
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: incompatiblePairs.isNotEmpty ? Colors.red.shade50 :
                   conditionalPairs.isNotEmpty ? Colors.orange.shade50 :
                   Colors.green.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: incompatiblePairs.isNotEmpty ? Colors.red.shade200 :
                     conditionalPairs.isNotEmpty ? Colors.orange.shade200 :
                     Colors.green.shade200,
            ),
          ),
          child: Row(
              children: [
              Icon(
                incompatiblePairs.isNotEmpty ? Icons.warning :
                conditionalPairs.isNotEmpty ? Icons.info :
                Icons.check_circle,
                color: incompatiblePairs.isNotEmpty ? Colors.red :
                       conditionalPairs.isNotEmpty ? Colors.orange :
                       Colors.green,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  incompatiblePairs.isNotEmpty
                      ? '${incompatiblePairs.length} incompatible pair(s) detected'
                      : conditionalPairs.isNotEmpty
                          ? '${conditionalPairs.length} conditional pair(s) need monitoring'
                          : 'All fish are compatible',
                      style: TextStyle(
                    color: incompatiblePairs.isNotEmpty ? Colors.red.shade700 :
                           conditionalPairs.isNotEmpty ? Colors.orange.shade700 :
                           Colors.green.shade700,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        
                const SizedBox(height: 16),
                
        // Incompatible pairs
        if (incompatiblePairs.isNotEmpty) ...[
          Text(
            'Incompatible Pairs:',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ...incompatiblePairs.map((pair) {
            final pairList = (pair['pair'] as List).map((e) => e.toString()).toList();
            final reasons = pair['reasons'] as List? ?? [];
            final reasonText = reasons.isNotEmpty ? reasons.join(', ') : 'Incompatible due to different requirements';
            return _buildCompatibilityItem(
              pairList[0], pairList[1], 'incompatible', Colors.red, reasonText
            );
          }),
          const SizedBox(height: 16),
        ],
        
        // Conditional pairs
        if (conditionalPairs.isNotEmpty) ...[
          Text(
            'Conditional Pairs (Monitor Closely):',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.orange,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ...conditionalPairs.map((pair) {
            final pairList = (pair['pair'] as List).map((e) => e.toString()).toList();
            final reasons = pair['reasons'] as List? ?? [];
            final reasonText = reasons.isNotEmpty ? reasons.join(', ') : 'Monitor fish behavior closely for any signs of stress or aggression';
            return _buildCompatibilityItem(
              pairList[0], pairList[1], 'conditional', Colors.orange, reasonText
            );
          }),
          const SizedBox(height: 16),
        ],
        
        // Compatible pairs
        if (compatiblePairs.isNotEmpty) ...[
          Text(
            'Compatible Pairs:',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ...compatiblePairs.map((pair) => _buildCompatibilityItem(
            pair[0], pair[1], 'compatible', Colors.green,
            'These fish are compatible and should work well together'
          )),
        ],
      ],
    );
  }

  Widget _buildCompatibilityItem(String fish1, String fish2, String status, Color color, String reason) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Row(
            children: [
              FaIcon(FontAwesomeIcons.fish, color: color, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$fish1 ↔ $fish2',
          style: TextStyle(
            fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.toUpperCase(),
          style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            reason,
            style: TextStyle(
              color: Colors.black87,
            fontSize: 12,
          ),
            overflow: TextOverflow.visible,
            maxLines: 3,
        ),
      ],
      ),
    );
  }

}
