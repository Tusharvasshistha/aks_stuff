# clean workspace on agents
param (
    [Parameter(Mandatory=$true)]
    [string]$AKS_NAME,
    [Parameter(Mandatory=$true)]
    [string]$NAMESPACE
)

Write-Host "***[ Check if kube config matches ]***" -fore yellow
[string]$CTX=(kubectl config current-context)
$compareCTX = (${AKS_NAME} -eq ${CTX}) -or ("${AKS_NAME}-admin" -eq ${CTX})


if ($compareCTX) {
    Write-Host "***[ The Current Context is matching: ${CTX} ]***" -fore green
    
    Write-Host "***[ Check if namespace exists ]***" -fore yellow
    $chkNamespace = (kubectl get namespaces -o json | ConvertFrom-Json).items.metadata.name | where {$_ -eq $NAMESPACE}
    if (!$chkNamespace) {
        Write-Error "***[ The Namespace ${NAMESPACE} was not found ]***"
        break
    }
} else {
    Write-Error "***[ The Current Context is not matching with: ${CTX} ]***"
    break
}

Write-Host "***[ Working on Namespace ${NAMESPACE} in cluster ${AKS_NAME} ]***" -fore green


$pods=(kubectl get pods -n $NAMESPACE -o json | ConvertFrom-Json).items.metadata.name
foreach ($p in $pods) {
    Write-Host "***[ working on $p ]***"
    
    if ($p -like "*win-*") {
        Write-Host "***[ Windows Container ]***"
        kubectl exec -i $p -n $NAMESPACE -- powershell -c "Restart-Computer -Force"
    } else {
        $chkPvc=(kubectl exec -i $p -n $NAMESPACE -- /bin/bash -c "df -h | grep /azp/_work")
        if ($chkPvc) {
            Write-Host "***[ Space before clean-up ]***"
            kubectl exec -i $p -n $NAMESPACE -- /bin/bash -c "df -h | grep /azp/_work"
            kubectl exec -i $p -n $NAMESPACE -- /bin/bash -c "rm -rf /azp/_work/*"
            Write-Host "***[ Space after clean-up ]***"
            kubectl exec -i $p -n $NAMESPACE -- /bin/bash -c "df -h | grep /azp/_work"
        }
        kubectl exec -i $p -n $NAMESPACE -- /bin/bash -c "/sbin/killall5"
    }
}
