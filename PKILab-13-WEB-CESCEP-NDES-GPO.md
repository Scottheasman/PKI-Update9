1. CEP URL for the GPO
For the Certificate Enrollment Policy Web Service GPO setting, you should use the CEP endpoint with /CEP at the end:

https://enroll.lab.local/ADPolicyProvider_CEP_Kerberos/service.svc/CEP

So in GPO:

Computer Configuration →
Policies → Windows Settings → Security Settings →
Public Key Policies → Certificate Services Client – Certificate Enrollment Policy
Add a new Enrollment Policy Server:
URL: https://enroll.lab.local/ADPolicyProvider_CEP_Kerberos/service.svc/CEP
Authentication: Windows Integrated
Check “Enable this policy server”