import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserPlanProvider with ChangeNotifier {
  String _plan = 'free';
  String get plan => _plan;

  Future<void> fetchPlan() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('tier_plan')
            .eq('id', user.id)
            .single();
        _plan = data['tier_plan'] ?? 'free';
        notifyListeners();
      } catch (error) {
        print('Error fetching plan: $error');
        _plan = 'free';
        notifyListeners();
      }
    }
  }

  void setPlan(String newPlan) {
    _plan = newPlan;
    notifyListeners();
  }
} 