import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Estado de facturación de la cuenta (prueba / plan activo).
class BillingStatus {
  BillingStatus({
    required this.plan,
    required this.status,
    required this.inTrial,
    required this.active,
    required this.businessesAllowed,
  });

  final String plan;
  final String status;
  final bool inTrial;
  final bool active;
  final int businessesAllowed;

  factory BillingStatus.fromJson(Map<String, dynamic> j) => BillingStatus(
        plan: j['plan'] as String? ?? 'free',
        status: j['status'] as String? ?? 'trial',
        inTrial: j['in_trial'] as bool? ?? true,
        active: j['active'] as bool? ?? true,
        businessesAllowed: j['businesses_allowed'] as int? ?? 1,
      );
}

/// Acceso a los endpoints de licencias/facturación.
class BillingApi {
  BillingApi(this._dio);
  final Dio _dio;

  Future<BillingStatus> status() async {
    final r = await _dio.get('/billing/status');
    return BillingStatus.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  /// Canjea una clave de activación; activa el plan si es válida.
  Future<BillingStatus> redeem(String code) async {
    final r = await _dio.post('/billing/redeem', data: {'code': code.trim().toUpperCase()});
    return BillingStatus.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  /// Genera claves de activación (solo el vendedor, con su secreto de administrador).
  Future<List<String>> generateKeys({
    required String adminSecret,
    required String plan,
    required int months,
    required int count,
  }) async {
    // El secreto va en el cuerpo (JSON admite cualquier carácter), no en un header.
    final r = await _dio.post(
      '/billing/admin/keys',
      data: {
        'plan': plan,
        'months': months,
        'count': count,
        'admin_secret': adminSecret,
      },
    );
    return (r.data['codes'] as List).map((e) => e.toString()).toList();
  }
}

final billingApiProvider = Provider<BillingApi>(
  (ref) => BillingApi(ref.watch(dioProvider)),
);
