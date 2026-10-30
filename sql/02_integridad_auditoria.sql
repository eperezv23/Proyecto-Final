/* Migración aditiva. Revisar contra el inventario restaurado antes de ejecutar.
   No elimina tablas ni datos del proyecto original. */
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 IF OBJECT_ID('dbo.TB_OPERACION','U') IS NULL
 CREATE TABLE dbo.TB_OPERACION(
  referencia varchar(40) NOT NULL CONSTRAINT PK_TB_OPERACION PRIMARY KEY,
  id_usuario int NOT NULL CONSTRAINT FK_OPERACION_USUARIO REFERENCES dbo.TB_USUARIO(id_usuario),
  fecha_operacion datetime2 NOT NULL CONSTRAINT DF_OPERACION_FECHA DEFAULT SYSDATETIME(),
  principal_sql sysname NOT NULL CONSTRAINT DF_OPERACION_PRINCIPAL DEFAULT ORIGINAL_LOGIN()
 );
 IF OBJECT_ID('dbo.TB_EVENTO_AUDITORIA','U') IS NULL
 CREATE TABLE dbo.TB_EVENTO_AUDITORIA(
  id_evento bigint IDENTITY PRIMARY KEY,
  referencia varchar(40) NULL REFERENCES dbo.TB_OPERACION(referencia),
  id_usuario int NULL REFERENCES dbo.TB_USUARIO(id_usuario),
  entidad varchar(100) NOT NULL,id_entidad int NOT NULL,detalle varchar(250) NOT NULL,
  fecha datetime2 NOT NULL CONSTRAINT DF_EVENTO_FECHA DEFAULT SYSDATETIME(),
  principal_sql sysname NOT NULL CONSTRAINT DF_EVENTO_PRINCIPAL DEFAULT ORIGINAL_LOGIN()
 );
 IF OBJECT_ID('dbo.TB_REVERSO_TRANSFERENCIA','U') IS NULL
 CREATE TABLE dbo.TB_REVERSO_TRANSFERENCIA(
  id_transferencia int NOT NULL PRIMARY KEY REFERENCES dbo.TB_TRANSFERENCIA(id_transferencia),
  referencia varchar(40) NOT NULL UNIQUE REFERENCES dbo.TB_OPERACION(referencia),
  motivo varchar(250) NOT NULL,id_usuario int NOT NULL REFERENCES dbo.TB_USUARIO(id_usuario),
  fecha datetime2 NOT NULL DEFAULT SYSDATETIME()
 );
 IF COL_LENGTH('dbo.TB_PLAZO_FIJO','referencia') IS NULL
  ALTER TABLE dbo.TB_PLAZO_FIJO ADD referencia varchar(40) NULL;
 IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.TB_PLAZO_FIJO') AND name='UX_PLAZO_REFERENCIA')
  EXEC(N'CREATE UNIQUE INDEX UX_PLAZO_REFERENCIA ON dbo.TB_PLAZO_FIJO(referencia) WHERE referencia IS NOT NULL;');
 IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.TB_CLIENTE') AND name='UX_CLIENTE_CUI_NO_NULO')
  CREATE UNIQUE INDEX UX_CLIENTE_CUI_NO_NULO ON dbo.TB_CLIENTE(cui) WHERE cui IS NOT NULL;
 IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.TB_CLIENTE') AND name='UX_CLIENTE_NIT_NO_NULO')
  CREATE UNIQUE INDEX UX_CLIENTE_NIT_NO_NULO ON dbo.TB_CLIENTE(nit) WHERE nit IS NOT NULL;
 IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.TB_MOVIMIENTO') AND name='IX_MOVIMIENTO_CUENTA_FECHA')
  CREATE INDEX IX_MOVIMIENTO_CUENTA_FECHA ON dbo.TB_MOVIMIENTO(id_cuenta,fecha_movimiento,id_movimiento)
  INCLUDE(monto,estado,id_tipo_movimiento);
 IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.TB_MOVIMIENTO') AND name='UX_MOVIMIENTO_REVERSO')
  CREATE UNIQUE INDEX UX_MOVIMIENTO_REVERSO ON dbo.TB_MOVIMIENTO(id_movimiento_original)
  WHERE id_movimiento_original IS NOT NULL;
 INSERT dbo.TB_TIPO_MOVIMIENTO(nombre)
 SELECT v.nombre FROM (VALUES('Transferencia interbancaria'),('Liquidacion plazo fijo'),
 ('Reverso credito'),('Reverso debito'),('Consumo debito')) v(nombre)
 WHERE NOT EXISTS(SELECT 1 FROM dbo.TB_TIPO_MOVIMIENTO t WHERE t.nombre=v.nombre);
 IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE name='CK_CLIENTE_IDENTIFICACION')
  ALTER TABLE dbo.TB_CLIENTE WITH CHECK ADD CONSTRAINT CK_CLIENTE_IDENTIFICACION
  CHECK((cui IS NULL OR (LEN(cui)=13 AND cui NOT LIKE '%[^0-9]%')) AND
    (cui IS NOT NULL OR nit IS NOT NULL));
 IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE name='CK_CLIENTE_ESTADO')
  ALTER TABLE dbo.TB_CLIENTE WITH CHECK ADD CONSTRAINT CK_CLIENTE_ESTADO
  CHECK(estado IN('Activo','Inactivo','Bloqueado'));
 IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE name='CK_TARJETA_SALDOS_COMPLETOS')
  ALTER TABLE dbo.TB_TARJETA WITH CHECK ADD CONSTRAINT CK_TARJETA_SALDOS_COMPLETOS
  CHECK((limite_credito IS NULL AND saldo_utilizado IS NULL) OR
   (limite_credito IS NOT NULL AND saldo_utilizado IS NOT NULL AND limite_credito>0
    AND saldo_utilizado>=0 AND saldo_utilizado<=limite_credito));
 IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE name='CK_TRANSFERENCIA_DISTINTAS')
  ALTER TABLE dbo.TB_TRANSFERENCIA WITH CHECK ADD CONSTRAINT CK_TRANSFERENCIA_DISTINTAS
  CHECK(id_cuenta_destino IS NULL OR id_cuenta_destino<>id_cuenta_origen);
 IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('dbo.TB_TARJETA') AND name='id_cuenta' AND is_nullable=1)
  ALTER TABLE dbo.TB_TARJETA ALTER COLUMN id_cuenta int NOT NULL;
 COMMIT;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
GO
CREATE OR ALTER TRIGGER dbo.TR_MOVIMIENTO_INMUTABLE
ON dbo.TB_MOVIMIENTO AFTER UPDATE,DELETE
AS
BEGIN
 SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM deleted WHERE estado='Confirmado')
  THROW 51100,'Los movimientos confirmados son inmutables. Registre un reverso.',1;
END;
GO
CREATE OR ALTER TRIGGER dbo.TR_AUDITORIA_INMUTABLE
ON dbo.TB_EVENTO_AUDITORIA AFTER UPDATE,DELETE
AS
BEGIN
 SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM deleted) THROW 51101,'La auditoría no puede alterarse ni eliminarse.',1;
END;
GO
CREATE OR ALTER TRIGGER dbo.TR_OPERACION_INMUTABLE
ON dbo.TB_OPERACION AFTER UPDATE,DELETE
AS
BEGIN
 SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM deleted) THROW 51102,'El registro de operaciones es inmutable.',1;
END;
GO
CREATE OR ALTER TRIGGER dbo.TR_CLIENTE_AUDITORIA
ON dbo.TB_CLIENTE AFTER INSERT,UPDATE
AS
BEGIN
 SET NOCOUNT ON;
 INSERT dbo.TB_EVENTO_AUDITORIA(entidad,id_entidad,detalle)
 SELECT 'TB_CLIENTE',i.id_cliente,
 CASE WHEN d.id_cliente IS NULL THEN 'Registro de cliente' ELSE 'Actualización de cliente' END
 FROM inserted i LEFT JOIN deleted d ON d.id_cliente=i.id_cliente;
END;
