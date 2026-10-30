/* Catálogos académicos. No reemplaza registros existentes. */
SET XACT_ABORT ON;
BEGIN TRANSACTION;
INSERT dbo.TB_TIPO_CLIENTE(nombre)
SELECT nombre FROM (VALUES('Individual'),('Juridico')) v(nombre)
WHERE NOT EXISTS(SELECT 1 FROM dbo.TB_TIPO_CLIENTE t WHERE t.nombre=v.nombre);
INSERT dbo.TB_TIPO_CUENTA(nombre)
SELECT nombre FROM (VALUES('Monetaria'),('Ahorro')) v(nombre)
WHERE NOT EXISTS(SELECT 1 FROM dbo.TB_TIPO_CUENTA t WHERE t.nombre=v.nombre);
INSERT dbo.TB_TIPO_TARJETA(nombre)
SELECT nombre FROM (VALUES('Debito'),('Credito')) v(nombre)
WHERE NOT EXISTS(SELECT 1 FROM dbo.TB_TIPO_TARJETA t WHERE t.nombre=v.nombre);
INSERT dbo.TB_MONEDA(codigo,nombre)
SELECT codigo,nombre FROM (VALUES('GTQ','Quetzal'),('USD','Dolar estadounidense')) v(codigo,nombre)
WHERE NOT EXISTS(SELECT 1 FROM dbo.TB_MONEDA t WHERE t.codigo=v.codigo);
INSERT dbo.TB_TIPO_MOVIMIENTO(nombre)
SELECT nombre FROM (VALUES('Deposito'),('Retiro'),('Transferencia enviada'),('Transferencia recibida'),
('Pago de tarjeta'),('Constitucion plazo fijo'),('Conversion enviada'),('Conversion recibida'),
('Transferencia interbancaria'),('Liquidacion plazo fijo'),('Reverso credito'),('Reverso debito'),('Consumo debito')) v(nombre)
WHERE NOT EXISTS(SELECT 1 FROM dbo.TB_TIPO_MOVIMIENTO t WHERE t.nombre=v.nombre);
INSERT dbo.TB_BANCO(nombre)
SELECT nombre FROM (VALUES('Banco Simulado A'),('Banco Simulado B')) v(nombre)
WHERE NOT EXISTS(SELECT 1 FROM dbo.TB_BANCO t WHERE t.nombre=v.nombre);
IF NOT EXISTS(SELECT 1 FROM dbo.TB_USUARIO WHERE nombre_usuario='operador_demo')
 INSERT dbo.TB_USUARIO(nombre_usuario,nombre_completo,clave_hash,estado,fecha_registro)
 VALUES('operador_demo','Operador ficticio de demostracion','SIN_ACCESO_POR_CLAVE','Activo',CONVERT(date,GETDATE()));
DECLARE @gtq int=(SELECT id_moneda FROM dbo.TB_MONEDA WHERE codigo='GTQ'),
 @usd int=(SELECT id_moneda FROM dbo.TB_MONEDA WHERE codigo='USD');
-- Cotizaciones ficticias; no son valores de mercado.
IF NOT EXISTS(SELECT 1 FROM dbo.TB_TIPO_CAMBIO WHERE id_moneda_origen=@gtq AND id_moneda_destino=@usd AND estado='Activo' AND fecha_registro<=GETDATE())
 INSERT dbo.TB_TIPO_CAMBIO(id_moneda_origen,id_moneda_destino,valor_cambio,fecha_registro,estado)
 VALUES(@gtq,@usd,0.13071895,GETDATE(),'Activo');
IF NOT EXISTS(SELECT 1 FROM dbo.TB_TIPO_CAMBIO WHERE id_moneda_origen=@usd AND id_moneda_destino=@gtq AND estado='Activo' AND fecha_registro<=GETDATE())
 INSERT dbo.TB_TIPO_CAMBIO(id_moneda_origen,id_moneda_destino,valor_cambio,fecha_registro,estado)
 VALUES(@usd,@gtq,7.65000000,GETDATE(),'Activo');
COMMIT;
