# Diagnóstico y cambios realizados

## Punto de partida verificado

El ZIP suministrado contenía un diagrama PNG, un respaldo NEOBANK_GT.bak y
SP01.sql. El respaldo se recuperó en una nueva base de desarrollo, sin reemplazar
la base MUNICIPALIDAD ni modificar el respaldo original.

La inspección confirmó 19 tablas de negocio, catálogos, un cliente, dos cuentas
con saldos de 5000 y 2500, un usuario y dos tipos de cambio. No había movimientos,
tarjetas ni inversiones cargadas. Las rutinas presentes en el respaldo eran
las de diagramas de SSMS; no había procedimientos ni funciones de negocio.
SP01 estaba entregado como archivo separado.

## Cambios

- Se conservó el esquema original como script reproducible.
- Se continuó SP01 manteniendo sus parámetros y reforzando validaciones.
- Se implementaron los diez procedimientos y cuatro funciones obligatorios.
- Se añadieron diez procedimientos para completar cotitularidad, emisión de
  tarjetas, débito, resolución interbancaria, liquidación, estados, reversos,
  registro de usuarios de auditoría y tipos de cambio.
- Se añadieron dos auxiliares internos para referencias y movimientos.
- Se incorporaron auditoría, referencias globales únicas y protección del historial.
- Se añadieron índices de identificación y consulta por cuenta/fecha, y
  restricciones complementarias. Las tarjetas nuevas requieren cuenta vinculada.
- Se prepararon doce consultas, datos ficticios, instalador y pruebas repetibles.
- Se documentaron fórmulas, reglas, estructura y colaboración con Git.
- Se comentaron los pasos relevantes del código en español.

## Pruebas y alcance

La evidencia JSON registra ejecución real, no una simulación de resultados.
Se ejecutaron 74 comprobaciones funcionales y doce validaciones de consultas.
La suite comprueba la atomicidad provocando un error después del débito y
ejecuta dos retiros simultáneos de 80 sobre una cuenta con 100; sólo uno puede
completarse y el saldo final es 20.

Una primera ejecución detectó que una clave foránea ya impedía borrar un
movimiento reversado antes de llegar al trigger. Se ajustó la prueba para
aceptar ambos mecanismos válidos de protección; las ejecuciones finales
completaron sus verificaciones sin fallos.

Los datos de prueba permanecen en la base de validación, identificados por un
prefijo propio. La base principal conserva el escenario demo para presentar
las consultas. Los archivos de evidencia no incluyen claves ni datos del
cliente original del respaldo.

## Configuración pendiente de aprobación

La revisión automática bloqueó aplicar el script opcional de rol SQL por
requerir aprobación expresa de sus permisos. El archivo está preparado, pero
no se ejecutó ni se asignaron miembros. La conexión de desarrollo conserva los
permisos que ya tenía. Tampoco se cambiaron permisos de GitHub, la visibilidad
del repositorio ni las reglas de protección de ramas.

El bloqueo de copiar el respaldo a Documentos públicos se resolvió utilizando
la carpeta propia de respaldos de SQL Server. El respaldo no se publica.
