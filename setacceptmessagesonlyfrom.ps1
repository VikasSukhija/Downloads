################################################################################################
##                                                                                            ##
##           Author: Vikas Sukhija                  		                              ##
##           Date: 02-05-2013                       		      			      ##
##           Description:- Add user to acceptmessages only from                               ##
##                 		 	      		                                      ##			      
################################################################################################



# import csv file

$data = import-csv $args[0]

$group = "GroupNameHere"


#

foreach ($i in $data)

{

$id = $i.name
$mailbox = get-mailbox $id
Write-host $mailbox
Set-DistributionGroup $group -AcceptMessagesOnlyFrom((Get-DistributionGroup $group).AcceptMessagesOnlyFrom + $id )


}

####################################################################################################