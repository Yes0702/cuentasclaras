// Convierte el proyecto Android ya compilado como APK de GitHub en la versión
// para Google Play (el AAB). Se corre en el workflow DESPUÉS de compilar el APK
// y ANTES de compilar el AAB, así el APK de GitHub queda exactamente igual.
//
// Qué cambia solo en la versión de Play (y por qué):
//  1. La app sabe que es la de Play (CC_CANAL = "play"): no busca ni descarga
//     actualizaciones por su cuenta (Play prohíbe que una app se actualice por
//     fuera de la tienda) y no muestra donaciones por Bre-B/PayPal (Play exige
//     su propio sistema de pagos para eso).
//  2. Se quitan los permisos que Play restringe:
//     - REQUEST_INSTALL_PACKAGES: solo se permite a tiendas/gestores de archivos.
//     - USE_EXACT_ALARM: solo para apps cuyo propósito principal es ser alarma o
//       calendario. Los recordatorios siguen funcionando con SCHEDULE_EXACT_ALARM.
//  3. Apunta a Android 16 (API 36), que Play exige a apps nuevas y actualizaciones
//     desde el 31 de agosto de 2026. Como en Android 16 la app siempre se dibuja
//     "de borde a borde", se le pide a Capacitor que deje el espacio de la barra de
//     estado y la de navegación para que nada quede tapado.
//
// Si algo de esto no se puede aplicar, el script FALLA a propósito: es mejor que
// la compilación se detenga a que salga un AAB que Play vaya a rechazar.
const fs = require("fs");

function fallar(msg){ console.error("❌ " + msg); process.exit(1); }

// 1) Marcar la app web como versión de Play
const html = "android/app/src/main/assets/public/index.html";
let h = fs.readFileSync(html, "utf8");
const marca = 'const CC_CANAL = "github";';
if(!h.includes(marca)) fallar("No encontré " + marca + " en " + html);
h = h.replace(marca, 'const CC_CANAL = "play";');
fs.writeFileSync(html, h);
console.log("✔ App marcada como versión de Google Play");

// 2) Quitar permisos restringidos (también si alguna librería los trajera)
const manifest = "android/app/src/main/AndroidManifest.xml";
let m = fs.readFileSync(manifest, "utf8");
if(!m.includes('xmlns:tools=')){
  m = m.replace("<manifest ", '<manifest xmlns:tools="http://schemas.android.com/tools" ');
}
["REQUEST_INSTALL_PACKAGES", "USE_EXACT_ALARM"].forEach(p=>{
  const nombre = "android.permission." + p;
  // Borra la línea que agregó scripts/permisos-android.js...
  m = m.split("\n").filter(l=> !(l.includes('"' + nombre + '"') && l.includes("uses-permission"))).join("\n");
  // ...y deja una orden explícita de quitarlo del manifiesto final.
  m = m.replace("<application", '<uses-permission android:name="' + nombre + '" tools:node="remove"/>\n    <application');
});
fs.writeFileSync(manifest, m);
console.log("✔ Permisos REQUEST_INSTALL_PACKAGES y USE_EXACT_ALARM quitados");

// 3) Android 16 (API 36)
const vars = "android/variables.gradle";
let v = fs.readFileSync(vars, "utf8");
if(!/compileSdkVersion\s*=\s*\d+/.test(v) || !/targetSdkVersion\s*=\s*\d+/.test(v)) fallar("No encontré compileSdkVersion/targetSdkVersion en " + vars);
v = v.replace(/compileSdkVersion\s*=\s*\d+/, "compileSdkVersion = 36").replace(/targetSdkVersion\s*=\s*\d+/, "targetSdkVersion = 36");
fs.writeFileSync(vars, v);
const props = "android/gradle.properties";
let gp = fs.existsSync(props) ? fs.readFileSync(props, "utf8") : "";
if(!gp.includes("android.suppressUnsupportedCompileSdk")) gp += "\nandroid.suppressUnsupportedCompileSdk=36\n";
fs.writeFileSync(props, gp);
console.log("✔ Apunta a Android 16 (API 36)");

const capCfg = "android/app/src/main/assets/capacitor.config.json";
const cfg = JSON.parse(fs.readFileSync(capCfg, "utf8"));
cfg.android = Object.assign({}, cfg.android, { adjustMarginsForEdgeToEdge: "force" });
fs.writeFileSync(capCfg, JSON.stringify(cfg, null, 2));
console.log("✔ Márgenes para barras del sistema activados (Android 16 de borde a borde)");
