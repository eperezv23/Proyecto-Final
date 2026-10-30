/* Datos íntegramente ficticios. Las referencias DEMO-* permiten ejecutarlo
   otra vez sin repetir los movimientos ya registrados. */
SET NOCOUNT ON;
DECLARE @usuario int=(SELECT id_usuario FROM dbo.TB_USUARIO WHERE nombre_usuario='operador_demo'),
 @individual int=(SELECT id_tipo_cliente FROM dbo.TB_TIPO_CLIENTE WHERE nombre='Individual'),
 @juridico int=(SELECT id_tipo_cliente FROM dbo.TB_TIPO_CLIENTE WHERE nombre='Juridico'),
 @monetaria int=(SELECT id_tipo_cuenta FROM dbo.TB_TIPO_CUENTA WHERE nombre='Monetaria'),
 @ahorro int=(SELECT id_tipo_cuenta FROM dbo.TB_TIPO_CUENTA WHERE nombre='Ahorro'),
 @gtq int=(SELECT id_moneda FROM dbo.TB_MONEDA WHERE codigo='GTQ'),
 @usd int=(SELECT id_moneda FROM dbo.TB_MONEDA WHERE codigo='USD'),
 @credito int=(SELECT id_tipo_tarjeta FROM dbo.TB_TIPO_TARJETA WHERE nombre='Credito'),
 @debito int=(SELECT id_tipo_tarjeta FROM dbo.TB_TIPO_TARJETA WHERE nombre='Debito'),
 @banco int=(SELECT id_banco FROM dbo.TB_BANCO WHERE nombre='Banco Simulado A');
DECLARE @i int=1,@cui varchar(20),@cliente int,@cuenta int,@dolares int,@numero varchar(30),
 @nombre varchar(150),@ref varchar(100),@monto decimal(18,6);
WHILE @i<=7
BEGIN
 SET @cui='990000000000'+CONVERT(varchar(1),@i);
 SET @nombre='Cliente Ficticio '+CONVERT(varchar(1),@i);
 IF NOT EXISTS(SELECT 1 FROM dbo.TB_CLIENTE WHERE cui=@cui)
  EXEC dbo.SP01_REGISTRAR_CLIENTE @individual,@nombre,@cui;
 SELECT @cliente=id_cliente FROM dbo.TB_CLIENTE WHERE cui=@cui;
 SET @numero='DEMO-GTQ-'+CONVERT(varchar(1),@i);
 SET @ref='DEMO-ABRIR-GTQ-'+CONVERT(varchar(1),@i);
 IF NOT EXISTS(SELECT 1 FROM dbo.TB_CUENTA WHERE numero_cuenta=@numero)
  EXEC dbo.SP02_APERTURAR_CUENTA @cliente,@monetaria,@gtq,@numero,@usuario,@ref;
 SELECT @cuenta=id_cuenta FROM dbo.TB_CUENTA WHERE numero_cuenta=@numero;
 SET @numero='DEMO-USD-'+CONVERT(varchar(1),@i);
 SET @ref='DEMO-ABRIR-USD-'+CONVERT(varchar(1),@i);
 IF NOT EXISTS(SELECT 1 FROM dbo.TB_CUENTA WHERE numero_cuenta=@numero)
  EXEC dbo.SP02_APERTURAR_CUENTA @cliente,@ahorro,@usd,@numero,@usuario,@ref;
 SELECT @dolares=id_cuenta FROM dbo.TB_CUENTA WHERE numero_cuenta=@numero;
 SET @monto=2000*@i;
 SET @ref='DEMO-DEPOSITO-GTQ-'+CONVERT(varchar(1),@i);
 IF NOT EXISTS(SELECT 1 FROM dbo.TB_OPERACION WHERE referencia=@ref)
  EXEC dbo.SP03_REGISTRAR_DEPOSITO @cuenta,@monto,@usuario,@ref;
 SET @monto=100*@i;
 SET @ref='DEMO-DEPOSITO-USD-'+CONVERT(varchar(1),@i);
 IF NOT EXISTS(SELECT 1 FROM dbo.TB_OPERACION WHERE referencia=@ref)
  EXEC dbo.SP03_REGISTRAR_DEPOSITO @dolares,@monto,@usuario,@ref;
 SET @i+=1;
END;
IF NOT EXISTS(SELECT 1 FROM dbo.TB_CLIENTE WHERE nit='DEMO-JURIDICO')
 EXEC dbo.SP01_REGISTRAR_CLIENTE @id_tipo_cliente=@juridico,@nombre='Empresa Ficticia Demo',@nit='DEMO-JURIDICO';
DECLARE @c1 int=(SELECT id_cliente FROM dbo.TB_CLIENTE WHERE cui='9900000000001'),
 @c2 int=(SELECT id_cliente FROM dbo.TB_CLIENTE WHERE cui='9900000000002'),
 @a int=(SELECT id_cuenta FROM dbo.TB_CUENTA WHERE numero_cuenta='DEMO-GTQ-1'),
 @b int=(SELECT id_cuenta FROM dbo.TB_CUENTA WHERE numero_cuenta='DEMO-GTQ-2'),
 @d int=(SELECT id_cuenta FROM dbo.TB_CUENTA WHERE numero_cuenta='DEMO-USD-1');
IF NOT EXISTS(SELECT 1 FROM dbo.TB_TITULAR_CUENTA WHERE id_cliente=@c2 AND id_cuenta=@a)
 EXEC dbo.SP11_AGREGAR_TITULAR @c2,@a,@usuario,'DEMO-TITULAR-COMPARTIDO';
IF NOT EXISTS(SELECT 1 FROM dbo.TB_CUENTA WHERE numero_cuenta='DEMO-SIN-MOVIMIENTOS')
 EXEC dbo.SP02_APERTURAR_CUENTA @c1,@ahorro,@gtq,'DEMO-SIN-MOVIMIENTOS',@usuario,'DEMO-ABRIR-SIN-MOV';
IF NOT EXISTS(SELECT 1 FROM dbo.TB_OPERACION WHERE referencia='DEMO-RETIRO')
 EXEC dbo.SP04_REGISTRAR_RETIRO @a,50,@usuario,'DEMO-RETIRO';
IF NOT EXISTS(SELECT 1 FROM dbo.TB_OPERACION WHERE referencia='DEMO-TRANSFERENCIA')
 EXEC dbo.SP05_TRANSFERENCIA_INTERNA @a,@b,100,@usuario,'DEMO-TRANSFERENCIA';
IF NOT EXISTS(SELECT 1 FROM dbo.TB_OPERACION WHERE referencia='DEMO-CONVERSION')
 EXEC dbo.SP07_CAMBIO_MONEDA @a,@d,765,@usuario,'DEMO-CONVERSION';
IF NOT EXISTS(SELECT 1 FROM dbo.TB_OPERACION WHERE referencia='DEMO-PLAZO')
 EXEC dbo.SP08_CONSTITUIR_PLAZO_FIJO @c1,@a,500,6,15,@usuario,'DEMO-PLAZO';
IF NOT EXISTS(SELECT 1 FROM dbo.TB_TARJETA WHERE numero_tarjeta='DEMO-CREDITO-001')
 EXEC dbo.SP12_EMITIR_TARJETA @c1,@a,@credito,'DEMO-CREDITO-001','2099-12-31',1000,@usuario,'DEMO-EMITIR-CREDITO';
DECLARE @tarjeta int=(SELECT id_tarjeta FROM dbo.TB_TARJETA WHERE numero_tarjeta='DEMO-CREDITO-001');
IF NOT EXISTS(SELECT 1 FROM dbo.TB_OPERACION WHERE referencia='DEMO-CONSUMO')
 EXEC dbo.SP09_CONSUMO_TARJETA_CREDITO @tarjeta,'Comercio Ficticio',900,@usuario,'DEMO-CONSUMO';
IF NOT EXISTS(SELECT 1 FROM dbo.TB_OPERACION WHERE referencia='DEMO-PAGO')
 EXEC dbo.SP10_PAGO_TARJETA_CREDITO @tarjeta,@a,50,@usuario,'DEMO-PAGO';
IF NOT EXISTS(SELECT 1 FROM dbo.TB_TARJETA WHERE numero_tarjeta='DEMO-DEBITO-001')
 EXEC dbo.SP12_EMITIR_TARJETA @c1,@a,@debito,'DEMO-DEBITO-001','2099-12-31',NULL,@usuario,'DEMO-EMITIR-DEBITO';
IF NOT EXISTS(SELECT 1 FROM dbo.TB_OPERACION WHERE referencia='DEMO-INTER-PENDIENTE')
 EXEC dbo.SP06_TRANSFERENCIA_INTERBANCARIA @b,@banco,'EXTERNA-FICTICIA',50,@usuario,'DEMO-INTER-PENDIENTE';
IF NOT EXISTS(SELECT 1 FROM dbo.TB_OPERACION WHERE referencia='DEMO-INTER-CONFIRMADA')
 EXEC dbo.SP06_TRANSFERENCIA_INTERBANCARIA @b,@banco,'EXTERNA-FICTICIA',50,@usuario,'DEMO-INTER-CONFIRMADA';
DECLARE @tr int=(SELECT id_transferencia FROM dbo.TB_TRANSFERENCIA WHERE referencia='DEMO-INTER-CONFIRMADA');
IF NOT EXISTS(SELECT 1 FROM dbo.TB_OPERACION WHERE referencia='DEMO-CONFIRMAR')
 EXEC dbo.SP14_RESOLVER_INTERBANCARIA @tr,'Confirmada',@usuario,'DEMO-CONFIRMAR';
IF NOT EXISTS(SELECT 1 FROM dbo.TB_OPERACION WHERE referencia='DEMO-INTER-RECHAZADA')
 EXEC dbo.SP06_TRANSFERENCIA_INTERBANCARIA @b,@banco,'EXTERNA-FICTICIA',50,@usuario,'DEMO-INTER-RECHAZADA';
SELECT @tr=id_transferencia FROM dbo.TB_TRANSFERENCIA WHERE referencia='DEMO-INTER-RECHAZADA';
IF NOT EXISTS(SELECT 1 FROM dbo.TB_OPERACION WHERE referencia='DEMO-RECHAZAR')
 EXEC dbo.SP14_RESOLVER_INTERBANCARIA @tr,'Rechazada',@usuario,'DEMO-RECHAZAR';
