# Variables.
$BaseDirectory = "C:\BASE"
$AppDirectory = "$BaseDirectory\APP"
$SrcDirectory = "$BaseDirectory\SRC"
$IISDirectory = "$AppDirectory\IIS"
$PHPDirectory = "$AppDirectory\PHP"
$PHPSessionDirectory = "$PHPDirectory\session"
$PHPUploadDirectory = "$PHPDirectory\upload"
$PHPLogDirectory = "$PHPDirectory\log"

# Create the APP and SRC directories.
New-Item -ItemType Directory -Path $BaseDirectory
New-Item -ItemType Directory -Path $AppDirectory
New-Item -ItemType Directory -Path $SrcDirectory
New-Item -ItemType Directory -Path $IISDirectory
New-Item -ItemType Directory -Path $PHPDirectory
New-Item -ItemType Directory -Path $PHPSessionDirectory
New-Item -ItemType Directory -Path $PHPUploadDirectory
New-Item -ItemType Directory -Path $PHPLogDirectory

Install-WindowsFeature -Name Web-Default-Doc, Web-Dir-Browsing, Web-Http-Errors, Web-Static-Content, Web-Http-Redirect, Web-Http-Logging,`
    Web-Stat-Compression, Web-Dyn-Compression, Web-Filtering, Web-Basic-Auth, Web-Net-Ext, Web-Net-Ext45, Web-Asp-Net, Web-Asp-Net45,`
    Web-CGI, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Mgmt-Console
  
###########################################################################################
### Install PHP  ##########################################################################
###########################################################################################

# Download Visual C++ Redistributable for Visual Studio 2015 x64.
Invoke-WebRequest -Uri $VisualStudioRedistributableDownloadLocation -OutFile $SrcDirectory\$VisualStudioRedistributablePackage

# Install Visual C++ Redistributable for Visual Studio 2015 x64.
Start-Process -FilePath $SrcDirectory\$VisualStudioRedistributablePackage -ArgumentList "/q /norestart" -Wait

$PHPUserGroup = "PHP Users"
$PHPDownloadLocation = "http://windows.php.net/downloads/releases/php-7.3.10-nts-Win32-VC15-x64.zip"
$PHPPackage = "php-7.3.10-nts-Win32-VC15-x64.zip"
$PHPDefaultDocument = "index.php"
$PHPErrorLogFile = "error.log"

# Create the PHP Users local Windows group.
$LocalAccountDB = [ADSI]"WinNT://$env:ComputerName"
$CreateGroupPHPUsers = $LocalAccountDB.Create("Group","$PHPUserGroup")
$CreateGroupPHPUsers.SetInfo()
$CreateGroupPHPUsers.Description = "Members of this group can use PHP on their website"
$CreateGroupPHPUsers.SetInfo()

# Set Read/Execute NTFS permissions for the group PHP Users on the PHP directory.
$ACL = Get-Acl -Path $PHPDirectory
$NTAccount = New-Object System.Security.Principal.NTAccount("$PHPUserGroup") 
$FileSystemRights = [System.Security.AccessControl.FileSystemRights]"ReadAndExecute"
$InheritanceFlags = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit,ObjectInherit"
$PropagationFlags = [System.Security.AccessControl.PropagationFlags]::None 
$AccessControlType =[System.Security.AccessControl.AccessControlType]::Allow
$UserPermissions = $NTAccount,$FileSystemRights,$InheritanceFlags,$PropagationFlags,$AccessControlType
$AccessRule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $UserPermissions
$ACL.SetAccessRule($AccessRule)
$ACL | Set-Acl -Path $PHPDirectory

# Set Modify NTFS permissions for PHP Users on the session directory.
$ACL = Get-Acl -Path $PHPSessionDirectory
$NTAccount = New-Object System.Security.Principal.NTAccount("$PHPUserGroup") 
$FileSystemRights = [System.Security.AccessControl.FileSystemRights]"Modify"
$InheritanceFlags = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit,ObjectInherit"
$PropagationFlags = [System.Security.AccessControl.PropagationFlags]::None 
$AccessControlType =[System.Security.AccessControl.AccessControlType]::Allow
$UserPermissions = $NTAccount,$FileSystemRights,$InheritanceFlags,$PropagationFlags,$AccessControlType
$AccessRule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $UserPermissions
$ACL.SetAccessRule($AccessRule)
$ACL | Set-Acl -Path $PHPSessionDirectory

# Set Modify NTFS permissions for PHP Users on the upload directory.
$ACL = Get-Acl -Path $PHPUploadDirectory
$NTAccount = New-Object System.Security.Principal.NTAccount("$PHPUserGroup") 
$FileSystemRights = [System.Security.AccessControl.FileSystemRights]"Modify"
$InheritanceFlags = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit,ObjectInherit"
$PropagationFlags = [System.Security.AccessControl.PropagationFlags]::None 
$AccessControlType =[System.Security.AccessControl.AccessControlType]::Allow
$UserPermissions = $NTAccount,$FileSystemRights,$InheritanceFlags,$PropagationFlags,$AccessControlType
$AccessRule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $UserPermissions
$ACL.SetAccessRule($AccessRule)
$ACL | Set-Acl -Path $PHPUploadDirectory

# Set Modify NTFS permissions for PHP Users on the log directory.
$ACL = Get-Acl -Path $PHPLogDirectory
$NTAccount = New-Object System.Security.Principal.NTAccount("$PHPUserGroup") 
$FileSystemRights = [System.Security.AccessControl.FileSystemRights]"Modify"
$InheritanceFlags = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit,ObjectInherit"
$PropagationFlags = [System.Security.AccessControl.PropagationFlags]::None 
$AccessControlType =[System.Security.AccessControl.AccessControlType]::Allow
$UserPermissions = $NTAccount,$FileSystemRights,$InheritanceFlags,$PropagationFlags,$AccessControlType
$AccessRule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $UserPermissions
$ACL.SetAccessRule($AccessRule)
$ACL | Set-Acl -Path $PHPLogDirectory

# Create the PHP log file.
New-Item -ItemType File -Path "$PHPLogDirectory\$PHPErrorLogFile"

# Download the PHP Non Thread Safe .zip package (x64).
Invoke-WebRequest -Uri $PHPDownloadLocation -OutFile "$SrcDirectory\$PHPPackage"

# Extract the .zip file to the PHP directory. In PowerShell 5 (Windows 10, Windows Server 2016) we have the Expand-Archive cmdlet for this,
# but since there is no production version yet of PowerShell 5 for previous operating systems, we use .NET for this.
Add-Type -AssemblyName "system.io.compression.filesystem"
[io.compression.zipfile]::ExtractToDirectory("$SrcDirectory\$PHPPackage", $PHPDirectory)

# Add the PHP installation directory to the Path environment variable.
$CurrentPath = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).PATH
$NewPath = $CurrentPath + ";$PHPDirectory\"
Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH -Value $NewPath

# Create a Handler Mapping for PHP.
New-WebHandler -Name "PHPFastCGI" -Path "*.php" -Modules FastCgiModule -ScriptProcessor "$PHPDirectory\php-cgi.exe" -Verb 'GET,HEAD,POST' -ResourceType Either

# Configure FastCGI Settings for PHP.
Add-WebConfiguration -Filter /system.webServer/fastCgi -PSPath IIS:\ -Value @{fullpath="$PHPDirectory\php-cgi.exe"}

# Add index.php to the Default Documents.
Add-WebConfiguration -Filter /system.webServer/defaultDocument/files -PSPath IIS:\ -Value @{value="$PHPDefaultDocument"} 

# Create php.ini and configure values.
$PHPIniBaseFile = Get-Content -Path "$PHPDirectory\php.ini-production"
$PHPIniValues = @{'max_execution_time = 30' = 'max_execution_time = 600';
'max_input_time = 60' = 'max_input_time = 600';
'; max_input_vars = 1000' = "max_input_vars = 2000";
'memory_limit = 128M' = "memory_limit = 256M";
';error_log = php_errors.log' = 'error_log = "C:\DATA\APP\PHP\log\error.log"';
'post_max_size = 8M' = 'post_max_size = 128M';
'; extension_dir = "ext"' = 'extension_dir = "C:\DATA\APP\PHP\ext"';
';cgi.force_redirect = 1' = 'cgi.force_redirect = 0';
';cgi.fix_pathinfo=1' = 'cgi.fix_pathinfo = 1';
';fastcgi.impersonate = 1' = 'fastcgi.impersonate = 1';
';upload_tmp_dir =' = 'upload_tmp_dir = "C:\DATA\APP\PHP\upload"';
'upload_max_filesize = 2M' = 'upload_max_filesize = 128M';
';session.save_path = "/tmp"' = 'session.save_path = "C:\DATA\APP\PHP\session"'   
}
foreach ($Entry in $PHPIniValues.Keys)
{
    $PHPIniBaseFile = $PHPIniBaseFile -replace $Entry, $PHPIniValues[$Entry]
}
Set-Content -Path "$PHPDirectory\php.ini" -Value $PHPIniBaseFile 

#################################################################################################
### Configure PHP Page ##########################################################################
#################################################################################################

# Variables.
$DomainDirectory = "C:\inetpub\"
$DomainWebDirectory = "$DomainDirectory\wwwroot"

# Create a page to test PHP.
$PhpTestFileContent = @"
<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="UTF-8">
        <title>My great web site</title>
        <meta name="description" contents="Just a test website for learning html, css and php">
        <link rel="stylesheet" href="css/style.css" type="text/css">
    </head>
    <body>
      <div>
        <h2>Client information</h2>
        <p><strong>Browser client:</strong><?php echo $_SERVER['HTTP_USER_AGENT']; ?></p>
      </div>
      <div>
        <h2>Server information</h2>
        <p><strong>PHP info:</strong></p>
        <div>
          <?php phpinfo(); ?>
        </div>
      </div>
      <footer>
          Server name: <?php echo php_uname("n"); ?>
      </footer>            
    </body>
</html>
"@
New-Item -ItemType File -Path $DomainWebDirectory -Name index.php -Value $PhpTestFileContent
