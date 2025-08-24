import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserPlanProvider with ChangeNotifier {
  String _plan = 'free';
  String get plan => _plan;
  RealtimeChannel? _realtimeChannel;

  Future<void> fetchPlan() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('tier_plan')
            .eq('id', user.id)
            .single();
        
        final raw = (data['tier_plan'] as String?)?.trim().toLowerCase() ?? '';
        // Normalize to only 'pro' or 'free'
        _plan = (raw == 'pro') ? 'pro' : 'free';
        notifyListeners();
      } catch (error) {
        debugPrint('Error fetching plan: $error');
        _plan = 'free';
        notifyListeners();
      }
    }
  }

  /// Start realtime subscription to the current user's `profiles.tier_plan` changes
  void subscribeToPlanChanges() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Avoid duplicating subscriptions
    if (_realtimeChannel != null) return;

    final channelName = 'profiles-plan-${user.id}';
    _realtimeChannel = Supabase.instance.client.channel(channelName);
    
    _realtimeChannel!
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'profiles',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: user.id,
        ),
        callback: (payload) {
          try {
            final newRecord = payload.newRecord;
            if (newRecord == null) return;
            
            final raw = (newRecord['tier_plan'] as String?)?.trim().toLowerCase() ?? '';
            final normalized = (raw == 'pro') ? 'pro' : 'free';
            
            if (normalized != _plan) {
              _plan = normalized;
              notifyListeners();
            }
          } catch (e) {
            debugPrint('Error processing realtime update: $e');
          }
        },
      )
      .subscribe();
  }

  /// Stop realtime subscription
  Future<void> unsubscribeFromPlanChanges() async {
    if (_realtimeChannel != null) {
      await _realtimeChannel!.unsubscribe();
      _realtimeChannel = null;
    }
  }

  void setPlan(String newPlan) {
    final normalized = newPlan.trim().toLowerCase();
    _plan = (normalized == 'pro') ? 'pro' : 'free';
    notifyListeners();
  }

  @override
  void dispose() {
    // Note: dispose() is synchronous, but unsubscribe is async
    // In a real app, consider managing this differently
    unsubscribeFromPlanChanges();
    super.dispose();
  }
}