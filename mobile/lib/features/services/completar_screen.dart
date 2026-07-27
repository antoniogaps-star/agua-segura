import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/formato.dart';
import '../../core/providers.dart';
import '../../data/local/database.dart';
import 'services_repository.dart';

/// Terminar un servicio: fotos del antes y el después, cuánto se cobró, y el
/// certificado listo para mandar por WhatsApp.
///
/// El cliente nunca ve su tinaco por dentro: paga por fe. Las dos fotos son lo que
/// convierte esa fe en una prueba — y a restaurantes, escuelas y guarderías les sirve
/// de comprobante sanitario.
class CompletarScreen extends ConsumerStatefulWidget {
  const CompletarScreen({super.key, required this.visita, required this.cliente});

  final ServiceJob visita;
  final Client? cliente;

  @override
  ConsumerState<CompletarScreen> createState() => _CompletarScreenState();
}

class _CompletarScreenState extends ConsumerState<CompletarScreen> {
  late final TextEditingController _precio = TextEditingController(
    text: (_sugerido / 100).toStringAsFixed(2),
  );
  final _notas = TextEditingController();
  bool _pagado = true; // todo es en efectivo, casi siempre se cobra al terminar
  String? _antes;
  String? _despues;
  bool _guardando = false;

  int get _sugerido => widget.visita.priceCents > 0
      ? widget.visita.priceCents
      : (precioSugeridoCents[widget.visita.serviceType] ?? 0);

  @override
  void initState() {
    super.initState();
    _antes = widget.visita.photoBefore;
    _despues = widget.visita.photoAfter;
    _notas.text = widget.visita.notes ?? '';
  }

  @override
  void dispose() {
    _precio.dispose();
    _notas.dispose();
    super.dispose();
  }

  Future<void> _tomarFoto({required bool antes}) async {
    final tomada = await ImagePicker().pickImage(
      source: ImageSource.camera,
      // Se comprime al tomarla: en la azotea no hay red para subir fotos enormes, y
      // llenar el celular del técnico sería un problema en dos semanas.
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (tomada == null) return;
    setState(() {
      if (antes) {
        _antes = tomada.path;
      } else {
        _despues = tomada.path;
      }
    });
    await ref.read(servicesRepositoryProvider).guardarFoto(
          widget.visita,
          antes: antes ? tomada.path : null,
          despues: antes ? null : tomada.path,
        );
  }

  int get _centavos {
    final limpio = _precio.text.replaceAll(RegExp(r'[^0-9.]'), '');
    return ((double.tryParse(limpio) ?? 0) * 100).round();
  }

  String _certificado() {
    final servicio = tiposDeServicio[widget.visita.serviceType] ?? widget.visita.serviceType;
    final hoy = DateTime.now();
    final proxima = siguienteFecha(widget.visita.serviceType, hoy);
    return '''
🧾 *CERTIFICADO DE SERVICIO — Agua Segura*

Cliente: ${widget.cliente?.name ?? ''}
${(widget.cliente?.address ?? '').isEmpty ? '' : 'Domicilio: ${widget.cliente!.address}\n'}Servicio: $servicio
Fecha: ${fechaLarga(hoy)}
${proxima == null ? '' : 'Próximo mantenimiento recomendado: ${fechaLarga(proxima)}\n'}
Gracias por confiar en nosotros.
_Hogar protegido, agua segura._'''
        .trim();
  }

  Future<void> _guardar({required bool compartir}) async {
    setState(() => _guardando = true);
    try {
      await ref.read(servicesRepositoryProvider).completar(
            widget.visita,
            priceCents: _centavos,
            isPaid: _pagado,
            notes: _notas.text.trim().isEmpty ? null : _notas.text.trim(),
            photoBefore: _antes,
            photoAfter: _despues,
          );

      if (compartir) {
        final fotos = [
          if (_antes != null) XFile(_antes!),
          if (_despues != null) XFile(_despues!),
        ];
        await Share.shareXFiles(fotos, text: _certificado());
      }
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final servicio = tiposDeServicio[widget.visita.serviceType] ?? widget.visita.serviceType;
    final proxima = siguienteFecha(widget.visita.serviceType, DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Terminar servicio')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.cliente?.name ?? 'Cliente',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(servicio, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),

          Text('Fotos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'El cliente no ve su tinaco por dentro. Las fotos son su comprobante.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Foto(
                  titulo: 'ANTES',
                  ruta: _antes,
                  onTap: () => _tomarFoto(antes: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Foto(
                  titulo: 'DESPUÉS',
                  ruta: _despues,
                  onTap: () => _tomarFoto(antes: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          TextField(
            controller: _precio,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Cuánto se cobró',
              prefixText: '\$ ',
              border: OutlineInputBorder(),
              // El sugerido ya viene puesto, pero un tinaco de 1100 L no cuesta igual
              // que uno de 450: siempre se puede cambiar.
              helperText: 'Puedes cambiarlo si el trabajo fue distinto',
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ya me pagó'),
            subtitle: Text(_pagado ? 'En efectivo' : 'Queda pendiente de cobro'),
            value: _pagado,
            onChanged: (v) => setState(() => _pagado = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notas,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Notas (opcional)',
              hintText: 'Tinaco de 1100 L, tapa rota…',
              border: OutlineInputBorder(),
            ),
          ),

          if (proxima != null) ...[
            const SizedBox(height: 20),
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: ListTile(
                leading: const Icon(Icons.event_repeat),
                title: const Text('Próximo mantenimiento'),
                subtitle: Text(
                  '${fechaLarga(proxima)} — se anota solo, no hay que acordarse',
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _guardando ? null : () => _guardar(compartir: true),
            icon: const Icon(Icons.share),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            label: const Text('Terminar y mandar certificado'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _guardando ? null : () => _guardar(compartir: false),
            child: const Text('Solo terminar'),
          ),
        ],
      ),
    );
  }
}

class _Foto extends StatelessWidget {
  const _Foto({required this.titulo, required this.ruta, required this.onTap});

  final String titulo;
  final String? ruta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: ruta == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.photo_camera_outlined, size: 32),
                  const SizedBox(height: 8),
                  Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Text('Tocar para tomar', style: TextStyle(fontSize: 11)),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(File(ruta!), fit: BoxFit.cover),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      color: Colors.black54,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        titulo,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
