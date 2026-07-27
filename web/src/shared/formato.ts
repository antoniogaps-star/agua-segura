/// Dinero en pesos, a partir de centavos.
export function pesos(centavos: number): string {
  return `$${(centavos / 100).toLocaleString("es-MX", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;
}

/// "15 de enero de 2026". Con letra a propósito: "15/01" se puede leer como "1 de mayo"
/// según a qué esté acostumbrado quien lo lee.
export function fechaLarga(iso: string): string {
  const [a, m, d] = iso.slice(0, 10).split("-").map(Number);
  return new Date(a, m - 1, d).toLocaleDateString("es-MX", {
    day: "numeric",
    month: "long",
    year: "numeric",
  });
}

export function fechaCorta(iso: string): string {
  const [a, m, d] = iso.slice(0, 10).split("-").map(Number);
  return new Date(a, m - 1, d).toLocaleDateString("es-MX", {
    day: "numeric",
    month: "short",
  });
}

/// Cuánto lleva vencido, en palabras: "van 7 meses" se entiende mejor que "213 días".
export function enPalabras(dias: number): string {
  const abs = Math.abs(dias);
  if (abs === 0) return "Le toca hoy";
  let texto: string;
  if (abs === 1) texto = "1 día";
  else if (abs < 30) texto = `${abs} días`;
  else if (abs < 60) texto = "1 mes";
  else if (abs < 365) texto = `${Math.round(abs / 30)} meses`;
  else if (abs < 730) texto = "1 año";
  else texto = `${Math.round(abs / 365)} años`;
  return dias > 0 ? `Van ${texto} de retraso` : `En ${texto}`;
}

/// Abre WhatsApp con el mensaje ya escrito. El dueño solo revisa y le da enviar.
export function abrirWhatsApp(telefono: string | null, mensaje: string): boolean {
  const numero = (telefono ?? "").replace(/\D/g, "");
  if (!numero) return false;
  window.open(
    `https://wa.me/${numero}?text=${encodeURIComponent(mensaje)}`,
    "_blank",
    "noopener",
  );
  return true;
}
