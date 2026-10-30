# Guía para leer el código

## Cómo se ejecuta una operación

1. La rutina inicia una transacción SQL y activa `XACT_ABORT`.
2. `SP00_ABRIR_OPERACION` obtiene un bloqueo transaccional exclusivo, comprueba
   el usuario y registra una referencia única. Esto impide gastar los mismos
   fondos en solicitudes simultáneas y repetir una referencia.
3. La rutina comprueba las condiciones del producto: estado, moneda, titular,
   importe, saldo, deuda o vencimiento, según corresponda.
4. Actualiza los saldos y registra movimientos y registros del producto.
   `SP00_MOVIMIENTO` centraliza la escritura de los movimientos confirmados.
5. Registra auditoría y ejecuta `COMMIT`. Si cualquier paso falla, el bloque
   `CATCH` ejecuta `ROLLBACK` y `THROW` devuelve el error original al cliente.

SP01 conserva la firma original para registrar clientes. Utiliza el mismo
bloqueo para evitar carreras y los índices únicos respaldan su validación.
Su desencadenador registra el usuario SQL mediante `ORIGINAL_LOGIN()`. Las
demás rutinas públicas también reciben `@id_usuario` y `@referencia`.

## Rutinas públicas

| Rutina | Acción y efecto relevante |
|---|---|
| SP01_REGISTRAR_CLIENTE | Limpia espacios, valida CUI/NIT y registra un cliente activo |
| SP02_APERTURAR_CUENTA | Crea cuenta en GTQ/USD con saldo cero y primer titular |
| SP03_REGISTRAR_DEPOSITO | Aumenta saldo y registra un crédito |
| SP04_REGISTRAR_RETIRO | Valida fondos, disminuye saldo y registra débito |
| SP05_TRANSFERENCIA_INTERNA | Debita origen y acredita destino; vincula ambos movimientos |
| SP06_TRANSFERENCIA_INTERBANCARIA | Debita fondos y deja el envío simulado pendiente |
| SP07_CAMBIO_MONEDA | Consulta cotización vigente, convierte y conserva la tasa aplicada |
| SP08_CONSTITUIR_PLAZO_FIJO | Debita principal y registra tasa anual, plazo y vencimiento |
| SP09_CONSUMO_TARJETA_CREDITO | Comprueba límite y estado y aumenta deuda |
| SP10_PAGO_TARJETA_CREDITO | Debita una cuenta y reduce deuda en la misma moneda |
| SP11_AGREGAR_TITULAR | Agrega otro cliente activo a una cuenta activa |
| SP12_EMITIR_TARJETA | Emite débito/crédito vinculado a cuenta y cliente |
| SP13_CONSUMO_TARJETA_DEBITO | Registra consumo y debita la cuenta vinculada |
| SP14_RESOLVER_INTERBANCARIA | Confirma sin otro débito o rechaza devolviendo fondos |
| SP15_LIQUIDAR_PLAZO_FIJO | Devuelve principal más interés cuando vence el plazo |
| SP16_CAMBIAR_ESTADO_PRODUCTO | Gestiona estados y rechaza cierres con fondos u obligaciones |
| SP17_REVERSAR_MOVIMIENTO | Compensa un depósito/retiro; conserva el original |
| SP18_REVERSAR_TRANSFERENCIA_INTERNA | Compensa ambos lados de una transferencia una sola vez |
| SP19_REGISTRAR_USUARIO | Registra operadores de auditoría sin crear accesos SQL |
| SP20_REGISTRAR_TIPO_CAMBIO | Agrega una cotización nueva sin reemplazar el historial |

## Funciones

- `F01_SALDO_DISPONIBLE(id_cuenta)`: saldo si la cuenta está activa; cero si está
  bloqueada/cerrada; `NULL` si no existe.
- `F02_INTERES_PLAZO_FIJO(id_plazo_fijo)`: interés pactado al vencimiento,
  `monto × tasa_anual/100 × días/365`, redondeado a centavos.
- `F03_UTILIZACION_TARJETA(id_tarjeta)`: deuda/límite × 100; `NULL` para una
  tarjeta inexistente, de débito o sin límite válido.
- `F04_CONVERTIR_MONEDA(monto,origen,destino,fecha)`: usa la cotización activa
  más reciente no posterior a la fecha. Devuelve `NULL` si faltan datos válidos
  o cotización. Para igual moneda conserva el importe redondeado.

## Tablas nuevas y restricciones

`TB_OPERACION` evita referencias repetidas entre módulos, identifica al
operador y conserva el principal SQL. `TB_EVENTO_AUDITORIA` registra altas y
eventos de las rutinas. `TB_REVERSO_TRANSFERENCIA` impide compensar una misma
transferencia dos veces.

Los índices únicos filtrados de CUI/NIT permiten varios valores `NULL` y
rechazan duplicados cuando existe identificación. Las claves foráneas mantienen
relaciones válidas. Los `CHECK` controlan saldos, montos, estados y fechas.

El desencadenador `TR_MOVIMIENTO_INMUTABLE` rechaza `UPDATE` y `DELETE` de
movimientos confirmados. Otros desencadenadores protegen el registro global y
la auditoría. Los reversos son nuevos registros, no modificaciones del original.

## Ejemplo de depósito manual

Este ejemplo modifica únicamente una cuenta ficticia; la referencia cambia en
cada ejecución para que una solicitud repetida no se confunda con otra nueva.

```sql
USE NEOBANK_GT;
DECLARE @cuenta int=(SELECT id_cuenta FROM dbo.TB_CUENTA WHERE numero_cuenta='DEMO-GTQ-1'),
 @usuario int=(SELECT id_usuario FROM dbo.TB_USUARIO WHERE nombre_usuario='operador_demo'),
 @ref varchar(40)='MANUAL-'+LEFT(CONVERT(varchar(36),NEWID()),12);
EXEC dbo.SP03_REGISTRAR_DEPOSITO @cuenta,100.00,@usuario,@ref;
```

Después de modificar los datos demo, las comprobaciones de valores exactos de
`Verificar-Consultas.ps1` deben ejecutarse en otra instalación limpia.

## Límites del alcance

El enunciado no define cálculo compuesto, año comercial de 360 días, retenciones,
comisiones, pagos interbancarios reales ni autenticación web. El código utiliza
las reglas académicas documentadas en el README. Los reversos implementados
son depósitos, retiros, transferencias internas y rechazos interbancarios;
otros productos conservan su historial y su propio proceso de liquidación/pago.

El operador de auditoría es un dato validado, mientras que el principal SQL
identifica la conexión que ejecutó la acción. No se debe interpretar un
`id_usuario` recibido como un mecanismo de autenticación independiente.
