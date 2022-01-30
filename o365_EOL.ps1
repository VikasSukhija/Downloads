Function LaunchO365 {

$UserCredential = Get-Credential

$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $UserCredential -Authentication Basic -AllowRedirection

Import-PSSession $Session

}

Function RemoveO365 {

$Session = Get-PSSession | where {$_.ComputerName -like "outlook.office365.com"}
Remove-PSSession $Session

}