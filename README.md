# NEOBANK GT - Proyecto Final de Base de Datos I

Simulador bancario realizado con SQL Server: clientes individuales y jurídicos,
cuentas compartidas en GTQ/USD, depósitos, retiros, transferencias, tarjetas,
plazos fijos, conversiones y auditoría. Se ejecuta mediante SQL; el enunciado no
requiere una aplicación gráfica.

Se continuó el modelo de las 19 tablas del respaldo original. Se conservaron
sus nombres, relaciones, tipos y restricciones, y se añadieron tres tablas de
control para referencias globales, auditoría y reversos de transferencias.

## Abrir el proyecto instalado

En SQL Server Management Studio, conectarse a `localhost` con autenticación de
Windows y abrir `sql/09_demostracion.sql`. La base principal es `NEOBANK_GT`.
El archivo muestra los datos de ejemplo y los resultados de las funciones.
Las doce consultas completas están en `sql/07_consultas.sql`; seleccionar
`NEOBANK_GT` en la lista de bases antes de ejecutarlas.

## Instalación en otro equipo

Requisitos: SQL Server 2019 o posterior, PowerShell con `System.Data.SqlClient`
y una cuenta de Windows autorizada para crear bases. Validado en SQL Server
2025 Developer. SSMS sirve para leer y ejecutar los scripts manualmente.

Desde la carpeta del proyecto en PowerShell:

```powershell
.\tools\Instalar-Neobank.ps1 -Database NEOBANK_GT
```

El instalador crea una base nueva y se detiene si ya existe. No elimina ni
sobrescribe bases. El esquema procede del respaldo; los datos de instalación
son completamente ficticios y no contienen credenciales del respaldo.
`-Server` permite indicar otra instancia local, por ejemplo `.\SQLEXPRESS`.
No se instalan componentes ni se modifican permisos de Windows.

Para actualizar una **copia compatible del proyecto original**, primero conservar
un respaldo y después utilizar:

```powershell
.\tools\Instalar-Neobank.ps1 -Database NEOBANK_GT_DESARROLLO -Actualizar -SinDemo
```

Esta migración se verificó contra el respaldo entregado. No se garantiza una
migración automática de otras versiones con datos o estructuras diferentes.

## Archivos y orden de ejecución

| Archivo | Contenido |
|---|---|
| `sql/01_esquema_original.sql` | 19 tablas originales, claves, índices y restricciones |
| `sql/02_integridad_auditoria.sql` | Migración, referencias únicas y movimientos inmutables |
| `sql/03_funciones.sql` | Las cuatro funciones F01-F04 |
| `sql/04_procedimientos.sql` | SP01-SP10 obligatorios, SP11-SP20 de soporte y dos auxiliares |
| `sql/05_catalogos.sql` | Tipos, monedas, bancos y operador ficticio |
| `sql/06_datos_demo.sql` | Escenario reproducible con ocho clientes ficticios |
| `sql/07_consultas.sql` | Las doce consultas C01-C12 con parámetros al inicio |
| `sql/08_permisos.sql` | Rol opcional preparado; no aplicado por el instalador |
| `sql/09_demostracion.sql` | Recorrido de lectura para presentar el proyecto en SSMS |
| `tools/` | Instalación y pruebas repetibles |
| `evidencias/` | Resultados reales de ejecución en JSON |
| `docs/` | Requerimientos, diseño, guía del código y colaboración |

## Pruebas

Crear una base separada para que las pruebas no mezclen sus datos con los de
demostración de la base principal:

```powershell
.\tools\Instalar-Neobank.ps1 -Database NEOBANK_GT_PRUEBAS
.\tools\Verificar-Consultas.ps1 -Database NEOBANK_GT_PRUEBAS
.\tools\Probar-Neobank.ps1 -Database NEOBANK_GT_PRUEBAS
```

La verificación de las consultas exige una instalación demo recién creada y
debe ejecutarse antes de la suite que inserta datos de prueba. La suite usa un
prefijo distinto en cada ejecución, deja sus datos ficticios identificables y
no elimina registros existentes. Incluye errores controlados y concurrencia.
Los resultados se guardan en `evidencias/`.

## Criterios del simulador

- Tasas de plazo fijo: porcentaje anual, interés simple y año de 365 días.
- Importes monetarios: positivos, con dos decimales. Los tipos originales
  `decimal(18,6)` se conservan por compatibilidad; cotizaciones usan ocho decimales.
- Las transferencias internas requieren la misma moneda. Para GTQ/USD se usa SP07.
- Las interbancarias debitan al solicitarse; confirmar no vuelve a debitar y
  rechazar devuelve el importe mediante un reverso. La cuenta debe estar activa.
- Cada titular ve el saldo completo de una cuenta compartida. Los totales del
  banco se calculan por cuenta, para no multiplicar saldos por cotitulares.
- Las tarjetas tienen una cuenta vinculada que identifica su moneda. Los
  identificadores `DEMO-*` son ficticios y no son números de tarjetas reales.
- `operador_demo` es un registro de auditoría; no permite iniciar sesión. La
  conexión usa autenticación de Windows de SQL Server.
- Los errores se propagan con `THROW`. Si la rutina participa en una transacción
  externa y falla, revierte toda esa transacción; el cliente debe reiniciarla.

Las escrituras de las rutinas se serializan con `sp_getapplock` para impedir
sobregiros y referencias duplicadas. La estrategia simplifica este proyecto
académico y limita el rendimiento con muchas operaciones simultáneas.

## Seguridad y GitHub

No versionar `.bak`, `.mdf`, `.ldf`, contraseñas, tokens, `.env` ni datos reales.
El repositorio contiene el esquema y datos de prueba reproducibles. El respaldo
original permanece en el equipo y se excluye del repositorio.

El rol opcional `neobank_operador` concede lectura de tablas de negocio y
ejecución de SP01-SP20, sin escritura directa de saldos ni lectura de
`clave_hash`. El script no asigna miembros ni crea logins. Su aplicación quedó
pendiente de aprobación explícita de permisos; la instalación actual utiliza
los permisos previos de la conexión de desarrollo.

Repositorio: [eperezv23/Proyecto-Final](https://github.com/eperezv23/Proyecto-Final).
Ver `docs/COLABORACION.md` para ramas, revisiones y sincronización.
