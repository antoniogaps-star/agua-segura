import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../data/local/database.dart';

/// El equipo del negocio: el dueño y sus técnicos.
///
/// Las **altas van contra el servidor**, no a la base local, porque crear un usuario
/// implica fijar una contraseña y comprobar quién tiene permiso — eso no se puede hacer
/// offline sin abrir un boquete. La **consulta** sí es local: el técnico necesita ver
/// los nombres en la azotea, sin señal.
class EquipoRepository {
  EquipoRepository(this._db, this._dio);

  final AppDatabase _db;
  final Dio _dio;

  /// Todos los del equipo, desde la base local (funciona sin internet).
  Future<List<TeamMember>> list() => _db.activeTeam();

  /// Solo los técnicos: son a quienes se les asignan las visitas.
  Future<List<TeamMember>> tecnicos() => _db.technicians();

  Future<TeamMember?> porId(String id) =>
      (_db.select(_db.teamMembers)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Da de alta a un técnico. Necesita internet: la cuenta vive en el servidor.
  Future<void> agregarTecnico({
    required String nombre,
    required String correo,
    required String contrasena,
  }) async {
    await _dio.post('/users', data: {
      'email': correo,
      'password': contrasena,
      'name': nombre,
      // "operator" es el técnico: su agenda y sus servicios, sin la caja.
      'role': 'operator',
    });
  }

  /// Da de baja a un técnico (deja de entrar, su historial de trabajos se queda).
  Future<void> darDeBaja(TeamMember quien) async {
    await _dio.delete('/users/${quien.id}');
  }

  /// Trae el equipo del servidor y lo guarda local. Se llama al abrir la pantalla y
  /// después de un alta, para no esperar a la siguiente sincronización.
  Future<void> refrescar() async {
    final respuesta = await _dio.get('/users');
    final lista = (respuesta.data as List).cast<Map<String, dynamic>>();
    for (final u in lista) {
      await _db.into(_db.teamMembers).insertOnConflictUpdate(
            TeamMembersCompanion.insert(
              id: u['id'] as String,
              tenantId: u['tenant_id'] as String,
              email: u['email'] as String,
              name: Value(u['name'] as String?),
              role: u['role'] as String,
              isActive: Value(u['is_active'] as bool? ?? true),
            ),
          );
    }
  }
}
