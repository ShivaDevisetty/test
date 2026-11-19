az resource list --resource-type Microsoft.App/jobs --query "[].{Name:name,ResourceGroup:resourceGroup,Subscription:subscriptionId}" --output table
