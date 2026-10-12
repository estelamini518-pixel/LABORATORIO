ESCAPE DEL LABORATORIO — PROYECTO FLUTTER (10 NIVELES)
=======================================================

Este ZIP contiene el código fuente de una versión Flutter del videojuego.
Tiene diez ambientes visuales diferentes, niveles progresivos, plataformas,
zombis, llave/tarjeta, salida, tres vidas, puntuación, Game Over, victoria y
controles táctiles. El diseño se dibuja con Flutter; no depende de imágenes web.

IMPORTANTE:
- Este ZIP NO contiene todavía el APK compilado.
- Como tu Lenovo no puede compilar Android Studio, incluimos un flujo de GitHub Actions
  para compilar el APK en la nube sin instalar Android Studio en la computadora.
- El juego está configurado en orientación horizontal.
- Para compilar localmente necesitarías Flutter SDK y Android SDK, pero no es necesario
  usar ese método si usas GitHub Actions.

CÓMO GENERAR EL APK SIN ANDROID STUDIO EN TU COMPUTADORA
1. Crea una cuenta o inicia sesión en GitHub: https://github.com/
2. Crea un repositorio nuevo, por ejemplo: escape-del-laboratorio-flutter
3. Sube el contenido de este ZIP al repositorio (descomprime primero el ZIP).
   Asegúrate de que pubspec.yaml y la carpeta lib estén en la raíz del repositorio.
4. Abre la pestaña Actions del repositorio.
5. Si GitHub pide habilitar Actions, actívalo.
6. El flujo "Build Android APK" puede ejecutarse automáticamente al subir a main/master.
   También puedes entrar al flujo y pulsar "Run workflow".
7. Espera a que termine la compilación. Si falla, abre el trabajo y revisa el error.
8. Cuando termine correctamente, abre la ejecución y busca "Artifacts".
9. Descarga "Escape-del-Laboratorio-APK.zip" y extrae app-release.apk.
10. Pasa app-release.apk a tu Redmi A2 y tócalo para instalar. Android podría pedirte
    permiso para instalar apps desde la aplicación que utilizaste para abrir el archivo.

CONTROLES:
- Computadora con teclado: flechas izquierda/derecha; espacio o flecha arriba para saltar.
- Teléfono: botones IZQUIERDA, SALTAR y DERECHA.
- Objetivo: recoger la llave de cada nivel y alcanzar la puerta del extremo derecho.

NIVELES:
1. Laboratorio principal
2. Pasillo contaminado
3. Invernadero mutante
4. Almacén de suministros
5. Zona de cuarentena
6. Túneles de servicio
7. Laboratorio criogénico
8. Sector de mutación
9. Núcleo de investigación
10. Salida de emergencia

Si el flujo de compilación falla, no significa que tengas que instalar Android Studio;
revisa el log de GitHub Actions y corrige el error señalado.
