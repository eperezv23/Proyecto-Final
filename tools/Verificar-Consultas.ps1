param([string]$Server='lpc:localhost',[string]$Database='NEOBANK_GT',[string]$OutputDirectory=(Join-Path $PSScriptRoot '..\evidencias'))
$ErrorActionPreference='Stop'
$out=[IO.Path]::GetFullPath($OutputDirectory)
$file=Join-Path $out 'consultas_demo.json'
& (Join-Path $PSScriptRoot 'Invoke-SqlScript.ps1') -Server $Server -Database $Database -SqlFile (Join-Path $PSScriptRoot '..\sql\07_consultas.sql') -ResultFile $file | Out-Null
$sets=Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
$checks=[System.Collections.Generic.List[object]]::new()
function A([string]$name,[bool]$value){$checks.Add([pscustomobject]@{consulta=$name;resultado=$(if($value){'CORRECTO'}else{'FALLO'})})}
if($sets.Count -ne 12){throw 'Se esperaban 12 conjuntos de resultados.'}
# Valores calculados de forma independiente para una instalación recién creada
# con 06_datos_demo.sql, antes de ejecutar Probar-Neobank.ps1.
A 'C01 incluye cliente sin cuentas' (@($sets[0].Rows|Where-Object {$_.nombre -eq 'Empresa Ficticia Demo' -and $_.cantidad_cuentas -eq 0}).Count -eq 1)
A 'C02 siete clientes con monetaria y ahorro' ($sets[1].Rows.Count -eq 7)
A 'C03 seis movimientos y orden cronológico descendente' ($sets[2].Rows.Count -eq 6 -and $sets[2].Rows[0].referencia -eq 'DEMO-PAGO' -and $sets[2].Rows[-1].referencia -eq 'DEMO-DEPOSITO-GTQ-1')
A 'C04 incluye cuenta sin movimientos' ($sets[3].Rows.Count -eq 1 -and $sets[3].Rows[0].numero_cuenta -eq 'DEMO-SIN-MOVIMIENTOS')
A 'C05 depósitos y retiros del cliente 1' (@($sets[4].Rows|Where-Object {$_.nombre -eq 'Cliente Ficticio 1' -and $_.moneda -eq 'GTQ' -and $_.total_depositos -eq 2000 -and $_.total_retiros -eq 50}).Count -eq 1)
A 'C06 plazo próximo a vencer' ($sets[5].Rows.Count -eq 1 -and $sets[5].Rows[0].monto -eq 500)
A 'C07 utilización de crédito superior a 80%' ($sets[6].Rows.Count -eq 1 -and $sets[6].Rows[0].porcentaje -eq 85)
$gtq=($sets[7].Rows|Where-Object moneda -eq GTQ|Measure-Object saldo_total -Sum).Sum
$usd=($sets[7].Rows|Where-Object moneda -eq USD|Measure-Object saldo_total -Sum).Sum
A 'C08 total institucional sin duplicar cotitulares' ($gtq -eq 54535 -and $usd -eq 2900)
A 'C09 cinco posiciones por moneda' ($sets[8].Rows.Count -eq 10 -and @($sets[8].Rows|Where-Object moneda -eq GTQ).Count -eq 5 -and @($sets[8].Rows|Where-Object moneda -eq USD).Count -eq 5)
A 'C10 saldo acumulado final exacto' ($sets[9].Rows.Count -eq 6 -and $sets[9].Rows[-1].saldo_acumulado -eq 535)
A 'C11 estados y porcentajes 50/25/25' (@($sets[10].Rows|Where-Object {$_.estado -eq 'Confirmada' -and $_.cantidad -eq 2 -and $_.porcentaje -eq 50}).Count -eq 1 -and @($sets[10].Rows|Where-Object {$_.porcentaje -eq 25 -and $_.cantidad -eq 1}).Count -eq 2)
A 'C12 consolida 535 + 500 - 850 = 185 GTQ' (@($sets[11].Rows|Where-Object {$_.nombre -eq 'Cliente Ficticio 1' -and $_.moneda -eq 'GTQ' -and $_.saldo_cuentas -eq 535 -and $_.inversiones -eq 500 -and $_.deuda_tarjetas -eq 850 -and $_.posicion_neta -eq 185}).Count -eq 1)
$report=[ordered]@{base=$Database;correctas=@($checks|Where-Object resultado -eq 'CORRECTO').Count;fallidas=@($checks|Where-Object resultado -eq 'FALLO').Count;pruebas=$checks.ToArray()}
$json=$report|ConvertTo-Json -Depth 6
[IO.File]::WriteAllText((Join-Path $out 'validacion_consultas.json'),$json,[Text.UTF8Encoding]::new($false))
$json
if($report.fallidas -gt 0){throw 'Hay consultas que no coinciden con el escenario esperado de datos demo.'}
