# Phase 1: Build Haldane Ltd

**Result:** a working Active Directory domain, `haldane.local`, with a domain
controller, a domain-joined member server and fictional staff accounts. A
staff member (`HALDANE\a.patel`) can sign in to the staff workstation through
the domain.

## What was built

| Machine | Private IP | Role |
| --- | --- | --- |
| DC01 | 10.10.1.4 | Domain controller and DNS server for `haldane.local` |
| WS01 | 10.10.1.10 | Member server acting as the shared staff workstation |

Both are Windows Server 2022 (Azure Edition), size B2s_v2, deployed from
[`infra/servers.bicep`](../infra/servers.bicep), with fixed private IPs and
automatic shutdown at 23:00 every night.

**Directory structure** (created by
[`02-create-ous-users.ps1`](../scripts/windows/02-create-ous-users.ps1)):

```text
haldane.local
└── Haldane
    ├── Staff              6 fictional employees
    ├── Groups             IT Admins, Finance, HR, Engineering
    ├── Servers
    └── Service Accounts   svc-backup
```

## Build steps

1. `./scripts/deploy-servers.sh`: deploy both VMs (about 5 minutes).
2. On DC01: [`01-promote-dc.ps1`](../scripts/windows/01-promote-dc.ps1)
   installs AD DS and creates the forest; DC01 restarts as a domain controller.
3. On DC01: [`02-create-ous-users.ps1`](../scripts/windows/02-create-ous-users.ps1).
4. On the Mac: `DNS_SERVER=10.10.1.4 ./scripts/deploy-network.sh`, then restart
   WS01 so it uses DC01 for DNS.
5. On WS01: [`03-join-domain.ps1`](../scripts/windows/03-join-domain.ps1), then
   [`04-allow-staff-rdp.ps1`](../scripts/windows/04-allow-staff-rdp.ps1).
6. Test: sign in to WS01 as `HALDANE\a.patel`; `whoami` returns `haldane\a.patel`.

## Design decisions

| Decision | Why |
| --- | --- |
| WS01 runs Windows Server, not Windows 11 | Defender for Servers covers server operating systems only; Windows 11 would need a separate Defender for Endpoint client licence, and Windows client VMs in Azure have extra licensing conditions |
| Fixed private IP for DC01 | Every machine uses DC01 for DNS, so its address must never change |
| The network's DNS points at DC01 | Domain members find the domain through DNS; Azure's default DNS knows nothing about `haldane.local` |
| Nightly auto-shutdown | A safety net against forgotten running VMs on a pay-as-you-go subscription |

## Problems and fixes

| Problem | Cause | Fix |
| --- | --- | --- |
| First RDP attempt to WS01 failed immediately | WS01 was still restarting after the DNS change | Waited for the VM to finish booting |
| Staff accounts couldn't sign in to WS01 over RDP | Windows Server only allows administrators to use Remote Desktop by default | Added `HALDANE\Domain Users` to WS01's Remote Desktop Users group ([`04-allow-staff-rdp.ps1`](../scripts/windows/04-allow-staff-rdp.ps1)) |

## Still to do

- Move WS01 from the default Computers container into `Haldane\Servers`.
- Add 2 or 3 deliberately weak settings, documented here, for the
  vulnerability scans in Phase 3 to find.
