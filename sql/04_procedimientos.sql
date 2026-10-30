/* Rutinas NEOBANK. Ejecutar después de la migración y funciones.
 Las escrituras se serializan mediante un bloqueo lógico transaccional para
 evitar sobregiros, dobles consumos y referencias repetidas. Esta estrategia
 prioriza corrección y sencillez en el simulador académico; limita concurrencia.
 No constituye una plataforma bancaria de producción.
*/
CREATE OR ALTER PROCEDURE dbo.SP00_ABRIR_OPERACION
 @referencia varchar(100), @id_usuario int
AS
BEGIN
 SET NOCOUNT ON;
 IF @@TRANCOUNT=0 THROW 51000,'La operación requiere una transacción activa.',1;
 DECLARE @bloqueo int;
 EXEC @bloqueo=sys.sp_getapplock @Resource='NEOBANK_TRANSACCIONES',
  @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
 IF @bloqueo<0 THROW 51001,'No se pudo obtener el bloqueo transaccional.',1;
 IF NULLIF(LTRIM(RTRIM(@referencia)),'') IS NULL
  THROW 51002,'La referencia es obligatoria.',1;
 IF LEN(@referencia)>40 THROW 51002,'La referencia debe tener como máximo 40 caracteres.',1;
 IF DATALENGTH(@referencia)<>DATALENGTH(LTRIM(RTRIM(@referencia)))
  THROW 51002,'La referencia no debe tener espacios en los extremos.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.TB_USUARIO WHERE id_usuario=@id_usuario AND estado='Activo')
  THROW 51003,'El usuario no existe o está inactivo.',1;
 INSERT dbo.TB_OPERACION(referencia,id_usuario,fecha_operacion)
 VALUES(@referencia,@id_usuario,GETDATE());
END;
GO

CREATE OR ALTER PROCEDURE dbo.SP00_MOVIMIENTO
 @id_cuenta int,@tipo varchar(100),@monto decimal(18,6),
 @referencia varchar(50),@id_usuario int,@descripcion varchar(250)=NULL,
 @id_movimiento_original int=NULL,@id_movimiento int=NULL OUTPUT
AS
BEGIN
 SET NOCOUNT ON;
 IF @@TRANCOUNT=0 THROW 51000,'El movimiento requiere una transacción activa.',1;
 IF @monto IS NULL OR @monto<=0 OR ROUND(@monto,2)<>@monto
  THROW 51004,'El monto debe ser positivo y tener como máximo dos decimales.',1;
 DECLARE @tipo_id int=(SELECT id_tipo_movimiento FROM dbo.TB_TIPO_MOVIMIENTO WHERE nombre=@tipo);
 IF @tipo_id IS NULL THROW 51005,'No existe el tipo de movimiento.',1;
 INSERT dbo.TB_MOVIMIENTO(id_cuenta,id_tipo_movimiento,id_movimiento_original,
  referencia,fecha_movimiento,monto,estado,descripcion,id_usuario)
 VALUES(@id_cuenta,@tipo_id,@id_movimiento_original,@referencia,GETDATE(),
  @monto,'Confirmado',@descripcion,@id_usuario);
 SET @id_movimiento=CONVERT(int,SCOPE_IDENTITY());
END;
GO

/* SP01_REGISTRAR_CLIENTE
 Propósito: Registra una persona individual o jurídica y rechaza identificaciones duplicadas.
 Los importes se expresan en la moneda de la cuenta; las referencias identifican
 operaciones completas y permiten detectar solicitudes repetidas.
*/
CREATE OR ALTER PROCEDURE dbo.SP01_REGISTRAR_CLIENTE
 @id_tipo_cliente int,@nombre varchar(150),
 @cui varchar(20)=NULL,@nit varchar(20)=NULL,@telefono varchar(25)=NULL,
 @correo varchar(150)=NULL,@direccion varchar(250)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 -- Cada rutina es una unidad atómica; también admite una transacción de pruebas externa.
 BEGIN TRY
  BEGIN TRANSACTION;
  -- Serializar validaciones y reservar referencia y ejecutor cuando corresponde.
  DECLARE @bloqueo int; EXEC @bloqueo=sys.sp_getapplock @Resource='NEOBANK_TRANSACCIONES',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000; IF @bloqueo<0 THROW 51001,'No se pudo obtener el bloqueo transaccional.',1;
  
 SET @nombre=NULLIF(LTRIM(RTRIM(@nombre)),'');
 SET @cui=NULLIF(LTRIM(RTRIM(@cui)),'');
 SET @nit=NULLIF(LTRIM(RTRIM(@nit)),'');
 DECLARE @tipo varchar(100)=(SELECT nombre FROM dbo.TB_TIPO_CLIENTE WHERE id_tipo_cliente=@id_tipo_cliente);
 IF @tipo IS NULL THROW 51010,'El tipo de cliente no existe.',1;
 IF @nombre IS NULL THROW 51011,'El nombre es obligatorio.',1;
 IF @tipo='Individual' AND (@cui IS NULL OR LEN(@cui)<>13 OR @cui LIKE '%[^0-9]%')
  THROW 51012,'El cliente individual requiere CUI de 13 dígitos.',1;
 IF @tipo='Juridico' AND @nit IS NULL THROW 51013,'El cliente jurídico requiere NIT.',1;
 IF @cui IS NOT NULL AND EXISTS(SELECT 1 FROM dbo.TB_CLIENTE WHERE cui=@cui)
  THROW 51014,'El CUI ya está registrado.',1;
 IF @nit IS NOT NULL AND EXISTS(SELECT 1 FROM dbo.TB_CLIENTE WHERE nit=@nit)
  THROW 51015,'El NIT ya está registrado.',1;
 INSERT dbo.TB_CLIENTE(id_tipo_cliente,nombre,cui,nit,telefono,correo,direccion,estado,fecha_registro)
 VALUES(@id_tipo_cliente,@nombre,@cui,@nit,@telefono,@correo,@direccion,'Activo',GETDATE());
 SELECT CONVERT(int,SCOPE_IDENTITY()) AS id_cliente;
 
  
  -- Publicar juntos saldos, movimientos y auditoría; nunca una parte aislada.
  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  -- Deshacer todos los cambios de esta operación y conservar el error original.
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH;
END;
GO

/* SP02_APERTURAR_CUENTA
 Propósito: Abre una cuenta con saldo cero y la vincula a su primer titular activo.
 Los importes se expresan en la moneda de la cuenta; las referencias identifican
 operaciones completas y permiten detectar solicitudes repetidas.
*/
CREATE OR ALTER PROCEDURE dbo.SP02_APERTURAR_CUENTA
 @id_cliente int,@id_tipo_cuenta int,@id_moneda int,
 @numero_cuenta varchar(30),@id_usuario int,@referencia varchar(100)
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 -- Cada rutina es una unidad atómica; también admite una transacción de pruebas externa.
 BEGIN TRY
  BEGIN TRANSACTION;
  -- Serializar validaciones y reservar referencia y ejecutor cuando corresponde.
  EXEC dbo.SP00_ABRIR_OPERACION @referencia,@id_usuario;
  
 IF NOT EXISTS(SELECT 1 FROM dbo.TB_CLIENTE WHERE id_cliente=@id_cliente AND estado='Activo')
  THROW 51020,'El cliente debe existir y estar activo.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.TB_TIPO_CUENTA WHERE id_tipo_cuenta=@id_tipo_cuenta)
  THROW 51021,'El tipo de cuenta no existe.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.TB_MONEDA WHERE id_moneda=@id_moneda AND codigo IN('GTQ','USD'))
  THROW 51022,'La moneda debe ser GTQ o USD.',1;
 IF NULLIF(LTRIM(RTRIM(@numero_cuenta)),'') IS NULL THROW 51023,'Número de cuenta obligatorio.',1;
 INSERT dbo.TB_CUENTA(numero_cuenta,id_tipo_cuenta,id_moneda,saldo,estado,fecha_apertura)
 VALUES(@numero_cuenta,@id_tipo_cuenta,@id_moneda,0,'Activa',GETDATE());
 DECLARE @id int=CONVERT(int,SCOPE_IDENTITY());
 INSERT dbo.TB_TITULAR_CUENTA(id_cliente,id_cuenta) VALUES(@id_cliente,@id);
 SELECT @id AS id_cuenta;
 
  INSERT dbo.TB_EVENTO_AUDITORIA(referencia,id_usuario,entidad,id_entidad,detalle) VALUES(@referencia,@id_usuario,'SP02_APERTURAR_CUENTA',0,'Ejecución completada');
  -- Publicar juntos saldos, movimientos y auditoría; nunca una parte aislada.
  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  -- Deshacer todos los cambios de esta operación y conservar el error original.
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH;
END;
GO

/* SP03_REGISTRAR_DEPOSITO
 Propósito: Acredita un depósito y conserva su movimiento y usuario ejecutor.
 Los importes se expresan en la moneda de la cuenta; las referencias identifican
 operaciones completas y permiten detectar solicitudes repetidas.
*/
CREATE OR ALTER PROCEDURE dbo.SP03_REGISTRAR_DEPOSITO
@id_cuenta int,@monto decimal(18,6),@id_usuario int,@referencia varchar(100)
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 -- Cada rutina es una unidad atómica; también admite una transacción de pruebas externa.
 BEGIN TRY
  BEGIN TRANSACTION;
  -- Serializar validaciones y reservar referencia y ejecutor cuando corresponde.
  EXEC dbo.SP00_ABRIR_OPERACION @referencia,@id_usuario;
  IF @monto IS NULL OR @monto<=0 OR ROUND(@monto,2)<>@monto
 THROW 51004,'El monto debe ser positivo y tener como máximo dos decimales.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.TB_CUENTA WHERE id_cuenta=@id_cuenta AND estado='Activa')
 THROW 51030,'La cuenta no existe o no está activa.',1;
 
 -- Acreditar fondos dentro de la misma transacción que el movimiento.
 UPDATE dbo.TB_CUENTA SET saldo=saldo+@monto WHERE id_cuenta=@id_cuenta;
 EXEC dbo.SP00_MOVIMIENTO @id_cuenta,'Deposito',@monto,@referencia,@id_usuario;
 
  INSERT dbo.TB_EVENTO_AUDITORIA(referencia,id_usuario,entidad,id_entidad,detalle) VALUES(@referencia,@id_usuario,'SP03_REGISTRAR_DEPOSITO',0,'Ejecución completada');
  -- Publicar juntos saldos, movimientos y auditoría; nunca una parte aislada.
  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  -- Deshacer todos los cambios de esta operación y conservar el error original.
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH;
END;
GO

/* SP04_REGISTRAR_RETIRO
 Propósito: Debita una cuenta activa únicamente si dispone de fondos suficientes.
 Los importes se expresan en la moneda de la cuenta; las referencias identifican
 operaciones completas y permiten detectar solicitudes repetidas.
*/
CREATE OR ALTER PROCEDURE dbo.SP04_REGISTRAR_RETIRO
@id_cuenta int,@monto decimal(18,6),@id_usuario int,@referencia varchar(100)
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 -- Cada rutina es una unidad atómica; también admite una transacción de pruebas externa.
 BEGIN TRY
  BEGIN TRANSACTION;
  -- Serializar validaciones y reservar referencia y ejecutor cuando corresponde.
  EXEC dbo.SP00_ABRIR_OPERACION @referencia,@id_usuario;
  IF @monto IS NULL OR @monto<=0 OR ROUND(@monto,2)<>@monto
 THROW 51004,'El monto debe ser positivo y tener como máximo dos decimales.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.TB_CUENTA WHERE id_cuenta=@id_cuenta AND estado='Activa')
 THROW 51030,'La cuenta no existe o no está activa.',1;
 IF (SELECT saldo FROM dbo.TB_CUENTA WHERE id_cuenta=@id_cuenta)<@monto THROW 51031,'Saldo insuficiente.',1;
 -- Descontar fondos sólo después de validar estado y saldo disponible.
 UPDATE dbo.TB_CUENTA SET saldo=saldo-@monto WHERE id_cuenta=@id_cuenta;
 EXEC dbo.SP00_MOVIMIENTO @id_cuenta,'Retiro',@monto,@referencia,@id_usuario;
 
  INSERT dbo.TB_EVENTO_AUDITORIA(referencia,id_usuario,entidad,id_entidad,detalle) VALUES(@referencia,@id_usuario,'SP04_REGISTRAR_RETIRO',0,'Ejecución completada');
  -- Publicar juntos saldos, movimientos y auditoría; nunca una parte aislada.
  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  -- Deshacer todos los cambios de esta operación y conservar el error original.
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH;
END;
GO

/* SP05_TRANSFERENCIA_INTERNA
 Propósito: Mueve fondos entre cuentas de igual moneda; ambos movimientos se confirman juntos.
 Los importes se expresan en la moneda de la cuenta; las referencias identifican
 operaciones completas y permiten detectar solicitudes repetidas.
*/
CREATE OR ALTER PROCEDURE dbo.SP05_TRANSFERENCIA_INTERNA
@id_cuenta_origen int,@id_cuenta_destino int,
 @monto decimal(18,6),@id_usuario int,@referencia varchar(100)
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 -- Cada rutina es una unidad atómica; también admite una transacción de pruebas externa.
 BEGIN TRY
  BEGIN TRANSACTION;
  -- Serializar validaciones y reservar referencia y ejecutor cuando corresponde.
  EXEC dbo.SP00_ABRIR_OPERACION @referencia,@id_usuario;
  
 IF @monto IS NULL OR @monto<=0 OR ROUND(@monto,2)<>@monto
 THROW 51004,'El monto debe ser positivo y tener como máximo dos decimales.',1;
 IF @id_cuenta_origen=@id_cuenta_destino THROW 51040,'Las cuentas deben ser diferentes.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.TB_CUENTA WHERE id_cuenta=@id_cuenta_origen AND estado='Activa')
 OR NOT EXISTS(SELECT 1 FROM dbo.TB_CUENTA WHERE id_cuenta=@id_cuenta_destino AND estado='Activa')
  THROW 51041,'Ambas cuentas deben existir y estar activas.',1;
 IF (SELECT saldo FROM dbo.TB_CUENTA WHERE id_cuenta=@id_cuenta_origen)<@monto
  THROW 51031,'Saldo insuficiente.',1;
 IF (SELECT id_moneda FROM dbo.TB_CUENTA WHERE id_cuenta=@id_cuenta_origen)<>
    (SELECT id_moneda FROM dbo.TB_CUENTA WHERE id_cuenta=@id_cuenta_destino)
  THROW 51042,'Use cambio de moneda para cuentas en monedas distintas.',1;
 -- Descontar fondos sólo después de validar estado y saldo disponible.
 UPDATE dbo.TB_CUENTA SET saldo=saldo-@monto WHERE id_cuenta=@id_cuenta_origen;
 -- Acreditar fondos dentro de la misma transacción que el movimiento.
 UPDATE dbo.TB_CUENTA SET saldo=saldo+@monto WHERE id_cuenta=@id_cuenta_destino;
 -- Registrar la cabecera que identifica cuentas, referencia, importe y estado.
 INSERT dbo.TB_TRANSFERENCIA(id_cuenta_origen,id_cuenta_destino,tipo_transferencia,referencia,
  monto,fecha_transferencia,estado,id_usuario)
 VALUES(@id_cuenta_origen,@id_cuenta_destino,'Interna',@referencia,@monto,GETDATE(),'Confirmada',@id_usuario);
 DECLARE @id int=CONVERT(int,SCOPE_IDENTITY()),@debito int,@credito int,
 @refd varchar(50)=@referencia+'-D',@refc varchar(50)=@referencia+'-C';
 EXEC dbo.SP00_MOVIMIENTO @id_cuenta_origen,'Transferencia enviada',@monto,@refd,@id_usuario,
  @id_movimiento=@debito OUTPUT;
 EXEC dbo.SP00_MOVIMIENTO @id_cuenta_destino,'Transferencia recibida',@monto,@refc,@id_usuario,
  @id_movimiento=@credito OUTPUT;
 -- Vincular cada asiento con la transferencia que lo originó.
 INSERT dbo.TB_TRANSFERENCIA_MOVIMIENTO(id_transferencia,id_movimiento) VALUES(@id,@debito),(@id,@credito);
 SELECT @id AS id_transferencia;
 
  INSERT dbo.TB_EVENTO_AUDITORIA(referencia,id_usuario,entidad,id_entidad,detalle) VALUES(@referencia,@id_usuario,'SP05_TRANSFERENCIA_INTERNA',0,'Ejecución completada');
  -- Publicar juntos saldos, movimientos y auditoría; nunca una parte aislada.
  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  -- Deshacer todos los cambios de esta operación y conservar el error original.
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH;
END;
GO

/* SP06_TRANSFERENCIA_INTERBANCARIA
 Propósito: Simula el envío externo pendiente y debita los fondos comprometidos.
 Los importes se expresan en la moneda de la cuenta; las referencias identifican
 operaciones completas y permiten detectar solicitudes repetidas.
*/
CREATE OR ALTER PROCEDURE dbo.SP06_TRANSFERENCIA_INTERBANCARIA
@id_cuenta_origen int,@id_banco_destino int,
 @cuenta_externa_destino varchar(30),@monto decimal(18,6),@id_usuario int,@referencia varchar(100)
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 -- Cada rutina es una unidad atómica; también admite una transacción de pruebas externa.
 BEGIN TRY
  BEGIN TRANSACTION;
  -- Serializar validaciones y reservar referencia y ejecutor cuando corresponde.
  EXEC dbo.SP00_ABRIR_OPERACION @referencia,@id_usuario;
  
 IF @monto IS NULL OR @monto<=0 OR ROUND(@monto,2)<>@monto
 THROW 51004,'El monto debe ser positivo y tener como máximo dos decimales.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.TB_CUENTA WHERE id_cuenta=@id_cuenta_origen AND estado='Activa')
  THROW 51041,'La cuenta de origen debe estar activa.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.TB_BANCO WHERE id_banco=@id_banco_destino)
  THROW 51043,'El banco de destino no existe.',1;
 IF NULLIF(LTRIM(RTRIM(@cuenta_externa_destino)),'') IS NULL THROW 51044,'Cuenta externa obligatoria.',1;
 IF (SELECT saldo FROM dbo.TB_CUENTA WHERE id_cuenta=@id_cuenta_origen)<@monto
  THROW 51031,'Saldo insuficiente.',1;
 -- Se debita al solicitar: evita gastar fondos comprometidos en otra operación.
 -- Descontar fondos sólo después de validar estado y saldo disponible.
 UPDATE dbo.TB_CUENTA SET saldo=saldo-@monto WHERE id_cuenta=@id_cuenta_origen;
 -- Registrar la cabecera que identifica cuentas, referencia, importe y estado.
 INSERT dbo.TB_TRANSFERENCIA(id_cuenta_origen,tipo_transferencia,referencia,monto,
 fecha_transferencia,estado,id_usuario,id_banco_destino,cuenta_externa_destino)
 VALUES(@id_cuenta_origen,'Interbancaria',@referencia,@monto,GETDATE(),'Pendiente',
 @id_usuario,@id_banco_destino,@cuenta_externa_destino);
 DECLARE @id int=CONVERT(int,SCOPE_IDENTITY()),@debito int;
 EXEC dbo.SP00_MOVIMIENTO @id_cuenta_origen,'Transferencia interbancaria',@monto,@referencia,@id_usuario,
 @id_movimiento=@debito OUTPUT;
 -- Vincular cada asiento con la transferencia que lo originó.
 INSERT dbo.TB_TRANSFERENCIA_MOVIMIENTO(id_transferencia,id_movimiento) VALUES(@id,@debito);
 SELECT @id AS id_transferencia;
 
  INSERT dbo.TB_EVENTO_AUDITORIA(referencia,id_usuario,entidad,id_entidad,detalle) VALUES(@referencia,@id_usuario,'SP06_TRANSFERENCIA_INTERBANCARIA',0,'Ejecución completada');
  -- Publicar juntos saldos, movimientos y auditoría; nunca una parte aislada.
  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  -- Deshacer todos los cambios de esta operación y conservar el error original.
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH;
END;
GO

/* SP07_CAMBIO_MONEDA
 Propósito: Debita moneda origen, acredita moneda destino y guarda la cotización histórica aplicada.
 Los importes se expresan en la moneda de la cuenta; las referencias identifican
 operaciones completas y permiten detectar solicitudes repetidas.
*/
CREATE OR ALTER PROCEDURE dbo.SP07_CAMBIO_MONEDA
@id_cuenta_origen int,@id_cuenta_destino int,
 @monto decimal(18,6),@id_usuario int,@referencia varchar(100)
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 -- Cada rutina es una unidad atómica; también admite una transacción de pruebas externa.
 BEGIN TRY
  BEGIN TRANSACTION;
  -- Serializar validaciones y reservar referencia y ejecutor cuando corresponde.
  EXEC dbo.SP00_ABRIR_OPERACION @referencia,@id_usuario;
  
 IF @monto IS NULL OR @monto<=0 OR ROUND(@monto,2)<>@monto
 THROW 51004,'El monto debe ser positivo y tener como máximo dos decimales.',1;
 IF @id_cuenta_origen=@id_cuenta_destino THROW 51040,'Las cuentas deben ser diferentes.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.TB_CUENTA WHERE id_cuenta=@id_cuenta_origen AND estado='Activa')
 OR NOT EXISTS(SELECT 1 FROM dbo.TB_CUENTA WHERE id_cuenta=@id_cuenta_destino AND estado='Activa')
  THROW 51041,'Ambas cuentas deben existir y estar activas.',1;
 IF (SELECT saldo FROM dbo.TB_CUENTA WHERE id_cuenta=@id_cuenta_origen)<@monto
  THROW 51031,'Saldo insuficiente.',1;
 DECLARE @mo int=(SELECT id_moneda FROM dbo.TB_CUENTA WHERE id_cuenta=@id_cuenta_origen),
 @md int=(SELECT id_moneda FROM dbo.TB_CUENTA WHERE id_cuenta=@id_cuenta_destino),
 @id_tc int,@tasa decimal(18,8),@destino decimal(18,6),@fecha datetime=GETDATE();
 IF @mo=@md THROW 51045,'La conversión requiere monedas diferentes.',1;
 SELECT TOP(1) @id_tc=id_tipo_cambio,@tasa=valor_cambio FROM dbo.TB_TIPO_CAMBIO
 WHERE id_moneda_origen=@mo AND id_moneda_destino=@md AND estado='Activo'
 AND fecha_registro<=@fecha AND valor_cambio>0 ORDER BY fecha_registro DESC,id_tipo_cambio DESC;
 IF @id_tc IS NULL THROW 51046,'No hay tipo de cambio vigente para esta dirección.',1;
 SET @destino=CONVERT(decimal(18,6),ROUND(CONVERT(decimal(28,8),@monto)*@tasa,2));
 IF @destino<=0 THROW 51047,'El monto convertido es menor que un centavo.',1;
 -- Descontar fondos sólo después de validar estado y saldo disponible.
 UPDATE dbo.TB_CUENTA SET saldo=saldo-@monto WHERE id_cuenta=@id_cuenta_origen;
 -- Acreditar fondos dentro de la misma transacción que el movimiento.
 UPDATE dbo.TB_CUENTA SET saldo=saldo+@destino WHERE id_cuenta=@id_cuenta_destino;
 -- Guardar ambos importes y la tasa aplicada como evidencia histórica.
 INSERT dbo.TB_CONVERSION_MONEDA(id_cuenta_origen,id_cuenta_destino,id_tipo_cambio,
 referencia,monto_origen,monto_destino,tipo_cambio_aplicado,fecha_conversion,estado,id_usuario)
 VALUES(@id_cuenta_origen,@id_cuenta_destino,@id_tc,@referencia,@monto,@destino,@tasa,@fecha,'Confirmada',@id_usuario);
 DECLARE @refd varchar(50)=@referencia+'-D',@refc varchar(50)=@referencia+'-C';
 EXEC dbo.SP00_MOVIMIENTO @id_cuenta_origen,'Conversion enviada',@monto,@refd,@id_usuario;
 EXEC dbo.SP00_MOVIMIENTO @id_cuenta_destino,'Conversion recibida',@destino,@refc,@id_usuario;
 
  INSERT dbo.TB_EVENTO_AUDITORIA(referencia,id_usuario,entidad,id_entidad,detalle) VALUES(@referencia,@id_usuario,'SP07_CAMBIO_MONEDA',0,'Ejecución completada');
  -- Publicar juntos saldos, movimientos y auditoría; nunca una parte aislada.
  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  -- Deshacer todos los cambios de esta operación y conservar el error original.
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH;
END;
GO

/* SP08_CONSTITUIR_PLAZO_FIJO
 Propósito: Aparta el principal de una cuenta del cliente y registra las condiciones del plazo fijo.
 Los importes se expresan en la moneda de la cuenta; las referencias identifican
 operaciones completas y permiten detectar solicitudes repetidas.
*/
CREATE OR ALTER PROCEDURE dbo.SP08_CONSTITUIR_PLAZO_FIJO
@id_cliente int,@id_cuenta_origen int,
 @monto decimal(18,6),@tasa_interes decimal(18,6),@plazo_dias int,
 @id_usuario int,@referencia varchar(100)
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 -- Cada rutina es una unidad atómica; también admite una transacción de pruebas externa.
 BEGIN TRY
  BEGIN TRANSACTION;
  -- Serializar validaciones y reservar referencia y ejecutor cuando corresponde.
  EXEC dbo.SP00_ABRIR_OPERACION @referencia,@id_usuario;
  
 IF @monto IS NULL OR @monto<=0 OR ROUND(@monto,2)<>@monto
 THROW 51004,'El monto debe ser positivo y tener como máximo dos decimales.',1;
 IF @tasa_interes IS NULL OR @tasa_interes<0 OR @tasa_interes>100 OR @plazo_dias IS NULL OR @plazo_dias<=0 OR @plazo_dias>36500
  THROW 51050,'Tasa o plazo inválidos.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.TB_CLIENTE WHERE id_cliente=@id_cliente AND estado='Activo')
  THROW 51020,'El cliente debe estar activo.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.TB_TITULAR_CUENTA WHERE id_cliente=@id_cliente AND id_cuenta=@id_cuenta_origen)
  THROW 51051,'El cliente debe ser titular de la cuenta origen.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.TB_CUENTA WHERE id_cuenta=@id_cuenta_origen AND estado='Activa')
  THROW 51041,'La cuenta origen debe estar activa.',1;
 IF (SELECT saldo FROM dbo.TB_CUENTA WHERE id_cuenta=@id_cuenta_origen)<@monto
  THROW 51031,'Saldo insuficiente.',1;
 -- Descontar fondos sólo después de validar estado y saldo disponible.
 UPDATE dbo.TB_CUENTA SET saldo=saldo-@monto WHERE id_cuenta=@id_cuenta_origen;
 INSERT dbo.TB_PLAZO_FIJO(id_cliente,id_cuenta_origen,monto,tasa_interes,plazo_dias,
 fecha_inicio,fecha_vencimiento,estado,id_usuario,referencia)
 VALUES(@id_cliente,@id_cuenta_origen,@monto,@tasa_interes,@plazo_dias,
 CONVERT(date,GETDATE()),DATEADD(day,@plazo_dias,CONVERT(date,GETDATE())),'Activo',@id_usuario,@referencia);
 DECLARE @id int=CONVERT(int,SCOPE_IDENTITY());
 EXEC dbo.SP00_MOVIMIENTO @id_cuenta_origen,'Constitucion plazo fijo',@monto,@referencia,@id_usuario;
 SELECT @id AS id_plazo_fijo;
 
  INSERT dbo.TB_EVENTO_AUDITORIA(referencia,id_usuario,entidad,id_entidad,detalle) VALUES(@referencia,@id_usuario,'SP08_CONSTITUIR_PLAZO_FIJO',0,'Ejecución completada');
  -- Publicar juntos saldos, movimientos y auditoría; nunca una parte aislada.
  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  -- Deshacer todos los cambios de esta operación y conservar el error original.
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH;
END;
GO

/* SP09_CONSUMO_TARJETA_CREDITO
 Propósito: Incrementa la deuda de crédito sin exceder el límite ni aceptar tarjetas bloqueadas.
 Los importes se expresan en la moneda de la cuenta; las referencias identifican
 operaciones completas y permiten detectar solicitudes repetidas.
*/
CREATE OR ALTER PROCEDURE dbo.SP09_CONSUMO_TARJETA_CREDITO
@id_tarjeta int,@comercio varchar(150),
 @monto decimal(18,6),@id_usuario int,@referencia varchar(100)
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 -- Cada rutina es una unidad atómica; también admite una transacción de pruebas externa.
 BEGIN TRY
  BEGIN TRANSACTION;
  -- Serializar validaciones y reservar referencia y ejecutor cuando corresponde.
  EXEC dbo.SP00_ABRIR_OPERACION @referencia,@id_usuario;
  
 IF @monto IS NULL OR @monto<=0 OR ROUND(@monto,2)<>@monto
 THROW 51004,'El monto debe ser positivo y tener como máximo dos decimales.',1;
 IF NULLIF(LTRIM(RTRIM(@comercio)),'') IS NULL THROW 51060,'El comercio es obligatorio.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.TB_TARJETA t JOIN dbo.TB_TIPO_TARJETA tt ON tt.id_tipo_tarjeta=t.id_tipo_tarjeta
 WHERE t.id_tarjeta=@id_tarjeta AND tt.nombre='Credito' AND t.estado='Activa' AND t.fecha_vencimiento>=CONVERT(date,GETDATE()))
  THROW 51061,'La tarjeta debe ser de crédito, estar activa y no vencida.',1;
 IF (SELECT limite_credito-saldo_utilizado FROM dbo.TB_TARJETA WHERE id_tarjeta=@id_tarjeta)<@monto
  THROW 51062,'Límite de crédito insuficiente.',1;
 -- Actualizar la obligación de crédito sin perder el consumo o pago asociado.
 UPDATE dbo.TB_TARJETA SET saldo_utilizado=saldo_utilizado+@monto WHERE id_tarjeta=@id_tarjeta;
 INSERT dbo.TB_CONSUMO_TARJETA(id_tarjeta,referencia,fecha_consumo,comercio,monto,estado,id_usuario)
 VALUES(@id_tarjeta,@referencia,GETDATE(),@comercio,@monto,'Confirmado',@id_usuario);
 
  INSERT dbo.TB_EVENTO_AUDITORIA(referencia,id_usuario,entidad,id_entidad,detalle) VALUES(@referencia,@id_usuario,'SP09_CONSUMO_TARJETA_CREDITO',0,'Ejecución completada');
  -- Publicar juntos saldos, movimientos y auditoría; nunca una parte aislada.
  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  -- Deshacer todos los cambios de esta operación y conservar el error original.
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH;
END;
GO

/* SP10_PAGO_TARJETA_CREDITO
 Propósito: Debita una cuenta de la misma moneda y reduce la deuda de la tarjeta.
 Los importes se expresan en la moneda de la cuenta; las referencias identifican
 operaciones completas y permiten detectar solicitudes repetidas.
*/
CREATE OR ALTER PROCEDURE dbo.SP10_PAGO_TARJETA_CREDITO
@id_tarjeta int,@id_cuenta_origen int,
 @monto decimal(18,6),@id_usuario int,@referencia varchar(100)
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 -- Cada rutina es una unidad atómica; también admite una transacción de pruebas externa.
 BEGIN TRY
  BEGIN TRANSACTION;
  -- Serializar validaciones y reservar referencia y ejecutor cuando corresponde.
  EXEC dbo.SP00_ABRIR_OPERACION @referencia,@id_usuario;
  
 IF @monto IS NULL OR @monto<=0 OR ROUND(@monto,2)<>@monto
 THROW 51004,'El monto debe ser positivo y tener como máximo dos decimales.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.TB_CUENTA WHERE id_cuenta=@id_cuenta_origen AND estado='Activa')
  THROW 51041,'La cuenta origen debe estar activa.',1;
 DECLARE @deuda decimal(18,6),@moneda int;
 SELECT @deuda=t.saldo_utilizado,@moneda=cu.id_moneda
 FROM dbo.TB_TARJETA t JOIN dbo.TB_TIPO_TARJETA tt ON tt.id_tipo_tarjeta=t.id_tipo_tarjeta
 JOIN dbo.TB_CUENTA cu ON cu.id_cuenta=t.id_cuenta
 WHERE t.id_tarjeta=@id_tarjeta AND tt.nombre='Credito';
 IF @deuda IS NULL THROW 51063,'La tarjeta de crédito no existe o no tiene moneda asociada.',1;
 IF (SELECT id_moneda FROM dbo.TB_CUENTA WHERE id_cuenta=@id_cuenta_origen)<>@moneda
  THROW 51064,'La cuenta y la tarjeta deben utilizar la misma moneda.',1;
 IF @monto>@deuda THROW 51065,'El pago no puede superar la deuda.',1;
 IF (SELECT saldo FROM dbo.TB_CUENTA WHERE id_cuenta=@id_cuenta_origen)<@monto
  THROW 51031,'Saldo insuficiente.',1;
 -- Descontar fondos sólo después de validar estado y saldo disponible.
 UPDATE dbo.TB_CUENTA SET saldo=saldo-@monto WHERE id_cuenta=@id_cuenta_origen;
 -- Actualizar la obligación de crédito sin perder el consumo o pago asociado.
 UPDATE dbo.TB_TARJETA SET saldo_utilizado=saldo_utilizado-@monto WHERE id_tarjeta=@id_tarjeta;
 INSERT dbo.TB_PAGO_TARJETA(id_tarjeta,id_cuenta_origen,referencia,fecha_pago,monto,estado,id_usuario)
 VALUES(@id_tarjeta,@id_cuenta_origen,@referencia,GETDATE(),@monto,'Confirmado',@id_usuario);
 EXEC dbo.SP00_MOVIMIENTO @id_cuenta_origen,'Pago de tarjeta',@monto,@referencia,@id_usuario;
 
  INSERT dbo.TB_EVENTO_AUDITORIA(referencia,id_usuario,entidad,id_entidad,detalle) VALUES(@referencia,@id_usuario,'SP10_PAGO_TARJETA_CREDITO',0,'Ejecución completada');
  -- Publicar juntos saldos, movimientos y auditoría; nunca una parte aislada.
  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  -- Deshacer todos los cambios de esta operación y conservar el error original.
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH;
END;
GO

/* SP11_AGREGAR_TITULAR
 Propósito: Añade un cotitular activo conservando la relación muchos a muchos.
 Los importes se expresan en la moneda de la cuenta; las referencias identifican
 operaciones completas y permiten detectar solicitudes repetidas.
*/
CREATE OR ALTER PROCEDURE dbo.SP11_AGREGAR_TITULAR
@id_cliente int,@id_cuenta int,@id_usuario int,@referencia varchar(100)
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 -- Cada rutina es una unidad atómica; también admite una transacción de pruebas externa.
 BEGIN TRY
  BEGIN TRANSACTION;
  -- Serializar validaciones y reservar referencia y ejecutor cuando corresponde.
  EXEC dbo.SP00_ABRIR_OPERACION @referencia,@id_usuario;
  
 IF NOT EXISTS(SELECT 1 FROM dbo.TB_CLIENTE WHERE id_cliente=@id_cliente AND estado='Activo')
  THROW 51020,'El cliente debe estar activo.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.TB_CUENTA WHERE id_cuenta=@id_cuenta AND estado='Activa')
  THROW 51030,'La cuenta debe estar activa.',1;
 INSERT dbo.TB_TITULAR_CUENTA(id_cliente,id_cuenta) VALUES(@id_cliente,@id_cuenta);
 
  INSERT dbo.TB_EVENTO_AUDITORIA(referencia,id_usuario,entidad,id_entidad,detalle) VALUES(@referencia,@id_usuario,'SP11_AGREGAR_TITULAR',0,'Ejecución completada');
  -- Publicar juntos saldos, movimientos y auditoría; nunca una parte aislada.
  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  -- Deshacer todos los cambios de esta operación y conservar el error original.
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH;
END;
GO

/* SP12_EMITIR_TARJETA
 Propósito: Emite tarjeta de débito o crédito para un titular activo y fija moneda mediante su cuenta.
 Los importes se expresan en la moneda de la cuenta; las referencias identifican
 operaciones completas y permiten detectar solicitudes repetidas.
*/
CREATE OR ALTER PROCEDURE dbo.SP12_EMITIR_TARJETA
@id_cliente int,@id_cuenta int,@id_tipo_tarjeta int,
 @numero_tarjeta varchar(20),@fecha_vencimiento date,@limite_credito decimal(18,6)=NULL,
 @id_usuario int=NULL,@referencia varchar(100)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 -- Cada rutina es una unidad atómica; también admite una transacción de pruebas externa.
 BEGIN TRY
  BEGIN TRANSACTION;
  -- Serializar validaciones y reservar referencia y ejecutor cuando corresponde.
  EXEC dbo.SP00_ABRIR_OPERACION @referencia,@id_usuario;
  
 IF NOT EXISTS(SELECT 1 FROM dbo.TB_CLIENTE WHERE id_cliente=@id_cliente AND estado='Activo')
  THROW 51020,'El cliente debe estar activo.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.TB_CUENTA WHERE id_cuenta=@id_cuenta AND estado='Activa')
  THROW 51030,'La cuenta debe estar activa.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.TB_TITULAR_CUENTA WHERE id_cliente=@id_cliente AND id_cuenta=@id_cuenta)
  THROW 51051,'El cliente debe ser titular de la cuenta.',1;
 DECLARE @tipo varchar(100)=(SELECT nombre FROM dbo.TB_TIPO_TARJETA WHERE id_tipo_tarjeta=@id_tipo_tarjeta);
 IF @tipo IS NULL THROW 51066,'El tipo de tarjeta no existe.',1;
 IF @fecha_vencimiento IS NULL OR @fecha_vencimiento<=CONVERT(date,GETDATE())
  THROW 51067,'El vencimiento debe ser futuro.',1;
 IF NULLIF(LTRIM(RTRIM(@numero_tarjeta)),'') IS NULL THROW 51068,'El número es obligatorio.',1;
 IF @tipo='Credito' AND (@limite_credito IS NULL OR @limite_credito<=0 OR ROUND(@limite_credito,2)<>@limite_credito)
  THROW 51069,'El crédito requiere un límite positivo con máximo dos decimales.',1;
 IF @tipo='Debito' SET @limite_credito=NULL;
 INSERT dbo.TB_TARJETA(id_cliente,id_tipo_tarjeta,id_cuenta,numero_tarjeta,
 fecha_emision,fecha_vencimiento,limite_credito,saldo_utilizado,estado)
 VALUES(@id_cliente,@id_tipo_tarjeta,@id_cuenta,@numero_tarjeta,CONVERT(date,GETDATE()),
 @fecha_vencimiento,@limite_credito,CASE WHEN @tipo='Credito' THEN 0 ELSE NULL END,'Activa');
 SELECT CONVERT(int,SCOPE_IDENTITY()) AS id_tarjeta;
 
  INSERT dbo.TB_EVENTO_AUDITORIA(referencia,id_usuario,entidad,id_entidad,detalle) VALUES(@referencia,@id_usuario,'SP12_EMITIR_TARJETA',0,'Ejecución completada');
  -- Publicar juntos saldos, movimientos y auditoría; nunca una parte aislada.
  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  -- Deshacer todos los cambios de esta operación y conservar el error original.
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH;
END;
GO

/* SP13_CONSUMO_TARJETA_DEBITO
 Propósito: Registra un consumo de débito y descuenta fondos de la cuenta vinculada.
 Los importes se expresan en la moneda de la cuenta; las referencias identifican
 operaciones completas y permiten detectar solicitudes repetidas.
*/
CREATE OR ALTER PROCEDURE dbo.SP13_CONSUMO_TARJETA_DEBITO
@id_tarjeta int,@comercio varchar(150),
 @monto decimal(18,6),@id_usuario int,@referencia varchar(100)
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 -- Cada rutina es una unidad atómica; también admite una transacción de pruebas externa.
 BEGIN TRY
  BEGIN TRANSACTION;
  -- Serializar validaciones y reservar referencia y ejecutor cuando corresponde.
  EXEC dbo.SP00_ABRIR_OPERACION @referencia,@id_usuario;
  
 IF @monto IS NULL OR @monto<=0 OR ROUND(@monto,2)<>@monto
 THROW 51004,'El monto debe ser positivo y tener como máximo dos decimales.',1;
 DECLARE @cuenta int;
 SELECT @cuenta=t.id_cuenta FROM dbo.TB_TARJETA t
 JOIN dbo.TB_TIPO_TARJETA tt ON tt.id_tipo_tarjeta=t.id_tipo_tarjeta
 WHERE t.id_tarjeta=@id_tarjeta AND tt.nombre='Debito' AND t.estado='Activa'
 AND t.fecha_vencimiento>=CONVERT(date,GETDATE());
 IF @cuenta IS NULL THROW 51070,'La tarjeta de débito no existe, está bloqueada o vencida.',1;
 IF NULLIF(LTRIM(RTRIM(@comercio)),'') IS NULL THROW 51060,'El comercio es obligatorio.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.TB_CUENTA WHERE id_cuenta=@cuenta AND estado='Activa')
  THROW 51030,'La cuenta debe estar activa.',1;
 IF (SELECT saldo FROM dbo.TB_CUENTA WHERE id_cuenta=@cuenta)<@monto
  THROW 51031,'Saldo insuficiente.',1;
 -- Descontar fondos sólo después de validar estado y saldo disponible.
 UPDATE dbo.TB_CUENTA SET saldo=saldo-@monto WHERE id_cuenta=@cuenta;
 INSERT dbo.TB_CONSUMO_TARJETA(id_tarjeta,referencia,fecha_consumo,comercio,monto,estado,id_usuario)
 VALUES(@id_tarjeta,@referencia,GETDATE(),@comercio,@monto,'Confirmado',@id_usuario);
 EXEC dbo.SP00_MOVIMIENTO @cuenta,'Consumo debito',@monto,@referencia,@id_usuario;
 
  INSERT dbo.TB_EVENTO_AUDITORIA(referencia,id_usuario,entidad,id_entidad,detalle) VALUES(@referencia,@id_usuario,'SP13_CONSUMO_TARJETA_DEBITO',0,'Ejecución completada');
  -- Publicar juntos saldos, movimientos y auditoría; nunca una parte aislada.
  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  -- Deshacer todos los cambios de esta operación y conservar el error original.
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH;
END;
GO

/* SP14_RESOLVER_INTERBANCARIA
 Propósito: Confirma un envío pendiente o devuelve sus fondos al rechazarlo, una sola vez.
 Los importes se expresan en la moneda de la cuenta; las referencias identifican
 operaciones completas y permiten detectar solicitudes repetidas.
*/
CREATE OR ALTER PROCEDURE dbo.SP14_RESOLVER_INTERBANCARIA
@id_transferencia int,@estado varchar(20),
 @id_usuario int,@referencia varchar(100)
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 -- Cada rutina es una unidad atómica; también admite una transacción de pruebas externa.
 BEGIN TRY
  BEGIN TRANSACTION;
  -- Serializar validaciones y reservar referencia y ejecutor cuando corresponde.
  EXEC dbo.SP00_ABRIR_OPERACION @referencia,@id_usuario;
  
 IF @estado IS NULL OR @estado NOT IN('Confirmada','Rechazada')
  THROW 51071,'El resultado debe ser Confirmada o Rechazada.',1;
 DECLARE @cuenta int,@monto decimal(18,6),@original int;
 SELECT @cuenta=id_cuenta_origen,@monto=monto FROM dbo.TB_TRANSFERENCIA
 WHERE id_transferencia=@id_transferencia AND tipo_transferencia='Interbancaria' AND estado='Pendiente';
 IF @cuenta IS NULL THROW 51072,'La transferencia no existe o ya fue resuelta.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.TB_CUENTA WHERE id_cuenta=@cuenta AND estado='Activa')
  THROW 51030,'La cuenta debe estar activa para resolver la transferencia.',1;
 IF @estado='Rechazada'
 BEGIN
  -- La devolución conserva el movimiento original y requiere cuenta activa.
  -- Acreditar fondos dentro de la misma transacción que el movimiento.
 UPDATE dbo.TB_CUENTA SET saldo=saldo+@monto WHERE id_cuenta=@cuenta;
  SELECT @original=tm.id_movimiento FROM dbo.TB_TRANSFERENCIA_MOVIMIENTO tm
  JOIN dbo.TB_MOVIMIENTO m ON m.id_movimiento=tm.id_movimiento
  JOIN dbo.TB_TIPO_MOVIMIENTO t ON t.id_tipo_movimiento=m.id_tipo_movimiento
  WHERE tm.id_transferencia=@id_transferencia AND t.nombre='Transferencia interbancaria';
  EXEC dbo.SP00_MOVIMIENTO @cuenta,'Reverso credito',@monto,@referencia,@id_usuario,
   @descripcion='Devolución por transferencia interbancaria rechazada',@id_movimiento_original=@original;
 END;
 UPDATE dbo.TB_TRANSFERENCIA SET estado=@estado WHERE id_transferencia=@id_transferencia;
 INSERT dbo.TB_EVENTO_AUDITORIA(referencia,id_usuario,entidad,id_entidad,detalle)
 VALUES(@referencia,@id_usuario,'TB_TRANSFERENCIA',@id_transferencia,@estado);
 
  INSERT dbo.TB_EVENTO_AUDITORIA(referencia,id_usuario,entidad,id_entidad,detalle) VALUES(@referencia,@id_usuario,'SP14_RESOLVER_INTERBANCARIA',0,'Ejecución completada');
  -- Publicar juntos saldos, movimientos y auditoría; nunca una parte aislada.
  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  -- Deshacer todos los cambios de esta operación y conservar el error original.
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH;
END;
GO

/* SP15_LIQUIDAR_PLAZO_FIJO
 Propósito: Al vencimiento devuelve principal más interés simple; impide doble liquidación.
 Los importes se expresan en la moneda de la cuenta; las referencias identifican
 operaciones completas y permiten detectar solicitudes repetidas.
*/
CREATE OR ALTER PROCEDURE dbo.SP15_LIQUIDAR_PLAZO_FIJO
@id_plazo_fijo int,@id_usuario int,@referencia varchar(100)
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 -- Cada rutina es una unidad atómica; también admite una transacción de pruebas externa.
 BEGIN TRY
  BEGIN TRANSACTION;
  -- Serializar validaciones y reservar referencia y ejecutor cuando corresponde.
  EXEC dbo.SP00_ABRIR_OPERACION @referencia,@id_usuario;
  
 DECLARE @cuenta int,@principal decimal(18,6),@vencimiento date;
 SELECT @cuenta=id_cuenta_origen,@principal=monto,@vencimiento=fecha_vencimiento
 FROM dbo.TB_PLAZO_FIJO WHERE id_plazo_fijo=@id_plazo_fijo AND estado IN('Activo','Vencido');
 IF @cuenta IS NULL THROW 51073,'El plazo no existe o ya está liquidado.',1;
 IF @vencimiento>CONVERT(date,GETDATE()) THROW 51074,'El plazo aún no vence.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.TB_CUENTA WHERE id_cuenta=@cuenta AND estado='Activa')
  THROW 51030,'La cuenta debe estar activa para liquidar.',1;
 DECLARE @total decimal(18,6)=@principal+dbo.F02_INTERES_PLAZO_FIJO(@id_plazo_fijo);
 -- Acreditar fondos dentro de la misma transacción que el movimiento.
 UPDATE dbo.TB_CUENTA SET saldo=saldo+@total WHERE id_cuenta=@cuenta;
 UPDATE dbo.TB_PLAZO_FIJO SET estado='Liquidado',fecha_liquidacion=CONVERT(date,GETDATE())
 WHERE id_plazo_fijo=@id_plazo_fijo;
 EXEC dbo.SP00_MOVIMIENTO @cuenta,'Liquidacion plazo fijo',@total,@referencia,@id_usuario;
 
  INSERT dbo.TB_EVENTO_AUDITORIA(referencia,id_usuario,entidad,id_entidad,detalle) VALUES(@referencia,@id_usuario,'SP15_LIQUIDAR_PLAZO_FIJO',0,'Ejecución completada');
  -- Publicar juntos saldos, movimientos y auditoría; nunca una parte aislada.
  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  -- Deshacer todos los cambios de esta operación y conservar el error original.
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH;
END;
GO

/* SP16_CAMBIAR_ESTADO_PRODUCTO
 Propósito: Bloquea, reactiva o cierra productos comprobando fondos, deuda y obligaciones pendientes.
 Los importes se expresan en la moneda de la cuenta; las referencias identifican
 operaciones completas y permiten detectar solicitudes repetidas.
*/
CREATE OR ALTER PROCEDURE dbo.SP16_CAMBIAR_ESTADO_PRODUCTO
@producto varchar(10),@id int,@estado varchar(20),
 @id_usuario int,@referencia varchar(100)
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 -- Cada rutina es una unidad atómica; también admite una transacción de pruebas externa.
 BEGIN TRY
  BEGIN TRANSACTION;
  -- Serializar validaciones y reservar referencia y ejecutor cuando corresponde.
  EXEC dbo.SP00_ABRIR_OPERACION @referencia,@id_usuario;
  
 IF @producto='Cuenta'
 BEGIN
  IF @estado IS NULL OR @estado NOT IN('Activa','Bloqueada','Cerrada') THROW 51075,'Estado de cuenta inválido.',1;
  IF NOT EXISTS(SELECT 1 FROM dbo.TB_CUENTA WHERE id_cuenta=@id) THROW 51076,'La cuenta no existe.',1;
  IF EXISTS(SELECT 1 FROM dbo.TB_CUENTA WHERE id_cuenta=@id AND estado='Cerrada')
   THROW 51077,'Una cuenta cerrada no puede reabrirse.',1;
  IF @estado='Cerrada' AND (
   EXISTS(SELECT 1 FROM dbo.TB_CUENTA WHERE id_cuenta=@id AND saldo<>0) OR
   EXISTS(SELECT 1 FROM dbo.TB_TRANSFERENCIA WHERE id_cuenta_origen=@id AND estado='Pendiente') OR
   EXISTS(SELECT 1 FROM dbo.TB_PLAZO_FIJO WHERE id_cuenta_origen=@id AND estado='Activo') OR
   EXISTS(SELECT 1 FROM dbo.TB_TARJETA WHERE id_cuenta=@id AND (saldo_utilizado>0 OR estado='Activa')))
   THROW 51078,'No se puede cerrar una cuenta con fondos o productos pendientes.',1;
  UPDATE dbo.TB_CUENTA SET estado=@estado WHERE id_cuenta=@id;
 END
 ELSE IF @producto='Tarjeta'
 BEGIN
  IF @estado IS NULL OR @estado NOT IN('Activa','Bloqueada','Cancelada') THROW 51079,'Estado de tarjeta inválido.',1;
  IF NOT EXISTS(SELECT 1 FROM dbo.TB_TARJETA WHERE id_tarjeta=@id) THROW 51080,'La tarjeta no existe.',1;
  IF EXISTS(SELECT 1 FROM dbo.TB_TARJETA WHERE id_tarjeta=@id AND estado='Cancelada')
   THROW 51081,'Una tarjeta cancelada no puede reactivarse.',1;
  IF @estado='Cancelada' AND EXISTS(SELECT 1 FROM dbo.TB_TARJETA WHERE id_tarjeta=@id AND saldo_utilizado<>0)
   THROW 51082,'La tarjeta tiene deuda pendiente.',1;
  IF @estado='Activa' AND EXISTS(SELECT 1 FROM dbo.TB_TARJETA t JOIN dbo.TB_CUENTA c ON c.id_cuenta=t.id_cuenta
   WHERE t.id_tarjeta=@id AND (c.estado<>'Activa' OR t.fecha_vencimiento<CONVERT(date,GETDATE())))
   THROW 51083,'La tarjeta está vencida o su cuenta no está activa.',1;
  UPDATE dbo.TB_TARJETA SET estado=@estado WHERE id_tarjeta=@id;
 END
 ELSE THROW 51084,'Producto inválido. Use Cuenta o Tarjeta.',1;
 INSERT dbo.TB_EVENTO_AUDITORIA(referencia,id_usuario,entidad,id_entidad,detalle)
 VALUES(@referencia,@id_usuario,@producto,@id,@estado);
 
  INSERT dbo.TB_EVENTO_AUDITORIA(referencia,id_usuario,entidad,id_entidad,detalle) VALUES(@referencia,@id_usuario,'SP16_CAMBIAR_ESTADO_PRODUCTO',0,'Ejecución completada');
  -- Publicar juntos saldos, movimientos y auditoría; nunca una parte aislada.
  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  -- Deshacer todos los cambios de esta operación y conservar el error original.
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH;
END;
GO

/* SP17_REVERSAR_MOVIMIENTO
 Propósito: Compensa un depósito o retiro con un movimiento nuevo que referencia al original.
 Los importes se expresan en la moneda de la cuenta; las referencias identifican
 operaciones completas y permiten detectar solicitudes repetidas.
*/
CREATE OR ALTER PROCEDURE dbo.SP17_REVERSAR_MOVIMIENTO
@id_movimiento_original int,@motivo varchar(250),
 @id_usuario int,@referencia varchar(100)
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 -- Cada rutina es una unidad atómica; también admite una transacción de pruebas externa.
 BEGIN TRY
  BEGIN TRANSACTION;
  -- Serializar validaciones y reservar referencia y ejecutor cuando corresponde.
  EXEC dbo.SP00_ABRIR_OPERACION @referencia,@id_usuario;
  
 DECLARE @cuenta int,@monto decimal(18,6),@tipo varchar(100);
 SELECT @cuenta=m.id_cuenta,@monto=m.monto,@tipo=t.nombre
 FROM dbo.TB_MOVIMIENTO m JOIN dbo.TB_TIPO_MOVIMIENTO t ON t.id_tipo_movimiento=m.id_tipo_movimiento
 WHERE m.id_movimiento=@id_movimiento_original AND m.estado='Confirmado';
 IF @cuenta IS NULL THROW 51085,'El movimiento confirmado no existe.',1;
 IF @tipo NOT IN('Deposito','Retiro') THROW 51086,'Use reverso de transferencia o el proceso específico del producto.',1;
 IF EXISTS(SELECT 1 FROM dbo.TB_MOVIMIENTO WHERE id_movimiento_original=@id_movimiento_original)
  THROW 51087,'El movimiento ya fue reversado.',1;
 IF NULLIF(LTRIM(RTRIM(@motivo)),'') IS NULL THROW 51088,'El motivo es obligatorio.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.TB_CUENTA WHERE id_cuenta=@cuenta AND estado='Activa')
  THROW 51030,'La cuenta debe estar activa.',1;
 IF @tipo='Deposito'
 BEGIN
  IF (SELECT saldo FROM dbo.TB_CUENTA WHERE id_cuenta=@cuenta)<@monto THROW 51031,'Saldo insuficiente para reversar.',1;
  -- Descontar fondos sólo después de validar estado y saldo disponible.
 UPDATE dbo.TB_CUENTA SET saldo=saldo-@monto WHERE id_cuenta=@cuenta;
  EXEC dbo.SP00_MOVIMIENTO @cuenta,'Reverso debito',@monto,@referencia,@id_usuario,@motivo,@id_movimiento_original;
 END
 ELSE
 BEGIN
  -- Acreditar fondos dentro de la misma transacción que el movimiento.
 UPDATE dbo.TB_CUENTA SET saldo=saldo+@monto WHERE id_cuenta=@cuenta;
  EXEC dbo.SP00_MOVIMIENTO @cuenta,'Reverso credito',@monto,@referencia,@id_usuario,@motivo,@id_movimiento_original;
 END;
 
  INSERT dbo.TB_EVENTO_AUDITORIA(referencia,id_usuario,entidad,id_entidad,detalle) VALUES(@referencia,@id_usuario,'SP17_REVERSAR_MOVIMIENTO',0,'Ejecución completada');
  -- Publicar juntos saldos, movimientos y auditoría; nunca una parte aislada.
  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  -- Deshacer todos los cambios de esta operación y conservar el error original.
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH;
END;
GO

/* SP18_REVERSAR_TRANSFERENCIA_INTERNA
 Propósito: Compensa ambos lados de una transferencia sin borrar ni modificar los movimientos originales.
 Los importes se expresan en la moneda de la cuenta; las referencias identifican
 operaciones completas y permiten detectar solicitudes repetidas.
*/
CREATE OR ALTER PROCEDURE dbo.SP18_REVERSAR_TRANSFERENCIA_INTERNA
@id_transferencia int,@motivo varchar(250),
 @id_usuario int,@referencia varchar(100)
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 -- Cada rutina es una unidad atómica; también admite una transacción de pruebas externa.
 BEGIN TRY
  BEGIN TRANSACTION;
  -- Serializar validaciones y reservar referencia y ejecutor cuando corresponde.
  EXEC dbo.SP00_ABRIR_OPERACION @referencia,@id_usuario;
  
 DECLARE @origen int,@destino int,@monto decimal(18,6),@debito int,@credito int;
 SELECT @origen=id_cuenta_origen,@destino=id_cuenta_destino,@monto=monto
 FROM dbo.TB_TRANSFERENCIA WHERE id_transferencia=@id_transferencia
 AND tipo_transferencia='Interna' AND estado='Confirmada';
 IF @origen IS NULL THROW 51089,'La transferencia interna confirmada no existe.',1;
 IF NULLIF(LTRIM(RTRIM(@motivo)),'') IS NULL THROW 51088,'El motivo es obligatorio.',1;
 IF EXISTS(SELECT 1 FROM dbo.TB_REVERSO_TRANSFERENCIA WHERE id_transferencia=@id_transferencia)
  THROW 51087,'La transferencia ya fue reversada.',1;
 IF EXISTS(SELECT 1 FROM dbo.TB_CUENTA WHERE id_cuenta IN(@origen,@destino) AND estado<>'Activa')
  THROW 51041,'Ambas cuentas deben estar activas.',1;
 IF (SELECT saldo FROM dbo.TB_CUENTA WHERE id_cuenta=@destino)<@monto THROW 51031,'Saldo insuficiente en destino para reversar.',1;
 SELECT @debito=MAX(CASE WHEN m.id_cuenta=@origen THEN m.id_movimiento END),
 @credito=MAX(CASE WHEN m.id_cuenta=@destino THEN m.id_movimiento END)
 FROM dbo.TB_TRANSFERENCIA_MOVIMIENTO tm JOIN dbo.TB_MOVIMIENTO m ON m.id_movimiento=tm.id_movimiento
 WHERE tm.id_transferencia=@id_transferencia;
 -- Descontar fondos sólo después de validar estado y saldo disponible.
 UPDATE dbo.TB_CUENTA SET saldo=saldo-@monto WHERE id_cuenta=@destino;
 -- Acreditar fondos dentro de la misma transacción que el movimiento.
 UPDATE dbo.TB_CUENTA SET saldo=saldo+@monto WHERE id_cuenta=@origen;
 DECLARE @refd varchar(50)=@referencia+'-D',@refc varchar(50)=@referencia+'-C';
 EXEC dbo.SP00_MOVIMIENTO @destino,'Reverso debito',@monto,@refd,@id_usuario,@motivo,@credito;
 EXEC dbo.SP00_MOVIMIENTO @origen,'Reverso credito',@monto,@refc,@id_usuario,@motivo,@debito;
 INSERT dbo.TB_REVERSO_TRANSFERENCIA(id_transferencia,referencia,motivo,id_usuario)
 VALUES(@id_transferencia,@referencia,@motivo,@id_usuario);
 
  INSERT dbo.TB_EVENTO_AUDITORIA(referencia,id_usuario,entidad,id_entidad,detalle) VALUES(@referencia,@id_usuario,'SP18_REVERSAR_TRANSFERENCIA_INTERNA',0,'Ejecución completada');
  -- Publicar juntos saldos, movimientos y auditoría; nunca una parte aislada.
  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  -- Deshacer todos los cambios de esta operación y conservar el error original.
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH;
END;
GO

/* SP19_REGISTRAR_USUARIO
 Propósito: Registra un usuario de auditoría; no crea un login ni una contraseña de SQL Server.
 Los importes se expresan en la moneda de la cuenta; las referencias identifican
 operaciones completas y permiten detectar solicitudes repetidas.
*/
CREATE OR ALTER PROCEDURE dbo.SP19_REGISTRAR_USUARIO
@nombre_usuario varchar(100),@nombre_completo varchar(150),
 @id_usuario int,@referencia varchar(100)
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 -- Cada rutina es una unidad atómica; también admite una transacción de pruebas externa.
 BEGIN TRY
  BEGIN TRANSACTION;
  -- Serializar validaciones y reservar referencia y ejecutor cuando corresponde.
  EXEC dbo.SP00_ABRIR_OPERACION @referencia,@id_usuario;
  
 IF NULLIF(LTRIM(RTRIM(@nombre_usuario)),'') IS NULL OR NULLIF(LTRIM(RTRIM(@nombre_completo)),'') IS NULL
  THROW 51090,'Nombre de usuario y nombre completo obligatorios.',1;
 -- Usuarios de auditoría, sin acceso mediante contraseña. La conexión utiliza
 -- autenticación de Windows de SQL Server, no este campo heredado.
 INSERT dbo.TB_USUARIO(nombre_usuario,nombre_completo,clave_hash,estado,fecha_registro)
 VALUES(@nombre_usuario,@nombre_completo,'SIN_ACCESO_POR_CLAVE','Activo',CONVERT(date,GETDATE()));
 DECLARE @id int=CONVERT(int,SCOPE_IDENTITY());
 INSERT dbo.TB_EVENTO_AUDITORIA(referencia,id_usuario,entidad,id_entidad,detalle)
 VALUES(@referencia,@id_usuario,'TB_USUARIO',@id,'Registro de usuario de auditoría');
 SELECT @id AS id_usuario;
 
  INSERT dbo.TB_EVENTO_AUDITORIA(referencia,id_usuario,entidad,id_entidad,detalle) VALUES(@referencia,@id_usuario,'SP19_REGISTRAR_USUARIO',0,'Ejecución completada');
  -- Publicar juntos saldos, movimientos y auditoría; nunca una parte aislada.
  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  -- Deshacer todos los cambios de esta operación y conservar el error original.
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH;
END;
GO

/* SP20_REGISTRAR_TIPO_CAMBIO
 Propósito: Añade una cotización ficticia nueva conservando el historial de las anteriores.
 Los importes se expresan en la moneda de la cuenta; las referencias identifican
 operaciones completas y permiten detectar solicitudes repetidas.
*/
CREATE OR ALTER PROCEDURE dbo.SP20_REGISTRAR_TIPO_CAMBIO
@id_moneda_origen int,@id_moneda_destino int,
 @valor_cambio decimal(18,8),@id_usuario int,@referencia varchar(100)
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 -- Cada rutina es una unidad atómica; también admite una transacción de pruebas externa.
 BEGIN TRY
  BEGIN TRANSACTION;
  -- Serializar validaciones y reservar referencia y ejecutor cuando corresponde.
  EXEC dbo.SP00_ABRIR_OPERACION @referencia,@id_usuario;
  
 IF @id_moneda_origen=@id_moneda_destino OR @valor_cambio IS NULL OR @valor_cambio<=0
  THROW 51091,'Monedas o tipo de cambio inválidos.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.TB_MONEDA WHERE id_moneda=@id_moneda_origen AND codigo IN('GTQ','USD'))
 OR NOT EXISTS(SELECT 1 FROM dbo.TB_MONEDA WHERE id_moneda=@id_moneda_destino AND codigo IN('GTQ','USD'))
  THROW 51022,'Las monedas deben ser GTQ y USD.',1;
 INSERT dbo.TB_TIPO_CAMBIO(id_moneda_origen,id_moneda_destino,valor_cambio,fecha_registro,estado)
 VALUES(@id_moneda_origen,@id_moneda_destino,@valor_cambio,GETDATE(),'Activo');
 DECLARE @id int=CONVERT(int,SCOPE_IDENTITY());
 INSERT dbo.TB_EVENTO_AUDITORIA(referencia,id_usuario,entidad,id_entidad,detalle)
 VALUES(@referencia,@id_usuario,'TB_TIPO_CAMBIO',@id,'Nueva cotización');
 SELECT @id AS id_tipo_cambio;
 
  INSERT dbo.TB_EVENTO_AUDITORIA(referencia,id_usuario,entidad,id_entidad,detalle) VALUES(@referencia,@id_usuario,'SP20_REGISTRAR_TIPO_CAMBIO',0,'Ejecución completada');
  -- Publicar juntos saldos, movimientos y auditoría; nunca una parte aislada.
  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  -- Deshacer todos los cambios de esta operación y conservar el error original.
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH;
END;
GO
