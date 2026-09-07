// Agrega los permisos de alarmas exactas y notificaciones al AndroidManifest
const fs = require("fs");
const path = "android/app/src/main/AndroidManifest.xml";
try{
  let m = fs.readFileSync(path, "utf8");
  const permisos = [
    '<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>',
    '<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>',
    '<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>',
    '<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>',
    '<uses-permission android:name="android.permission.VIBRATE"/>',
    '<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>'
  ];
  permisos.forEach(p=>{
    if(!m.includes(p)){
      m = m.replace("<application", p + "\n    <application");
    }
  });
  fs.writeFileSync(path, m);
  console.log("Permisos de alarmas agregados al AndroidManifest");
}catch(e){
  console.log("No se pudo modificar el manifest (puede que aún no exista):", e.message);
}
