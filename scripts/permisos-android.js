/* Añade al AndroidManifest.xml los permisos que necesitan las alarmas.
   Se ejecuta solo, después de "npx cap add android". Es idempotente. */
const fs = require("fs");
const RUTA = "android/app/src/main/AndroidManifest.xml";

const PERMISOS = [
  "android.permission.POST_NOTIFICATIONS",
  "android.permission.SCHEDULE_EXACT_ALARM",
  "android.permission.RECEIVE_BOOT_COMPLETED",
  "android.permission.VIBRATE",
  "android.permission.WAKE_LOCK",
  "android.permission.USE_BIOMETRIC"
];

if (!fs.existsSync(RUTA)) {
  console.error("No encuentro " + RUTA + ". ¿Corriste 'npx cap add android' antes?");
  process.exit(1);
}

let xml = fs.readFileSync(RUTA, "utf8");
const faltantes = PERMISOS.filter((p) => !xml.includes('"' + p + '"'));

if (!faltantes.length) {
  console.log("Los permisos ya estaban puestos. Nada que hacer.");
  process.exit(0);
}

const bloque = faltantes
  .map((p) => '    <uses-permission android:name="' + p + '" />')
  .join("\n");

// se insertan justo antes del cierre de <manifest>
xml = xml.replace(/<\/manifest>/, bloque + "\n</manifest>");
fs.writeFileSync(RUTA, xml, "utf8");

console.log("Permisos agregados:\n" + faltantes.map((p) => "  - " + p).join("\n"));
