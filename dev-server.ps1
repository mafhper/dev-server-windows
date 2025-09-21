# Testa conexao ao Postgres se variaveis detectadas
    if ($hasBackend -and $dbVars.Count -gt 0) {
        $pgUser = [System.Environment]::GetEnvironmentVariable("PGUSER")
        $pgPass = [System.Environment]::GetEnvironmentVariable("PGPASSWORD")
        $pgDb   = [System.Environment]::GetEnvironmentVariable("PGDATABASE")
        $pgHost = [System.Environment]::GetEnvironmentVariable("PGHOST")
        if ($pgUser -and $pgDb -and $pgHost) {
            Write-Host "Testando conexao ao Postgres..."
            $env:PGUSER = $pgUser
            $env:PGPASSWORD = $pgPass
            $env:PGDATABASE = $pgDb
            $env:PGHOST = $pgHost
            $result = & psql -h $pgHost -U $pgUser -d $pgDb -c "SELECT 1;" 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[ERRO] Nao foi possivel conectar ao banco Postgres. Verifique se o servico esta rodando e as variaveis estao corretas."
                Write-Host $result
                $cont = Read-Host "Deseja continuar mesmo assim? (s/n)"
                if ($cont -ne "s") { Write-Host "Operacao abortada."; return }
            } else {
                Write-Host "Conexao ao Postgres bem-sucedida."
            }
        }
    }
# Configuracao de encoding para PowerShell
$OutputEncoding = [Console]::OutputEncoding = [Console]::InputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
function Test-Command($cmd) {
    $null = Get-Command $cmd -ErrorAction SilentlyContinue
    return $?
}

# Checagem dinamica de dependencias conforme projeto
function Check-ProjectDependencies($projPath) {
    $missing = @()
    $type = Get-ProjectType $projPath
    if ($type -in @('react','next','vue','express','node')) {
        if (-not (Test-Command 'node')) { $missing += 'Node.js (node)'; }
        if (-not (Test-Command 'npm')) { $missing += 'Node.js (npm)'; }
    }
    if ($type -eq 'php') {
        if (-not (Test-Command 'php')) { $missing += 'PHP (php)'; }
        if (-not (Test-Command 'composer')) { $missing += 'Composer (composer)'; }
    }
    # Checa backend se existir
    $backendPath = Join-Path $projPath "backend"
    if (Test-Path $backendPath) {
        $envFile = Join-Path $backendPath ".env"
        if (Test-Path $envFile) {
            $envLines = Get-Content $envFile
            $hasPgVars = $false
            $envLines | ForEach-Object {
                if ($_ -match "^\s*(PGUSER|PGPASSWORD|PGDATABASE|PGHOST)=") { $hasPgVars = $true }
            }
            if ($hasPgVars -and -not (Test-Command 'psql')) { $missing += 'Postgres (psql)'; }
        }
    }
    if ($missing.Count -gt 0) {
        Write-Host "[AVISO] Os seguintes programas necessarios para este projeto nao foram encontrados no sistema:" -ForegroundColor Yellow
        $missing | ForEach-Object { Write-Host " - $_" -ForegroundColor Yellow }
        Write-Host "Instale os programas acima para garantir o funcionamento completo do script." -ForegroundColor Yellow
        Write-Host "Acesse https://nodejs.org, https://getcomposer.org, https://www.php.net/downloads.php, https://www.postgresql.org/download/ para baixar e instalar." -ForegroundColor Yellow
    }
}

$LOCALHOST_ROOT = "C:\LocalServer"
$PROJECTS_DIR   = Join-Path $LOCALHOST_ROOT "projects"
$LOGS_DIR       = Join-Path $LOCALHOST_ROOT "logs"
$CONFIG_FILE    = Join-Path $LOCALHOST_ROOT "server-config.json"
$RUNNING_FILE   = Join-Path $LOCALHOST_ROOT "running-processes.json"

# Garante diretorios
New-Item -ItemType Directory -Force -Path $PROJECTS_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $LOGS_DIR | Out-Null
if (!(Test-Path $RUNNING_FILE)) { '{}' | Out-File $RUNNING_FILE }

function Get-AvailablePort {
    $port = 3000
    while (Test-NetConnection -ComputerName localhost -Port $port -InformationLevel Quiet -WarningAction SilentlyContinue) {
        $port++
    }
    return $port
}

function Get-ProjectType($path) {
    if (Test-Path (Join-Path $path "package.json")) {
        $package = Get-Content (Join-Path $path "package.json") -Raw | ConvertFrom-Json
        if ($package.dependencies.react) { return "react" }
        elseif ($package.dependencies.next) { return "next" }
        elseif ($package.dependencies.vue) { return "vue" }
        elseif ($package.dependencies.express) { return "express" }
        else { return "node" }
    }
    elseif (Test-Path (Join-Path $path "composer.json")) {
        return "php"
    }
    elseif (Test-Path (Join-Path $path "index.html")) {
        return "static"
    }
    else {
        return "unknown"
    }
}

function Install-Dependencies($path, $type) {
    Write-Host "Instalando dependencias para $type..."
    switch ($type) {
        "react" { Push-Location $path; npm install; Pop-Location }
        "next"  { Push-Location $path; npm install; Pop-Location }
        "vue"   { Push-Location $path; npm install; Pop-Location }
        "express" { Push-Location $path; npm install; Pop-Location }
        "node"  { Push-Location $path; npm install; Pop-Location }
        "php"   { Push-Location $path; composer install; Pop-Location }
        default { Write-Host "Nenhuma dependencia especial detectada." }
    }
}

function Start-ProjectServer($path, $name, $type, $mode) {
    $port = Get-AvailablePort

    # Detecta backend
    $backendPath = Join-Path $path "backend"
    $hasBackend = Test-Path $backendPath

    $cmds = @()
    $procNames = @()

    # Iniciar backend se existir
    if ($hasBackend) {
        $envFile = Join-Path $backendPath ".env"
        $dbVars = @()
        if (Test-Path $envFile) {
            Write-Host "Carregando variaveis do .env do backend..."
            $envLines = Get-Content $envFile
            $envResumo = @()
            $envLines | ForEach-Object {
                if ($_ -match "^\s*([^#][^=]+)=(.+)$") {
                    [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2])
                    $envResumo += $_
                    if ($matches[1] -match "^(PGUSER|PGPASSWORD|PGDATABASE|PGHOST|DB_HOST|DB_USER|DB_PASS|DB_NAME)$") {
                        $dbVars += $_
                    }
                }
            }
            Write-Host "\nResumo das variaveis do .env do backend:"
            $envResumo | ForEach-Object { Write-Host "  $_" }
            if ($dbVars.Count -gt 0) {
                Write-Host "\n[AVISO] Variaveis de banco de dados detectadas no .env do backend:"
                $dbVars | ForEach-Object { Write-Host "  $_" }
                Write-Host "Certifique-se de que o servico do banco (ex: Postgres) esta rodando e acessivel."
            }
        }
        # Detecta se eh Node/Express
        if (Test-Path (Join-Path $backendPath "package.json")) {
            $cmds += @{ cmd = "npm start"; path = $backendPath; tipo = "backend" }
            $procNames += "$name-backend"
        }
        # Pode adicionar outros tipos de backend aqui
    }

    # Iniciar frontend normalmente
    switch ("$type-$mode") {
        "react-dev"   { $cmds += @{ cmd = "npm start"; path = $path; tipo = "frontend" }; $procNames += "$name-frontend" }
        "react-build" {
            Push-Location $path; npm run build; Pop-Location
            $buildDir = Join-Path $path "build"
            if (!(Test-Path $buildDir)) { $buildDir = Join-Path $path "dist" } # Fallback para Vite
            if (!(Test-Path $buildDir)) { Write-Host "Pasta de build nao encontrada em $buildDir"; return }
            $buildDirName = Split-Path $buildDir -Leaf
            $cmds += @{ cmd = "npx serve -s $buildDirName -l $port"; path = $path; tipo = "frontend" }; $procNames += "$name-frontend"
        }
        "react-serve" {
            $buildDir = Join-Path $path "build"
            if (!(Test-Path $buildDir)) { $buildDir = Join-Path $path "dist" } # Fallback para Vite
            if (!(Test-Path $buildDir)) { Write-Host "Pasta de build/dist nao encontrada. Rode em modo 'build' primeiro."; return }
            $buildDirName = Split-Path $buildDir -Leaf
            $cmds += @{ cmd = "npx serve -s $buildDirName -l $port"; path = $path; tipo = "frontend" }; $procNames += "$name-frontend"
        }

        "next-dev"    { $cmds += @{ cmd = "npm run dev -- -p $port"; path = $path; tipo = "frontend" }; $procNames += "$name-frontend" }
        "next-build"  {
            Push-Location $path; npm run build; Pop-Location
            $buildDir = Join-Path $path ".next"
            if (!(Test-Path $buildDir)) { Write-Host "Pasta de build nao encontrada em $buildDir"; return }
            $cmds += @{ cmd = "npm start -- -p $port"; path = $path; tipo = "frontend" }; $procNames += "$name-frontend"
        }

        "vue-dev"     { $cmds += @{ cmd = "npm run serve -- --port $port"; path = $path; tipo = "frontend" }; $procNames += "$name-frontend" }
        "vue-build"   {
            Push-Location $path; npm run build; Pop-Location
            $buildDir = Join-Path $path "dist"
            if (!(Test-Path $buildDir)) { Write-Host "Pasta de build nao encontrada em $buildDir"; return }
            $cmds += @{ cmd = "npx serve dist -l $port"; path = $path; tipo = "frontend" }; $procNames += "$name-frontend"
        }

        "express-dev" { $cmds += @{ cmd = "npm start"; path = $path; tipo = "frontend" }; $procNames += "$name-frontend" }
        "node-dev"    { $cmds += @{ cmd = "npm start"; path = $path; tipo = "frontend" }; $procNames += "$name-frontend" }

        "php-dev"     { $cmds += @{ cmd = "php -S localhost:$port"; path = $path; tipo = "frontend" }; $procNames += "$name-frontend" }
        "static-dev"  { $cmds += @{ cmd = "npx http-server -p $port"; path = $path; tipo = "frontend" }; $procNames += "$name-frontend" }

        default       { Write-Host "Tipo de projeto ou modo nao suportado."; return }
    }

    # Inicia todos os processos (frontend/backend)
    for ($i = 0; $i -lt $cmds.Count; $i++) {
        $procName = $procNames[$i]
        $cmdObj = $cmds[$i]
        Write-Host "Preparando para iniciar o servidor $($cmdObj.tipo) para $name..."
        $logFile = Join-Path $LOGS_DIR "$procName.log"

        # Cria um script temporario para executar o comando na nova janela
        $tmpScript = Join-Path $env:TEMP ("run-$procName.ps1")

        # Conteudo do script temporario
        $scriptContent = @"
`$host.UI.RawUI.WindowTitle = '$procName'
Set-Location -Path '$($cmdObj.path)'
Write-Host "Iniciando o servico '$procName' em '$($cmdObj.path)'..."
Write-Host "Comando: $($cmdObj.cmd)"
Write-Host "Logs tambem estao sendo salvos em: $logFile"
Write-Host "Pressione Ctrl+C nesta janela para parar este servico."

try {
    Invoke-Expression "$($cmdObj.cmd) | Tee-Object -FilePath '$logFile'"
} catch {
    Write-Host "`n[ERRO] Ocorreu um problema ao iniciar o servidor." -ForegroundColor Red
    Write-Host `$_.Exception.Message -ForegroundColor Red
    Read-Host "Pressione Enter para fechar esta janela..."
}
"@
        $scriptContent | Out-File -FilePath $tmpScript -Encoding UTF8

        Write-Host "Abrindo uma nova janela para o servidor '$procName'..."
        $process = Start-Process powershell -ArgumentList "-NoExit", "-File", "`"$tmpScript`"" -PassThru

        # Salva no JSON de processos
        $running = Get-Content $RUNNING_FILE | ConvertFrom-Json
        $running | Add-Member -NotePropertyName $procName -NotePropertyValue @{
            pid=$process.Id; port=$port; path=$cmdObj.path; mode=$mode; tipo=$cmdObj.tipo; log=$logFile
        } -Force
        $running | ConvertTo-Json | Out-File $RUNNING_FILE
    }
}

function List-Servers {
    Write-Host "`n----- SERVIDORES ATIVOS -----" -ForegroundColor Green
    $running = Get-Content $RUNNING_FILE -ErrorAction SilentlyContinue | ConvertFrom-Json
    if (-not $running -or $running.PSObject.Properties.Count -eq 0) {
        Write-Host "Nenhum servidor rodando." -ForegroundColor Gray
    } else {
        $running.PSObject.Properties | ForEach-Object {
            $info = $_.Value
            $url = "http://localhost:$($info.port)"
            Write-Host ""
            Write-Host "Servidor: $($_.Name)" -ForegroundColor White
            Write-Host "  PID:     $($info.pid)"
            Write-Host "  Porta:   $($info.port)"
            Write-Host "  Modo:    $($info.mode)"
            Write-Host "  Tipo:    $($info.tipo)"
            Write-Host "  Caminho: $($info.path)"
            Write-Host "  URL:     $url" -ForegroundColor Cyan
        }
    }
}

function Stop-Server($name) {
    $running = Get-Content $RUNNING_FILE | ConvertFrom-Json
    if ($running.$name) {
        $processId = $running.$name.pid
        if (Get-Process -Id $processId -ErrorAction SilentlyContinue) {
            Stop-Process -Id $processId -Force
            Write-Host "Servidor $name parado."
        } else {
            Write-Host "O processo $processId ja nao estava em execucao."
        }
        $running.PSObject.Properties.Remove($name)
        $running | ConvertTo-Json | Out-File $RUNNING_FILE
    } else {
        Write-Host "Servidor $name nao encontrado."
    }
}

function Remove-Project {
    $projects = Get-ChildItem $PROJECTS_DIR -Directory
    if ($projects.Count -eq 0) {
        Write-Host "Nenhum projeto encontrado em $PROJECTS_DIR."
        return
    }

    Write-Host "`nProjetos disponiveis:"
    $projects | ForEach-Object { Write-Host " - $($_.Name)" }

    $projName = Read-Host "Digite o nome do projeto que deseja remover"
    $projPath = Join-Path $PROJECTS_DIR $projName

    if (!(Test-Path $projPath)) {
        Write-Host "Projeto nao encontrado."
        return
    }

    $confirm = Read-Host "Tem certeza que deseja remover $projName? (s/n)"
    if ($confirm -eq "s") {
        Remove-Item -Recurse -Force $projPath
        Write-Host "Projeto $projName removido de $PROJECTS_DIR."

        # Tambem limpa do JSON de processos se existir
        $running = Get-Content $RUNNING_FILE | ConvertFrom-Json
        if ($running.$projName) {
            $running.PSObject.Properties.Remove($projName)
            $running | ConvertTo-Json | Out-File $RUNNING_FILE
            Write-Host "Entradas de processo do projeto $projName removidas."
        }
    } else {
        Write-Host "Remocao cancelada."
    }
}

function Sync-RunningProcesses {
    $content = Get-Content $RUNNING_FILE -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($content)) {
        '{}' | Out-File $RUNNING_FILE
        return
    }

    try {
        $running = $content | ConvertFrom-Json
    } catch {
        Write-Host "[AVISO] O arquivo de estado 'running-processes.json' estava corrompido e foi resetado." -ForegroundColor Yellow
        '{}' | Out-File $RUNNING_FILE
        Start-Sleep -Seconds 2
        return
    }

    $cleanedProcesses = $running | Clone
    $hasChanges = $false

    if ($running.PSObject.Properties.Count -eq 0) {
        return
    }

    foreach ($proc in $running.PSObject.Properties) {
        $processId = $proc.Value.pid
        if (-not (Get-Process -Id $processId -ErrorAction SilentlyContinue)) {
            $cleanedProcesses.PSObject.Properties.Remove($proc.Name)
            $hasChanges = $true
        }
    }

    if ($hasChanges) {
        $cleanedProcesses | ConvertTo-Json | Out-File $RUNNING_FILE
    }
}

function Show-Dashboard {
    Clear-Host
    Write-Host "================= PAINEL DE CONTROLE DO SERVIDOR LOCAL =================" -ForegroundColor Magenta

    # Mostrar servidores ativos
    Write-Host "`n----- SERVIDORES ATIVOS -----" -ForegroundColor Green
    $running = Get-Content $RUNNING_FILE -ErrorAction SilentlyContinue | ConvertFrom-Json
    if (-not $running -or $running.PSObject.Properties.Count -eq 0) {
        Write-Host "Nenhum servidor rodando." -ForegroundColor Gray
    } else {
        $running.PSObject.Properties | ForEach-Object {
            $info = $_.Value
            $url = "http://localhost:$($info.port)"
            Write-Host ""
            Write-Host "Servidor: $($_.Name)" -ForegroundColor White
            Write-Host "  PID:     $($info.pid)"
            Write-Host "  Porta:   $($info.port)"
            Write-Host "  Modo:    $($info.mode)"
            Write-Host "  Tipo:    $($info.tipo)"
            Write-Host "  Caminho: $($info.path)"
            Write-Host "  URL:     $url" -ForegroundColor Cyan
        }
    }

    # Listar projetos copiados
    Write-Host "`n----- PROJETOS DISPONIVEIS -----" -ForegroundColor Yellow
    $projects = Get-ChildItem $PROJECTS_DIR -Directory
    if ($projects.Count -eq 0) {
        Write-Host 'Nenhum projeto copiado ainda.' -ForegroundColor Gray
    } else {
        $i = 1
        foreach ($proj in $projects) {
            $projType = Get-ProjectType $proj.FullName
            Write-Host ""
            Write-Host "$i. $($proj.Name)" -ForegroundColor White
            Write-Host "   Tipo: $projType"
            Write-Host "   Caminho: $($proj.FullName)"
            Write-Host "   Modificado em: $($proj.LastWriteTime)"
            $i++
        }
    }
}


# ===== LOOP PRINCIPAL =====
while ($true) {
    Sync-RunningProcesses
    Show-Dashboard

    # Menu
    Write-Host "`n------------------- MENU -------------------" -ForegroundColor Cyan
    Write-Host '[1] Copiar e Iniciar Novo Projeto'
    Write-Host '[2] Listar Servidores (Atualizar Painel)'
    Write-Host '[3] Parar Servidor'
    Write-Host '[4] Sair do Painel'
    Write-Host '[5] Iniciar Servidor de Projeto Existente'
    Write-Host '[6] Remover Projeto Copiado'
    $choice = Read-Host 'Digite o numero da opcao desejada'

    switch ($choice) {
        '1' {
            $projPath = Read-Host 'Informe o caminho de ORIGEM do projeto'
            if (!(Test-Path $projPath)) { Write-Host 'Caminho invalido.'; continue }
            $projName = Split-Path $projPath -Leaf
            $dest = Join-Path $PROJECTS_DIR $projName
            if (Test-Path $dest) {
                $overwrite = Read-Host "O projeto '$projName' ja existe. Deseja substituir os arquivos? (s/n)"
                if ($overwrite -ne 's') { Write-Host 'Operacao cancelada.'; continue }
                Write-Host "Removendo copia antiga..."
                Remove-Item -Recurse -Force $dest
            }
            Write-Host "Copiando arquivos de '$projPath' para '$dest'..."
            robocopy $projPath $dest /E /XD node_modules .git /NFL /NDL /NJH /NJS /nc /ns /np > $null
            $type = Get-ProjectType $dest
            Check-ProjectDependencies $dest
            Install-Dependencies $dest $type
            $mode = 'dev'
            if ($type -in @('react','next','vue')) { $mode = Read-Host "Deseja rodar em modo 'dev' ou 'build'? (dev/build)" }
            Start-ProjectServer $dest $projName $type $mode
            Read-Host "Pressione Enter para continuar..."
        }
        '2' { continue } # Apenas atualiza o painel
        '3' {
            try {
                $running = Get-Content $RUNNING_FILE | ConvertFrom-Json
                $serverNames = @($running.PSObject.Properties.Name)

                if ($serverNames.Count -eq 0) {
                    Write-Host "Nenhum servidor para parar."
                    Start-Sleep -Seconds 2
                    continue
                }

                $i = 1
                Write-Host "`nEscolha o servidor para parar:" -ForegroundColor Yellow
                foreach ($name in $serverNames) {
                    Write-Host "[$i] $name"
                    $i++
                }

                $serverNum = Read-Host 'Digite o numero do servidor'
                if ($serverNum -notmatch '^[0-9]+$' -or [int]$serverNum -lt 1 -or [int]$serverNum -gt $serverNames.Count) {
                    Write-Host 'Numero invalido.'
                    Start-Sleep -Seconds 2
                    continue
                }

                $serverToStop = $serverNames[[int]$serverNum - 1]
                Stop-Server $serverToStop
            } catch {
                Write-Host "`n[ERRO] Ocorreu um problema ao tentar parar o servidor." -ForegroundColor Red
                Write-Host $_.Exception.Message -ForegroundColor Red
            } finally {
                Read-Host "Pressione Enter para continuar..."
            }
        }
        '4' {
            $confirmExit = Read-Host "Deseja parar todos os servidores ativos antes de sair? (s/n)"
            if ($confirmExit -eq 's') {
                $running = Get-Content $RUNNING_FILE | ConvertFrom-Json
                if ($running.PSObject.Properties.Count -gt 0) {
                    Write-Host "Parando todos os servidores..."
                    $serverNames = @($running.PSObject.Properties.Name)
                    foreach ($name in $serverNames) {
                        Stop-Server $name
                    }
                } else {
                    Write-Host "Nenhum servidor para parar."
                }
            }
            Write-Host "Saindo..."
            Exit
        }
        '5' {
            $projects = Get-ChildItem $PROJECTS_DIR -Directory
            if ($projects.Count -eq 0) { Write-Host 'Nenhum projeto copiado ainda.'; continue }
            $i = 1
            Write-Host "`nEscolha o projeto para iniciar:" -ForegroundColor Yellow
            foreach ($p in $projects) { Write-Host "[$i] $($p.Name)"; $i++ }
            $projNum = Read-Host 'Digite o numero do projeto'
            if ($projNum -notmatch '^[0-9]+$' -or [int]$projNum -lt 1 -or [int]$projNum -gt $projects.Count) { Write-Host 'Numero invalido.'; continue }
            $proj = $projects[[int]$projNum-1]
            $projName = $proj.Name; $projPath = $proj.FullName
            $type = Get-ProjectType $projPath
            Check-ProjectDependencies $projPath
            $mode = 'dev'
            if ($type -in @('react','next','vue')) { $mode = Read-Host "Deseja rodar em modo 'dev', 'build' ou 'serve'? (dev/build/serve)" }
            Start-ProjectServer $projPath $projName $type $mode
            Read-Host "Pressione Enter para continuar..."
        }
        '6' {
            $projects = Get-ChildItem $PROJECTS_DIR -Directory
            if ($projects.Count -eq 0) { Write-Host 'Nenhum projeto para remover.'; Start-Sleep -Seconds 2; continue }
             $i = 1
            Write-Host "`nEscolha o projeto para remover:" -ForegroundColor Yellow
            foreach ($p in $projects) { Write-Host "[$i] $($p.Name)"; $i++ }
            $projNum = Read-Host 'Digite o numero do projeto'
            if ($projNum -notmatch '^[0-9]+$' -or [int]$projNum -lt 1 -or [int]$projNum -gt $projects.Count) { Write-Host 'Numero invalido.'; continue }
            $proj = $projects[[int]$projNum-1]
            $projName = $proj.Name
            $confirmRemove = Read-Host "Tem certeza que deseja remover o projeto '$projName'? (s/n)"
            if ($confirmRemove -eq 's') {
                Remove-Project -Name $projName
                Write-Host "Projeto $projName removido."
            } else { Write-Host 'Remocao cancelada.' }
            Read-Host "Pressione Enter para continuar..."
        }
        default { Write-Host 'Opcao invalida.' }
    }
}
