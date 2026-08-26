$ErrorActionPreference = "Stop"

Write-Host "Fetching IAM github-action-user ARN..."

$userArn = aws iam get-user `
    --user-name github-action-user `
    --query "User.Arn" `
    --output text

if (-not $userArn) {
    throw "Could not find github-action-user"
}

Write-Host "User ARN: $userArn"

Write-Host ""
Write-Host "Checking EKS connection..."

kubectl get nodes

if ($LASTEXITCODE -ne 0) {
    throw "Could not connect to EKS cluster"
}

Write-Host ""
Write-Host "Getting current aws-auth ConfigMap..."

$awsAuth = kubectl get configmap aws-auth `
    -n kube-system `
    -o yaml

if ($LASTEXITCODE -ne 0) {
    throw "Could not get aws-auth ConfigMap"
}

$awsAuth | Out-File "$env:TEMP\aws-auth.yaml" -Encoding utf8

Write-Host ""
Write-Host "Creating patch..."

# Create the JSON patch as a PowerShell object.
# This avoids Windows CMD/PowerShell quote escaping problems.
$mapUser = @(
    @{
        userarn  = $userArn
        username = "github-action-user"
        groups   = @("system:masters")
    }
)

$patchObject = @{
    data = @{
        mapUsers = ($mapUser | ConvertTo-Json -Compress)
    }
}

$patchJson = $patchObject | ConvertTo-Json -Compress

Write-Host "Updating aws-auth ConfigMap..."

kubectl patch configmap aws-auth `
    -n kube-system `
    --type merge `
    -p $patchJson

if ($LASTEXITCODE -ne 0) {
    throw "Failed to update aws-auth ConfigMap"
}

Write-Host ""
Write-Host "Successfully added github-action-user to EKS."
Write-Host ""

Write-Host "Verifying..."

kubectl get configmap aws-auth `
    -n kube-system `
    -o yaml

if ($LASTEXITCODE -ne 0) {
    throw "Could not verify aws-auth ConfigMap"
}

Write-Host ""
Write-Host "Done!"