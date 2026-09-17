// scripts/textzoom-android.js
// Bloquea el tamaño de letra del sistema en el WebView de la app,
// para que SOLO mande el control "Tamaño de letra" de Ajustes dentro de Cuentas Claras.
const fs = require("fs");
const path = "android/app/src/main/java/com/cuentasclaras/presupuesto/MainActivity.java";

if (!fs.existsSync(path)) {
  console.log("⚠️  No encontré MainActivity.java en la ruta esperada, no se tocó nada.");
  process.exit(0);
}

let contenido = fs.readFileSync(path, "utf8");

if (contenido.includes("setTextZoom")) {
  console.log("✓ MainActivity.java ya tiene el ajuste de tamaño de letra fijo.");
  process.exit(0);
}

const plantillaSimple = "public class MainActivity extends BridgeActivity {}";

if (contenido.includes(plantillaSimple)) {
  contenido = contenido
    .replace("import com.getcapacitor.BridgeActivity;",
      "import android.os.Bundle;\nimport com.getcapacitor.BridgeActivity;")
    .replace(plantillaSimple,
`public class MainActivity extends BridgeActivity {
  @Override
  public void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    // Ignora el tamaño de letra del sistema: solo manda el ajuste propio de la app.
    if (getBridge() != null && getBridge().getWebView() != null) {
      getBridge().getWebView().getSettings().setTextZoom(100);
    }
  }
}`);
  fs.writeFileSync(path, contenido);
  console.log("✓ Se agregó setTextZoom(100) a MainActivity.java");
} else {
  console.log("⚠️  MainActivity.java no tiene la forma esperada. No se tocó nada — revisar manualmente.");
}
