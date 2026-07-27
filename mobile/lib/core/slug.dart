/// Convierte el nombre de una empresa en un identificador válido para el backend
/// (minúsculas, sin acentos, sin espacios; solo a-z, 0-9 y guiones).
///
/// Así el usuario nunca escribe ni ve un "slug": teclea el nombre normal de su
/// negocio y la app lo traduce igual al registrarse y al entrar.
///
/// Ejemplos:
///   'Modelorama Toño'   -> 'modelorama-tono'
///   'Abarrotes La Esquina' -> 'abarrotes-la-esquina'
String slugify(String input) {
  var s = input.toLowerCase().trim();

  // Reemplaza acentos y ñ por su letra base.
  const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const to = 'aaaaaeeeeiiiiooooouuuunc';
  for (var i = 0; i < from.length; i++) {
    s = s.replaceAll(from[i], to[i]);
  }

  s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '-'); // todo lo no alfanumérico -> guion
  s = s.replaceAll(RegExp(r'-{2,}'), '-'); // colapsa guiones repetidos
  s = s.replaceAll(RegExp(r'^-+|-+$'), ''); // quita guiones de los extremos
  return s;
}
