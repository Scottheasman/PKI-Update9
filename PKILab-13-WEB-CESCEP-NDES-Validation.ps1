$urls = @(
    "https://enroll.lab.local/ADPolicyProvider_CEP_Kerberos/service.svc",
    "https://enroll.lab.local/Lab%20Issuing%20CA%201_CES_Kerberos/service.svc",
    "https://enroll.lab.local/Lab%20Issuing%20CA%202_CES_Kerberos/service.svc",
    "https://scep1.lab.local/certsrv/mscep/mscep.dll",
    "https://scep2.lab.local/certsrv/mscep/mscep.dll"
)

$results = foreach ($u in $urls) {
    try {
        $r = Invoke-WebRequest -Uri $u -UseDefaultCredentials -UseBasicParsing -Method Get -TimeoutSec 10
        [PSCustomObject]@{
            Url        = $u
            StatusCode = $r.StatusCode
        }
    } catch {
        [PSCustomObject]@{
            Url        = $u
            StatusCode = "ERROR: " + $_.Exception.Message
        }
    }
}

$results