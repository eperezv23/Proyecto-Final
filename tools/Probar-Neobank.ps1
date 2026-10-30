param(
 [string]$Server='lpc:localhost',
 [string]$Database='NEOBANK_GT_DESARROLLO',
 [string]$ResultFile=(Join-Path $PSScriptRoot '..\evidencias\pruebas.json')
)
$ErrorActionPreference='Stop'
if($Database -notmatch '^NEOBANK_GT(?:_[A-Z0-9]+)*$'){throw 'Use una base de pruebas NEOBANK_GT.'}
$cx=[System.Data.SqlClient.SqlConnection]::new("Server=$Server;Database=$Database;Integrated Security=True;Encrypt=False;Connect Timeout=10;Application Name=NEOBANK Pruebas")
$checks=[System.Collections.Generic.List[object]]::new()
$prefix='T'+[guid]::NewGuid().ToString('N').Substring(0,7)
function Q([string]$sql){
 $cmd=$cx.CreateCommand();$cmd.CommandText=$sql;$cmd.CommandTimeout=60
 try{$cmd.ExecuteScalar()}finally{$cmd.Dispose()}
}
function Check([string]$name,[bool]$ok,[string]$detail=''){
 $checks.Add([pscustomobject]@{prueba=$name;resultado=$(if($ok){'CORRECTO'}else{'FALLO'});detalle=$detail})
 if(-not $ok){throw "Falló: $name $detail"}
}
function Reject([string]$name,[string]$sql,[int[]]$numbers){
 $number=0
 try{$null=Q $sql}catch{$ex=$_.Exception.GetBaseException();if($ex -is [System.Data.SqlClient.SqlException]){$number=$ex.Number}else{throw}}
 Check $name ($number -in $numbers) "Error SQL obtenido: $number"
}
try{
 $cx.Open()
 $user=Q "SELECT id_usuario FROM dbo.TB_USUARIO WHERE nombre_usuario='operador_demo'"
 $individual=Q "SELECT id_tipo_cliente FROM dbo.TB_TIPO_CLIENTE WHERE nombre='Individual'"
 $juridico=Q "SELECT id_tipo_cliente FROM dbo.TB_TIPO_CLIENTE WHERE nombre='Juridico'"
 $monetaria=Q "SELECT id_tipo_cuenta FROM dbo.TB_TIPO_CUENTA WHERE nombre='Monetaria'"
 $ahorro=Q "SELECT id_tipo_cuenta FROM dbo.TB_TIPO_CUENTA WHERE nombre='Ahorro'"
 $gtq=Q "SELECT id_moneda FROM dbo.TB_MONEDA WHERE codigo='GTQ'"
 $usd=Q "SELECT id_moneda FROM dbo.TB_MONEDA WHERE codigo='USD'"
 $cred=Q "SELECT id_tipo_tarjeta FROM dbo.TB_TIPO_TARJETA WHERE nombre='Credito'"
 $deb=Q "SELECT id_tipo_tarjeta FROM dbo.TB_TIPO_TARJETA WHERE nombre='Debito'"
 $bank=Q "SELECT id_banco FROM dbo.TB_BANCO WHERE nombre='Banco Simulado A'"
 $cui='9'+([DateTime]::UtcNow.Ticks.ToString().Substring(6,12))
 $c1=Q "EXEC dbo.SP01_REGISTRAR_CLIENTE @id_tipo_cliente=$individual,@nombre='Prueba $prefix Individual',@cui='$cui'"
 Check 'SP01 registra cliente individual' ($c1 -gt 0)
 Reject 'RN01 rechaza CUI duplicado' "EXEC dbo.SP01_REGISTRAR_CLIENTE $individual,'Duplicado','$cui'" @(51014)
 Reject 'SP01 rechaza nombre vacío' "EXEC dbo.SP01_REGISTRAR_CLIENTE $individual,'   ','9999999999998'" @(51011)
 Reject 'SP01 rechaza CUI mal formado' "EXEC dbo.SP01_REGISTRAR_CLIENTE $individual,'Incorrecto','ABC'" @(51012)
 Reject 'SP01 valida tipo de cliente' "EXEC dbo.SP01_REGISTRAR_CLIENTE -1,'Incorrecto','9999999999998'" @(51010)
 $c2=Q "EXEC dbo.SP01_REGISTRAR_CLIENTE @id_tipo_cliente=$juridico,@nombre='Prueba $prefix Empresa',@nit='$prefix-NIT'"
 Check 'SP01 registra cliente jurídico' ($c2 -gt 0)
 Reject 'RN01 rechaza NIT duplicado' "EXEC dbo.SP01_REGISTRAR_CLIENTE @id_tipo_cliente=$juridico,@nombre='Duplicado',@nit='$prefix-NIT'" @(51015)
 Reject 'SP01 jurídico requiere NIT' "EXEC dbo.SP01_REGISTRAR_CLIENTE @id_tipo_cliente=$juridico,@nombre='Sin NIT'" @(51013)
 Check 'Auditoría registra alta y principal SQL' ((Q "SELECT COUNT(*) FROM dbo.TB_EVENTO_AUDITORIA WHERE entidad='TB_CLIENTE' AND id_entidad=$c1 AND principal_sql=ORIGINAL_LOGIN()") -eq 1)
 $a=Q "EXEC dbo.SP02_APERTURAR_CUENTA $c1,$monetaria,$gtq,'$prefix-A',$user,'$prefix-OA'"
 $b=Q "EXEC dbo.SP02_APERTURAR_CUENTA $c2,$ahorro,$gtq,'$prefix-B',$user,'$prefix-OB'"
 $d=Q "EXEC dbo.SP02_APERTURAR_CUENTA $c1,$ahorro,$usd,'$prefix-USD',$user,'$prefix-OD'"
 Check 'SP02 apertura con saldo cero y titular' ((Q "SELECT COUNT(*) FROM dbo.TB_CUENTA c JOIN dbo.TB_TITULAR_CUENTA t ON t.id_cuenta=c.id_cuenta WHERE c.id_cuenta=$a AND c.saldo=0 AND t.id_cliente=$c1") -eq 1)
 $null=Q "EXEC dbo.SP11_AGREGAR_TITULAR $c2,$a,$user,'$prefix-TIT'"
 Check 'RN02 cuenta compartida con dos titulares' ((Q "SELECT COUNT(*) FROM dbo.TB_TITULAR_CUENTA WHERE id_cuenta=$a") -eq 2)
 $null=Q "UPDATE dbo.TB_CLIENTE SET estado='Inactivo' WHERE id_cliente=$c2"
 Reject 'RN03 cliente inactivo no abre cuentas' "EXEC dbo.SP02_APERTURAR_CUENTA $c2,$ahorro,$gtq,'$prefix-ERROR',$user,'$prefix-INACT'" @(51020)
 $null=Q "UPDATE dbo.TB_CLIENTE SET estado='Activo' WHERE id_cliente=$c2"
 $null=Q "EXEC dbo.SP03_REGISTRAR_DEPOSITO $a,10000,$user,'$prefix-DEP'"
 Check 'SP03 depósito acredita y genera movimiento' ((Q "SELECT saldo FROM dbo.TB_CUENTA WHERE id_cuenta=$a") -eq 10000 -and (Q "SELECT monto FROM dbo.TB_MOVIMIENTO WHERE referencia='$prefix-DEP'") -eq 10000)
 Reject 'Monto cero rechazado' "EXEC dbo.SP03_REGISTRAR_DEPOSITO $a,0,$user,'$prefix-ZERO'" @(51004)
 Reject 'Monto negativo rechazado' "EXEC dbo.SP03_REGISTRAR_DEPOSITO $a,-1,$user,'$prefix-NEG'" @(51004)
 Reject 'Más de dos decimales rechazado' "EXEC dbo.SP03_REGISTRAR_DEPOSITO $a,1.001,$user,'$prefix-DEC'" @(51004)
 Reject 'Usuario inexistente rechazado' "EXEC dbo.SP03_REGISTRAR_DEPOSITO $a,1,-1,'$prefix-USR'" @(51003)
 Reject 'Referencia vacía rechazada' "EXEC dbo.SP03_REGISTRAR_DEPOSITO $a,1,$user,''" @(51002)
 Reject 'Referencia extensa rechazada sin truncar' "EXEC dbo.SP03_REGISTRAR_DEPOSITO $a,1,$user,'12345678901234567890123456789012345678901'" @(51002)
 Reject 'RN08 referencia global duplicada' "EXEC dbo.SP04_REGISTRAR_RETIRO $a,1,$user,'$prefix-DEP'" @(2627,2601)
 Check 'Rechazos conservan saldo original' ((Q "SELECT saldo FROM dbo.TB_CUENTA WHERE id_cuenta=$a") -eq 10000)
 $null=Q "EXEC dbo.SP04_REGISTRAR_RETIRO $a,200,$user,'$prefix-RET'"
 Check 'SP04 retiro debita saldo' ((Q "SELECT saldo FROM dbo.TB_CUENTA WHERE id_cuenta=$a") -eq 9800)
 Reject 'RN05 retiro sin saldo rechazado' "EXEC dbo.SP04_REGISTRAR_RETIRO $a,9800.01,$user,'$prefix-NOFUNDS'" @(51031)
 $transfer=Q "EXEC dbo.SP05_TRANSFERENCIA_INTERNA $a,$b,1000,$user,'$prefix-TR'"
 Check 'SP05 transfiere conservando total entre cuentas' ((Q "SELECT saldo FROM dbo.TB_CUENTA WHERE id_cuenta=$a") -eq 8800 -and (Q "SELECT saldo FROM dbo.TB_CUENTA WHERE id_cuenta=$b") -eq 1000)
 Check 'RN06 transferencia tiene débito y crédito relacionados' ((Q "SELECT COUNT(*) FROM dbo.TB_TRANSFERENCIA_MOVIMIENTO WHERE id_transferencia=$transfer") -eq 2)
 Reject 'Transferencia a la misma cuenta rechazada' "EXEC dbo.SP05_TRANSFERENCIA_INTERNA $a,$a,1,$user,'$prefix-SAME'" @(51040)
 Reject 'Transferencia entre monedas requiere conversión' "EXEC dbo.SP05_TRANSFERENCIA_INTERNA $a,$d,1,$user,'$prefix-DIFF'" @(51042)
 $null=Q "EXEC dbo.SP16_CAMBIAR_ESTADO_PRODUCTO 'Cuenta',$b,'Bloqueada',$user,'$prefix-BLOCK'"
 Reject 'RN04 depósito en cuenta bloqueada rechazado' "EXEC dbo.SP03_REGISTRAR_DEPOSITO $b,1,$user,'$prefix-BLKDEP'" @(51030)
 Reject 'RN04 retiro de cuenta bloqueada rechazado' "EXEC dbo.SP04_REGISTRAR_RETIRO $b,1,$user,'$prefix-BLKRET'" @(51030)
 Reject 'RN04 transferencia a cuenta bloqueada rechazada' "EXEC dbo.SP05_TRANSFERENCIA_INTERNA $a,$b,1,$user,'$prefix-BLKTR'" @(51041)
 $null=Q "EXEC dbo.SP16_CAMBIAR_ESTADO_PRODUCTO 'Cuenta',$b,'Activa',$user,'$prefix-UNBLOCK'"
 # Error deliberado después del débito, durante la inserción del crédito.
 $null=Q "CREATE OR ALTER TRIGGER dbo.TR_PRUEBA_ROLLBACK ON dbo.TB_MOVIMIENTO AFTER INSERT AS BEGIN IF EXISTS(SELECT 1 FROM inserted WHERE referencia='$prefix-FAIL-C') THROW 51990,'Fallo deliberado de prueba',1; END"
 try{Reject 'RN07 ROLLBACK ante error después del débito' "EXEC dbo.SP05_TRANSFERENCIA_INTERNA $a,$b,50,$user,'$prefix-FAIL'" @(51990)}
 finally{$null=Q 'DROP TRIGGER IF EXISTS dbo.TR_PRUEBA_ROLLBACK'}
 Check 'ROLLBACK restaura ambas cuentas' ((Q "SELECT saldo FROM dbo.TB_CUENTA WHERE id_cuenta=$a") -eq 8800 -and (Q "SELECT saldo FROM dbo.TB_CUENTA WHERE id_cuenta=$b") -eq 1000)
 Check 'ROLLBACK no deja operación, transferencia ni movimiento parcial' ((Q "SELECT (SELECT COUNT(*) FROM dbo.TB_OPERACION WHERE referencia='$prefix-FAIL')+(SELECT COUNT(*) FROM dbo.TB_TRANSFERENCIA WHERE referencia='$prefix-FAIL')+(SELECT COUNT(*) FROM dbo.TB_MOVIMIENTO WHERE referencia LIKE '$prefix-FAIL%')") -eq 0)
 $pending=Q "EXEC dbo.SP06_TRANSFERENCIA_INTERBANCARIA $a,$bank,'EXT-FICTICIA',100,$user,'$prefix-IB'"
 Check 'SP06 interbancaria pendiente y fondos debitados' ((Q "SELECT estado FROM dbo.TB_TRANSFERENCIA WHERE id_transferencia=$pending") -eq 'Pendiente' -and (Q "SELECT saldo FROM dbo.TB_CUENTA WHERE id_cuenta=$a") -eq 8700)
 $null=Q "EXEC dbo.SP16_CAMBIAR_ESTADO_PRODUCTO 'Cuenta',$a,'Bloqueada',$user,'$prefix-IBBLOCK'"
 Reject 'RN04 cuenta bloqueada no resuelve interbancarias' "EXEC dbo.SP14_RESOLVER_INTERBANCARIA $pending,'Rechazada',$user,'$prefix-IBBLKRES'" @(51030)
 $null=Q "EXEC dbo.SP16_CAMBIAR_ESTADO_PRODUCTO 'Cuenta',$a,'Activa',$user,'$prefix-IBUNBLOCK'"
 $null=Q "EXEC dbo.SP14_RESOLVER_INTERBANCARIA $pending,'Rechazada',$user,'$prefix-REJECT'"
 Check 'Interbancaria rechazada devuelve fondos y conserva original' ((Q "SELECT saldo FROM dbo.TB_CUENTA WHERE id_cuenta=$a") -eq 8800 -and (Q "SELECT COUNT(*) FROM dbo.TB_MOVIMIENTO WHERE id_movimiento_original IS NOT NULL AND referencia='$prefix-REJECT'") -eq 1)
 Reject 'Interbancaria no puede resolverse dos veces' "EXEC dbo.SP14_RESOLVER_INTERBANCARIA $pending,'Confirmada',$user,'$prefix-TWICE'" @(51072)
 $confirmed=Q "EXEC dbo.SP06_TRANSFERENCIA_INTERBANCARIA $a,$bank,'EXT-FICTICIA',50,$user,'$prefix-IB2'"
 $null=Q "EXEC dbo.SP14_RESOLVER_INTERBANCARIA $confirmed,'Confirmada',$user,'$prefix-CONFIRM'"
 Check 'Interbancaria confirmada no debita dos veces' ((Q "SELECT saldo FROM dbo.TB_CUENTA WHERE id_cuenta=$a") -eq 8750)
 $rate=Q "SELECT TOP(1) valor_cambio FROM dbo.TB_TIPO_CAMBIO WHERE id_moneda_origen=$gtq AND id_moneda_destino=$usd AND estado='Activo' AND fecha_registro<=GETDATE() ORDER BY fecha_registro DESC,id_tipo_cambio DESC"
 $expected=[math]::Round([decimal]765*[decimal]$rate,2,[MidpointRounding]::AwayFromZero)
 $null=Q "EXEC dbo.SP07_CAMBIO_MONEDA $a,$d,765,$user,'$prefix-FX'"
 Check 'SP07 conversión calcula destino con ocho decimales de cotización' ((Q "SELECT saldo FROM dbo.TB_CUENTA WHERE id_cuenta=$d") -eq $expected)
 Check 'RN10 conserva cotización aplicada exacta' ((Q "SELECT tipo_cambio_aplicado FROM dbo.TB_CONVERSION_MONEDA WHERE referencia='$prefix-FX'") -eq $rate)
 Check 'F04 conversión coincide con la operación' ((Q "SELECT dbo.F04_CONVERTIR_MONEDA(765,$gtq,$usd,GETDATE())") -eq $expected)
 Check 'F04 moneda idéntica conserva importe' ((Q "SELECT dbo.F04_CONVERTIR_MONEDA(123.45,$gtq,$gtq,GETDATE())") -eq 123.45)
 Check 'F04 moneda inexistente devuelve NULL' ((Q "SELECT dbo.F04_CONVERTIR_MONEDA(1,-1,$usd,GETDATE())") -is [DBNull])
 $card=Q "EXEC dbo.SP12_EMITIR_TARJETA $c1,$a,$cred,'$prefix-CRED','2099-12-31',1000,$user,'$prefix-CARD'"
 $null=Q "EXEC dbo.SP09_CONSUMO_TARJETA_CREDITO $card,'Comercio ficticio',850,$user,'$prefix-BUY'"
 Check 'SP09 consumo actualiza deuda sin debitar cuenta' ((Q "SELECT saldo_utilizado FROM dbo.TB_TARJETA WHERE id_tarjeta=$card") -eq 850 -and (Q "SELECT saldo FROM dbo.TB_CUENTA WHERE id_cuenta=$a") -eq 7985)
 Check 'F03 utilización de tarjeta' ((Q "SELECT dbo.F03_UTILIZACION_TARJETA($card)") -eq 85)
 Reject 'RN11 consumo sobre límite rechazado' "EXEC dbo.SP09_CONSUMO_TARJETA_CREDITO $card,'Comercio',151,$user,'$prefix-LIMIT'" @(51062)
 $null=Q "EXEC dbo.SP16_CAMBIAR_ESTADO_PRODUCTO 'Tarjeta',$card,'Bloqueada',$user,'$prefix-CBLOCK'"
 Reject 'RN12 tarjeta bloqueada no consume' "EXEC dbo.SP09_CONSUMO_TARJETA_CREDITO $card,'Comercio',1,$user,'$prefix-CBLKBUY'" @(51061)
 $null=Q "EXEC dbo.SP10_PAGO_TARJETA_CREDITO $card,$a,50,$user,'$prefix-PAY'"
 Check 'SP10 pago reduce deuda y cuenta; admite pagar tarjeta bloqueada' ((Q "SELECT saldo_utilizado FROM dbo.TB_TARJETA WHERE id_tarjeta=$card") -eq 800 -and (Q "SELECT saldo FROM dbo.TB_CUENTA WHERE id_cuenta=$a") -eq 7935)
 Reject 'Pago superior a deuda rechazado' "EXEC dbo.SP10_PAGO_TARJETA_CREDITO $card,$a,801,$user,'$prefix-OVERPAY'" @(51065)
 Reject 'Pago desde moneda diferente rechazado' "EXEC dbo.SP10_PAGO_TARJETA_CREDITO $card,$d,1,$user,'$prefix-PAYFX'" @(51064)
 $debit=Q "EXEC dbo.SP12_EMITIR_TARJETA $c1,$a,$deb,'$prefix-DEB','2099-12-31',NULL,$user,'$prefix-DCARD'"
 $null=Q "EXEC dbo.SP13_CONSUMO_TARJETA_DEBITO $debit,'Comercio ficticio',35,$user,'$prefix-DBUY'"
 Check 'Consumo débito reduce cuenta' ((Q "SELECT saldo FROM dbo.TB_CUENTA WHERE id_cuenta=$a") -eq 7900)
 $p=Q "EXEC dbo.SP08_CONSTITUIR_PLAZO_FIJO $c1,$a,1000,12,365,$user,'$prefix-PF'"
 Check 'SP08 plazo fijo debita principal y guarda vencimiento' ((Q "SELECT saldo FROM dbo.TB_CUENTA WHERE id_cuenta=$a") -eq 6900 -and (Q "SELECT DATEDIFF(day,fecha_inicio,fecha_vencimiento) FROM dbo.TB_PLAZO_FIJO WHERE id_plazo_fijo=$p") -eq 365)
 Check 'F02 interés simple anual' ((Q "SELECT dbo.F02_INTERES_PLAZO_FIJO($p)") -eq 120)
 Reject 'No liquida plazo antes del vencimiento' "EXEC dbo.SP15_LIQUIDAR_PLAZO_FIJO $p,$user,'$prefix-EARLY'" @(51074)
 # Simulación de paso del tiempo exclusivamente sobre el plazo ficticio de esta prueba.
 $null=Q "UPDATE dbo.TB_PLAZO_FIJO SET fecha_inicio=DATEADD(day,-365,CONVERT(date,GETDATE())),fecha_vencimiento=CONVERT(date,GETDATE()),estado='Vencido' WHERE id_plazo_fijo=$p"
 $null=Q "EXEC dbo.SP15_LIQUIDAR_PLAZO_FIJO $p,$user,'$prefix-LIQ'"
 Check 'Liquidación acredita principal e interés una sola vez' ((Q "SELECT saldo FROM dbo.TB_CUENTA WHERE id_cuenta=$a") -eq 8020 -and (Q "SELECT estado FROM dbo.TB_PLAZO_FIJO WHERE id_plazo_fijo=$p") -eq 'Liquidado')
 Reject 'No permite doble liquidación' "EXEC dbo.SP15_LIQUIDAR_PLAZO_FIJO $p,$user,'$prefix-LIQ2'" @(51073)
 $ret=Q "SELECT id_movimiento FROM dbo.TB_MOVIMIENTO WHERE referencia='$prefix-RET'"
 $null=Q "EXEC dbo.SP17_REVERSAR_MOVIMIENTO $ret,'Correccion de prueba',$user,'$prefix-REV'"
 Check 'RN14 reverso conserva original y restaura importe' ((Q "SELECT saldo FROM dbo.TB_CUENTA WHERE id_cuenta=$a") -eq 8220 -and (Q "SELECT estado FROM dbo.TB_MOVIMIENTO WHERE id_movimiento=$ret") -eq 'Confirmado')
 Reject 'No permite doble reverso' "EXEC dbo.SP17_REVERSAR_MOVIMIENTO $ret,'Duplicado',$user,'$prefix-REV2'" @(51087)
 Reject 'RN14 no elimina movimiento confirmado' "DELETE FROM dbo.TB_MOVIMIENTO WHERE id_movimiento=$ret" @(51100,547)
 Reject 'RN14 no modifica movimiento confirmado' "UPDATE dbo.TB_MOVIMIENTO SET monto=1 WHERE id_movimiento=$ret" @(51100)
 $null=Q "EXEC dbo.SP18_REVERSAR_TRANSFERENCIA_INTERNA $transfer,'Correccion de prueba',$user,'$prefix-REVTR'"
 Check 'Reverso de transferencia restaura ambas cuentas' ((Q "SELECT saldo FROM dbo.TB_CUENTA WHERE id_cuenta=$a") -eq 9220 -and (Q "SELECT saldo FROM dbo.TB_CUENTA WHERE id_cuenta=$b") -eq 0)
 Reject 'Transferencia no se reversa dos veces' "EXEC dbo.SP18_REVERSAR_TRANSFERENCIA_INTERNA $transfer,'Duplicado',$user,'$prefix-REVTR2'" @(51087)
 Check 'F01 saldo disponible activo' ((Q "SELECT dbo.F01_SALDO_DISPONIBLE($a)") -eq 9220)
 $null=Q "EXEC dbo.SP16_CAMBIAR_ESTADO_PRODUCTO 'Cuenta',$b,'Cerrada',$user,'$prefix-CLOSE'"
 Check 'F01 cuenta cerrada no tiene saldo disponible' ((Q "SELECT dbo.F01_SALDO_DISPONIBLE($b)") -eq 0)
 Reject 'Cuenta cerrada no se reabre' "EXEC dbo.SP16_CAMBIAR_ESTADO_PRODUCTO 'Cuenta',$b,'Activa',$user,'$prefix-REOPEN'" @(51077)
 Reject 'Cuenta cerrada no recibe depósitos' "EXEC dbo.SP03_REGISTRAR_DEPOSITO $b,1,$user,'$prefix-CLOSEDDEP'" @(51030)
 $u2=Q "EXEC dbo.SP19_REGISTRAR_USUARIO '$prefix-OPER','Operador ficticio',$user,'$prefix-NEWUSER'"
 Check 'RF07 registra usuario de auditoría' ($u2 -gt 0)
 $tc=Q "EXEC dbo.SP20_REGISTRAR_TIPO_CAMBIO $usd,$gtq,7.65,$user,'$prefix-RATE'"
 Check 'Registro de nueva cotización' ($tc -gt 0)
 Check 'RN15 todos los movimientos tienen usuario válido' ((Q 'SELECT COUNT(*) FROM dbo.TB_MOVIMIENTO m LEFT JOIN dbo.TB_USUARIO u ON u.id_usuario=m.id_usuario WHERE u.id_usuario IS NULL') -eq 0)
 Check 'Referencias únicas en registro global' ((Q 'SELECT COUNT(*) FROM (SELECT referencia FROM dbo.TB_OPERACION GROUP BY referencia HAVING COUNT(*)>1) d') -eq 0)
 Check 'No quedan transacciones abiertas tras rechazos' ((Q 'SELECT @@TRANCOUNT') -eq 0)
 Check 'No quedan saldos negativos' ((Q 'SELECT COUNT(*) FROM dbo.TB_CUENTA WHERE saldo<0') -eq 0)
 Check 'No quedan tarjetas sobre su límite' ((Q 'SELECT COUNT(*) FROM dbo.TB_TARJETA WHERE saldo_utilizado>limite_credito') -eq 0)
 # Dos solicitudes simultáneas de 80 sobre una cuenta de saldo 100.
 $conc=Q "EXEC dbo.SP02_APERTURAR_CUENTA $c1,$ahorro,$gtq,'$prefix-CONC',$user,'$prefix-CO'"
 $null=Q "EXEC dbo.SP03_REGISTRAR_DEPOSITO $conc,100,$user,'$prefix-CD'"
 $other=[System.Data.SqlClient.SqlConnection]::new($cx.ConnectionString)
 try{
  $other.Open();$x=$cx.CreateCommand();$y=$other.CreateCommand()
  $x.CommandText="EXEC dbo.SP04_REGISTRAR_RETIRO $conc,80,$user,'$prefix-C1'";
  $y.CommandText="EXEC dbo.SP04_REGISTRAR_RETIRO $conc,80,$user,'$prefix-C2'";
  $t1=$x.ExecuteNonQueryAsync();$t2=$y.ExecuteNonQueryAsync();$success=0;$insufficient=0
  foreach($t in @($t1,$t2)){
   try{$null=$t.GetAwaiter().GetResult();$success++}catch{if($_.Exception.GetBaseException().Number -eq 51031){$insufficient++}else{throw}}
  }
  Check 'Concurrencia: sólo un retiro puede gastar los mismos fondos' ($success -eq 1 -and $insufficient -eq 1 -and (Q "SELECT saldo FROM dbo.TB_CUENTA WHERE id_cuenta=$conc") -eq 20)
 }finally{if($x){$x.Dispose()};if($y){$y.Dispose()};$other.Dispose()}
}catch{
 $checks.Add([pscustomobject]@{prueba='Ejecución de suite';resultado='FALLO';detalle=$_.Exception.Message})
 throw
}finally{
 $cx.Dispose()
 $report=[ordered]@{fecha_guatemala=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(-6)).ToString('o');servidor=$Server;base=$Database;lote=$prefix;correctas=@($checks|Where-Object resultado -eq 'CORRECTO').Count;fallidas=@($checks|Where-Object resultado -eq 'FALLO').Count;pruebas=$checks.ToArray()}
 $json=ConvertTo-Json -InputObject $report -Depth 8
 [IO.File]::WriteAllText([IO.Path]::GetFullPath($ResultFile),$json,[Text.UTF8Encoding]::new($false))
 Write-Output $json
}
