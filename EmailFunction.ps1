<#	
	.NOTES
	===========================================================================
	 Created on:   	12/14/2016 12:55 PM
	 Created by:   	Vikas Sukhija
	 Organization: 	
	 Filename:     	
	===========================================================================
	.DESCRIPTION
		Send-Email function for PS2.0
		Example:
		Send-Email -From "user2@labtest.com" -To "user1@labtest.com","user2@labtest.com" 
		-subject "Test Email Function" -body "Test" -smtpserver smtpserver -cc "user1@labtest.com","user2@labtest.com" 
		-bcc "user1@labtest.com","user2@labtest.com" -attachment "c:\attach.txt"
#>
function Send-Email
{
	[CmdletBinding()]
	param
	(
		$From,
		[array]$To,
		[array]$bcc,
		[array]$cc,
		$body,
		$subject,
		$attachment,
		$smtpserver
	)
	$message = new-object System.Net.Mail.MailMessage
	$message.From = $from
	if ($To -ne $null)
	{
		$To | ForEach-Object{
			$to1 = $_
			$to1
			$message.To.Add($to1)
		}
	}
	if ($cc -ne $null)
	{
		$cc | ForEach-Object{
			$cc1 = $_
			$cc1
			$message.CC.Add($cc1)
		}
	}
	if ($bcc -ne $null)
	{
		$bcc | ForEach-Object{
			$bcc1 = $_
			$bcc1
			$message.bcc.Add($bcc1)
		}
	}
	$message.IsBodyHtml = $True
	if ($subject -ne $null)
	{
		$message.Subject = $Subject
	}
	if ($attachment -ne $null)
	{
		$attach = new-object Net.Mail.Attachment($attachment)
		$message.Attachments.Add($attach)
	}
	if ($body -ne $null)
	{
		$message.body = $body
	}
	$smtp = new-object Net.Mail.SmtpClient($smtpserver)
	$smtp.Send($message)
}
##################################################################################