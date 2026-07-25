# Admin privileges check kirima
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process PowerShell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
    Exit
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# iOS-style Glass UI
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Height="520" Width="400"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        WindowStartupLocation="CenterScreen" Topmost="True">
    
    <Window.Resources>
        <Style TargetType="Button" x:Key="IOSButton">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Name="border" CornerRadius="15" Background="{TemplateBinding Background}" BorderThickness="0">
                            <TextBlock Text="{TemplateBinding Content}" FontFamily="Arial" Foreground="{TemplateBinding Foreground}" HorizontalAlignment="Center" VerticalAlignment="Center" FontWeight="Bold" FontSize="{TemplateBinding FontSize}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Opacity" Value="0.8"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    
    <Border CornerRadius="25" Background="#B3121212" BorderBrush="#40FFFFFF" BorderThickness="1.5">
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="70"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="60"/>
            </Grid.RowDefinitions>
            
            <TextBlock Text="LensLock" FontFamily="Arial" Foreground="White" FontSize="26" FontWeight="Bold" VerticalAlignment="Center" Margin="25,10,0,0"/>
            
            <!-- Minimize Button -->
            <Button Name="MinButton" Content="-" Width="30" Height="30" HorizontalAlignment="Right" Margin="0,20,50,0" VerticalAlignment="Top" 
                    Background="Transparent" Foreground="#888888" Style="{StaticResource IOSButton}" FontSize="20" Padding="0"/>

            <!-- Close Button -->
            <Button Name="CloseButton" Content="X" Width="30" Height="30" HorizontalAlignment="Right" Margin="0,20,20,0" VerticalAlignment="Top" 
                    Background="Transparent" Foreground="#888888" Style="{StaticResource IOSButton}" FontSize="15" Padding="0"/>
            
            <ScrollViewer Grid.Row="1" Margin="15,0,15,0" VerticalScrollBarVisibility="Hidden">
                <StackPanel Name="CameraPanel" Orientation="Vertical"/>
            </ScrollViewer>

            <!-- Footer -->
            <Border Grid.Row="2" BorderThickness="0,1,0,0" BorderBrush="#20FFFFFF" Margin="20,0,20,0">
                <Grid>
                    <TextBlock Text="Made by Dush" FontFamily="Arial" Foreground="#888888" FontSize="12" VerticalAlignment="Center" HorizontalAlignment="Left" Margin="5,0,0,0"/>
                    <Button Name="DonateButton" Content="&#x2615; Donate" Width="90" Height="30" HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,5,0"
                            Background="#26FFFFFF" Foreground="White" Style="{StaticResource IOSButton}" FontSize="12"/>
                </Grid>
            </Border>
        </Grid>
    </Border>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [System.Windows.Markup.XamlReader]::Load($reader)

$closeBtn = $window.FindName("CloseButton")
$minBtn = $window.FindName("MinButton")
$donateBtn = $window.FindName("DonateButton")
$cameraPanel = $window.FindName("CameraPanel")

# --- System Tray & Context Menu Setup ---
$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
$notifyIcon.Text = "LensLock Portable"
$notifyIcon.Visible = $false

# Right-click menu eka hadima
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

$openMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$openMenuItem.Text = "Open"
$openMenuItem.Add_Click({
    $window.Opacity = 1
    $window.ShowInTaskbar = $true
    $window.IsHitTestVisible = $true
    $window.WindowState = "Normal"
    $window.Activate()
    $notifyIcon.Visible = $false
})

$exitMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$exitMenuItem.Text = "Exit"
$exitMenuItem.Add_Click({
    $notifyIcon.Dispose() 
    $window.Close() 
})

# Menu items deka Context Menu ekata add kirima
$contextMenu.Items.Add($openMenuItem) | Out-Null
$contextMenu.Items.Add($exitMenuItem) | Out-Null
$notifyIcon.ContextMenuStrip = $contextMenu

# Double-click kalama open wena eka
$notifyIcon.add_DoubleClick({
    $window.Opacity = 1
    $window.ShowInTaskbar = $true
    $window.IsHitTestVisible = $true
    $window.WindowState = "Normal"
    $window.Activate()
    $notifyIcon.Visible = $false
})

$window.Add_MouseLeftButtonDown({ $this.DragMove() })

# Minimize (Hide) kalama background ekata yanawa
$minBtn.Add_Click({
    $window.Opacity = 0
    $window.ShowInTaskbar = $false
    $window.IsHitTestVisible = $false
    $notifyIcon.Visible = $true
    $notifyIcon.ShowBalloonTip(3000, "LensLock Portable", "App is running in the background. Right-click here for options.", [System.Windows.Forms.ToolTipIcon]::Info)
})

# Close button eken kelinma Exit wenawa
$closeBtn.Add_Click({ 
    $notifyIcon.Dispose() 
    $window.Close() 
})

$donateBtn.Add_Click({
    Start-Process "https://paypal.me/Dush733"
})

# State tracking to prevent UI flickering
$script:lastCamState = ""

function Load-CamerasUI {
    $cameraList = @()

    # Get Connected PnP Cameras
    $pnpCameras = @(Get-PnpDevice -Class Camera -ErrorAction SilentlyContinue) + @(Get-PnpDevice -Class Image -ErrorAction SilentlyContinue) | Where-Object { $_.Present -eq $true }
    
    foreach ($cam in $pnpCameras) {
        $cameraList += [PSCustomObject]@{
            Name      = $cam.FriendlyName
            Type      = 'PnP'
            Id        = $cam.InstanceId
            IsEnabled = ($cam.Status -eq 'OK')
        }
    }

    $DirectShowCams = @(
        @{ Name="OBS Virtual Camera"; RegName="OBS Virtual Camera"; InstanceId="{A3FCE0F5-3493-419F-958A-ABA1250EC20B}"; Paths=@("$env:ProgramFiles\obs-studio\data\obs-plugins\win-dshow\obs-virtualcam-module64.dll", "${env:ProgramFiles(x86)}\obs-studio\data\obs-plugins\win-dshow\obs-virtualcam-module32.dll") },
        @{ Name="DroidCam"; RegName="DroidCam"; Paths=@("${env:ProgramFiles(x86)}\DroidCam\DroidCamSource.ax", "${env:ProgramFiles(x86)}\DroidCam\DroidCamSource64.ax", "$env:ProgramFiles\DroidCam\DroidCamSource.ax", "$env:ProgramFiles\DroidCam\DroidCamSource64.ax", "${env:ProgramFiles(x86)}\DroidCam\DroidCamVideo.dll", "${env:ProgramFiles(x86)}\DroidCam\DroidCamVideo64.dll") },
        @{ Name="SplitCam"; RegName="SplitCam"; Paths=@("$env:ProgramFiles\SplitCam\SplitCamVideoFilter64.dll", "$env:ProgramFiles\SplitCam\SplitCamVideoFilter.dll", "${env:ProgramFiles(x86)}\SplitCam\SplitCamVideoFilter32.dll") },
        @{ Name="Snap Camera"; RegName="Snap Camera"; Paths=@("$env:ProgramFiles\Snap Inc\Snap Camera\Core\SnapCameraCore.dll", "$env:ProgramFiles\Snap Inc\Snap Camera\SnapCamera.dll") },
        @{ Name="XSplit Broadcaster"; RegName="XSplit"; Paths=@("$env:ProgramFiles\XSplit\Broadcaster\xsplit_vc.dll", "${env:ProgramFiles(x86)}\XSplit\Broadcaster\xsplit_vc.dll") }
    )

    $dshowRegPath = "HKLM:\SOFTWARE\Classes\CLSID\{860BB310-5D01-11d0-BD3B-00A0C911CE86}\Instance"
    $activeDShow = @()
    if (Test-Path $dshowRegPath) {
        $subKeys = Get-ChildItem -Path $dshowRegPath
        foreach ($sk in $subKeys) {
            $activeDShow += Get-ItemProperty -Path $sk.PSPath -ErrorAction SilentlyContinue
        }
    }

    foreach ($ds in $DirectShowCams) {
        $validPath = $null
        foreach ($p in $ds.Paths) {
            if (Test-Path $p) { $validPath = $p; break }
        }
        
        if ($null -ne $validPath) {
            $isRegEnabled = $false
            $currentInstId = $ds.InstanceId
            $displayName = $ds.Name

            foreach ($active in $activeDShow) {
                if (($null -ne $ds.InstanceId -and $active.PSChildName -eq $ds.InstanceId) -or ($active.FriendlyName -match $ds.RegName) -or ($active.FriendlyName -eq "HD webcam C252")) {
                    $isRegEnabled = $true
                    $currentInstId = $active.PSChildName
                    if ($active.FriendlyName) { $displayName = $active.FriendlyName }
                    break
                }
            }
            
            $cameraList += [PSCustomObject]@{
                Name      = $displayName
                Type      = 'DirectShow'
                Id        = $validPath
                IsEnabled = $isRegEnabled
                InstanceId = $currentInstId
            }
        }
    }

    # Generate current state text to see if anything changed
    $currentState = ""
    foreach ($cam in $cameraList) {
        $currentState += "$($cam.Id)=$($cam.IsEnabled)|"
    }

    if ($currentState -eq $script:lastCamState) {
        return
    }
    $script:lastCamState = $currentState

    $cameraPanel.Children.Clear()

    if ($cameraList.Count -eq 0) {
        $noCam = New-Object System.Windows.Controls.TextBlock
        $noCam.Text = "No cameras found."
        $noCam.Foreground = "#AAFFFFFF"
        $noCam.FontSize = 14
        $noCam.HorizontalAlignment = "Center"
        $noCam.Margin = "0,30,0,0"
        $cameraPanel.Children.Add($noCam) | Out-Null
        return
    }

    foreach ($cam in $cameraList) {
        $border = New-Object System.Windows.Controls.Border
        $border.CornerRadius = "15"
        $border.Background = (New-Object System.Windows.Media.BrushConverter).ConvertFromString("#26FFFFFF") 
        $border.Margin = "0,0,0,12"
        $border.Padding = "15"

        $grid = New-Object System.Windows.Controls.Grid
        $col1 = New-Object System.Windows.Controls.ColumnDefinition
        $col1.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        $col2 = New-Object System.Windows.Controls.ColumnDefinition
        $col2.Width = [System.Windows.GridLength]::Auto
        $grid.ColumnDefinitions.Add($col1)
        $grid.ColumnDefinitions.Add($col2)

        $lbl = New-Object System.Windows.Controls.TextBlock
        $lbl.Text = $cam.Name
        $lbl.FontFamily = "Arial"
        $lbl.Foreground = "White"
        $lbl.FontSize = 14
        $lbl.FontWeight = "SemiBold"
        $lbl.VerticalAlignment = "Center"
        $lbl.TextWrapping = "Wrap"
        $lbl.Margin = "0,0,10,0"
        [System.Windows.Controls.Grid]::SetColumn($lbl, 0)

        $btn = New-Object System.Windows.Controls.Button
        $btn.Width = 70
        $btn.Height = 30
        $btn.Tag = $cam 
        $btn.Style = $window.FindResource("IOSButton")
        [System.Windows.Controls.Grid]::SetColumn($btn, 1)

        if ($cam.IsEnabled) {
            $btn.Content = "ON"
            $btn.Background = (New-Object System.Windows.Media.BrushConverter).ConvertFromString("#34C759")
            $btn.Foreground = "White"
        } else {
            $btn.Content = "OFF"
            $btn.Background = (New-Object System.Windows.Media.BrushConverter).ConvertFromString("#3A3A3C")
            $btn.Foreground = "White"
        }

        $btn.Add_Click({
            $script:refreshTimer.Stop() 
            
            $clickedCam = $this.Tag
            $this.Content = "..."
            $this.IsEnabled = $false
            
            if ($clickedCam.Type -eq 'PnP') {
                if ($clickedCam.IsEnabled) {
                    Disable-PnpDevice -InstanceId $clickedCam.Id -Confirm:$false
                } else {
                    Enable-PnpDevice -InstanceId $clickedCam.Id -Confirm:$false
                }
            } elseif ($clickedCam.Type -eq 'DirectShow') {
                if ($clickedCam.IsEnabled) {
                    Start-Process "regsvr32.exe" -ArgumentList "/u /s `"$($clickedCam.Id)`"" -Wait -NoNewWindow
                } else {
                    Start-Process "regsvr32.exe" -ArgumentList "/s `"$($clickedCam.Id)`"" -Wait -NoNewWindow
                    Start-Sleep -Milliseconds 800

                    if ($clickedCam.InstanceId -eq "{A3FCE0F5-3493-419F-958A-ABA1250EC20B}") {
                        $cat = "{860BB310-5D01-11d0-BD3B-00A0C911CE86}"
                        $obsInst = "{A3FCE0F5-3493-419F-958A-ABA1250EC20B}"
                        $regPath64 = "HKLM:\SOFTWARE\Classes\CLSID\$cat\Instance\$obsInst"
                        $regPath32 = "HKLM:\SOFTWARE\WOW6432Node\Classes\CLSID\$cat\Instance\$obsInst"
                        
                        $filterData = [byte[]](0x02,0x00,0x00,0x00,0x00,0x00,0x20,0x00,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x30,0x70,0x69,0x33,0x08,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x30,0x74,0x79,0x33,0x00,0x00,0x00,0x00,0x38,0x00,0x00,0x00,0x48,0x00,0x00,0x00,0x76,0x69,0x64,0x73,0x00,0x00,0x10,0x00,0x80,0x00,0x00,0xaa,0x00,0x38,0x9b,0x71,0x4e,0x56,0x31,0x32,0x00,0x00,0x10,0x00,0x80,0x00,0x00,0xaa,0x00,0x38,0x9b,0x71)

                        if (Test-Path $regPath64) {
                            Set-ItemProperty -Path $regPath64 -Name "FriendlyName" -Value "HD webcam C252" -Force | Out-Null
                            Set-ItemProperty -Path $regPath64 -Name "FilterData" -Value $filterData -Force | Out-Null
                        }
                        if (Test-Path $regPath32) {
                            Set-ItemProperty -Path $regPath32 -Name "FriendlyName" -Value "HD webcam C252" -Force | Out-Null
                            Set-ItemProperty -Path $regPath32 -Name "FilterData" -Value $filterData -Force | Out-Null
                        }
                    }
                }
            }
            
            Start-Sleep -Seconds 1 
            $script:lastCamState = "" 
            Load-CamerasUI
            $script:refreshTimer.Start() 
        })

        $grid.Children.Add($lbl) | Out-Null
        $grid.Children.Add($btn) | Out-Null
        $border.Child = $grid
        $cameraPanel.Children.Add($border) | Out-Null
    }
}

# Auto-Refresh Timer Setup (Every 3 Seconds)
$script:refreshTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:refreshTimer.Interval = [TimeSpan]::FromSeconds(3)
$script:refreshTimer.Add_Tick({ Load-CamerasUI })

Load-CamerasUI
$script:refreshTimer.Start()
$window.ShowDialog() | Out-Null