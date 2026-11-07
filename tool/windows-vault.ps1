param([ValidateSet('protect','unprotect')][string]$Operation)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Security
$inputText = [Console]::In.ReadToEnd()
$scope = [Security.Cryptography.DataProtectionScope]::CurrentUser
if ($Operation -eq 'protect') {
  $bytes = [Text.Encoding]::UTF8.GetBytes($inputText)
  $outputBytes = [Security.Cryptography.ProtectedData]::Protect($bytes, $null, $scope)
  [Console]::Out.Write([Convert]::ToBase64String($outputBytes))
} else {
  $bytes = [Convert]::FromBase64String($inputText)
  $outputBytes = [Security.Cryptography.ProtectedData]::Unprotect($bytes, $null, $scope)
  [Console]::Out.Write([Text.Encoding]::UTF8.GetString($outputBytes))
}
