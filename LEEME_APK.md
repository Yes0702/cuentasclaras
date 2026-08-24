# Cuentas Claras — APK con alarmas nativas

## Por qué esta ruta y no PWABuilder

PWABuilder envuelve tu PWA en un contenedor, pero **por dentro sigue
siendo la misma página web** con las mismas limitaciones: las alarmas
las decide el navegador. No arregla tu problema.

Este proyecto usa **Capacitor**, que sí te da acceso al `AlarmManager`
de Android. Las alarmas quedan registradas en el sistema operativo, no
en la app. Eso significa que:

- Suenan con la app completamente cerrada.
- Sobreviven a que reinicies el celular.
- Funcionan sin internet.
- No dependen de que Android decida despertar la app.

---

## Cómo generar el APK (gratis, sin instalar nada)

Compilas en los servidores de GitHub. No necesitas Android Studio ni un
computador potente.

### 1. Crea el repositorio

1. Entra a https://github.com y crea una cuenta si no tienes.
2. Botón **+** (arriba a la derecha) → **New repository**.
3. Nombre: `cuentas-claras`. Déjalo en **Private** si quieres.
4. Crear.

### 2. Sube esta carpeta

En la página del repo vacío: **uploading an existing file** → arrastra
**todo el contenido** de la carpeta `CuentasClaras_APK`.

> ⚠️ Importante: la carpeta oculta `.github` debe subir también. Si tu
> computador no la muestra, activa "ver archivos ocultos". Sin ella no
> se compila nada.

Confirma con **Commit changes**.

### 3. Espera el APK

1. Ve a la pestaña **Actions** del repo.
2. Verás "Compilar APK" corriendo (bolita amarilla). Tarda 5–10 min.
3. Cuando quede el chulo verde ✅, entra a la ejecución.
4. Abajo, en **Artifacts**, descarga **CuentasClaras-APK**.
5. Es un `.zip`; ábrelo y adentro está `CuentasClaras.apk`.

Si sale ❌ rojo, entra y mira en qué paso falló — el mensaje suele decir
exactamente qué pasó.

### 4. Instala en el celular

1. Pasa el `.apk` al teléfono (WhatsApp a ti mismo, Drive, o cable).
2. Ábrelo desde el celular.
3. Android dirá que la app viene de un origen desconocido → **Permitir**
   / **Instalar de todas formas**. Es normal: el APK no viene de Play
   Store porque no está firmado con una cuenta de desarrollador.

---

## Configuración obligatoria al abrir la app

Esto es de una sola vez, pero **sin esto las alarmas no llegan**:

1. Abre la app → **Ajustes** → **Activar notificaciones** → *Permitir*.
2. Si aparece el botón rojo **"Permitir alarmas exactas"**, tócalo. Se
   abre una pantalla de Android → activa *"Permitir alarmas y
   recordatorios"*. Sin esto Android agrupa tus avisos y llegan tarde.
3. Ajustes de Android → Apps → Cuentas Claras → **Batería** →
   **"Sin restricciones"**.
4. Solo en Xiaomi / Huawei / Oppo / Samsung: busca **"Inicio automático"**
   (o *Autostart*) y actívalo. Son las marcas más agresivas cerrando apps.

Luego toca **"Probar aviso"**: programa una notificación a 5 segundos.
Cierra la app por completo (deslízala fuera de recientes) y verifica que
llegue igual. Esa es la prueba real.

---

## Cómo funciona por dentro

La app calcula las **próximas 30 ocurrencias** de cada alarma y las
registra una por una en Android con `allowWhileIdle: true` (dispara
incluso en modo Doze). Se re-agendan solas cada vez que abres la app,
así que el colchón nunca se vacía: en una alarma diaria son ~30 días de
margen sin abrir la app.

Se agenda por fechas explícitas en vez de usar la repetición del plugin
porque esta última ha sido históricamente inconsistente entre versiones
de Android.

En el APK, el service worker queda desactivado como fuente de alarmas
(recibe una lista vacía) para que no te lleguen avisos duplicados. El
mismo `index.html` sigue funcionando como PWA normal en el navegador.

---

## Si cambias la app después

Editas `www/index.html` en GitHub (o subes el archivo nuevo), y al hacer
commit el APK se vuelve a compilar solo. Descargas el nuevo de Actions y
lo instalas encima: **tus datos no se borran**, quedan en el
almacenamiento local de la app.

---

## Nota sobre firma y Play Store

Este APK es de tipo *debug*: sirve perfectamente para instalarlo en tus
celulares y los de tu familia. Si algún día quieres publicarlo en Google
Play necesitas un `.aab` firmado y una cuenta de desarrollador (pago
único de 25 USD). El paso de compilación cambiaría a `bundleRelease` más
la firma con un keystore.

---

# ⚙️ Configurar WhatsApp y donaciones

Abre `www/index.html`, busca `const CONFIG = {` (está al inicio del
`<script>`, cerca de la línea 2800) y cambia solo esos valores:

```js
const CONFIG = {
  whatsapp: "573001234567",   // tu número con indicativo, solo números
  nequi:    "3001234567",     // tu Nequi
  breb:     "@TuLlave123",    // tu llave Bre-B
  pseUrl:   "",               // link de pago, opcional
  mostrarDonacion: true       // false esconde todo el bloque
};
```

**Lo que dejes vacío (`""`) desaparece solo de la pantalla.** Si no
quieres el bloque de donaciones todavía, pon `mostrarDonacion: false`
y no se ve nada.

## Sobre las llaves Bre-B

Como persona natural puedes registrar hasta cuatro llaves: celular,
cédula, correo o una alfanumérica tipo `@Maria123`. **Registra la
alfanumérica** desde la app de tu banco (busca "Bre-B" o "Registrar
llave") y usa esa. Así no expones tu número ni tu cédula a gente que no
conoces. Recibir es gratis y funciona desde cualquier banco.

## Sobre PSE

`pseUrl` queda vacío a propósito. Como persona natural no puedes recibir
PSE directamente: necesitas un agregador (Wompi, ePayco, Mercado Pago),
que cobra comisión por transacción. Con Nequi y Bre-B, que son gratis,
ya cubres el 95% de los casos en Colombia. Si algún día lo quieres,
creas un link de pago en Wompi y lo pegas ahí.
