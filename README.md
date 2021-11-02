# Pterodactyl-Script
Installing Pterodactyl in just a few minutes! <br />
Please note this script is meant to be used on fresh installations only. You must run it as root. <br />
<br />
`curl -Ls https://api.github.com/repos/TommyTran732/Pterodactyl-Script/releases/latest | grep -wo "https.*install.sh" | wget -qi -` <br />
<br /> 
`bash install.sh` <br />
<br />
Visit my Matrix group: https://matrix.to/#/#tommytran732:matrix.org
<br />
# Supported Operating System
RHEL, CentOS Stream and Rocky Linux are recommended over Ubuntu and Debian due to the new Appstream system introduced in RHEL 8. With modular repos, package management with dnf becomes so much easier and cleaner compared to apt. <br />

Fedora is not recommended due to its short life cycle. However, if you live on the edge and can handle frequent major updates on your own, then it is fine.

| Operating System  | Version  | Supported            | Recommended        | Notes                                |
| ----------------- | -------- | -------------------- | ------------------ | ------------------------------------ |
| Fedora            | 35       | :heavy_check_mark:   | 🔴                 |                                      |
| CentOS            | Stream 8 | :heavy_check_mark:   | ✔️                  |                                      |
| RHEL              | 8        | :heavy_check_mark:   | ✔️                  |                                      |
| Rocky Linux       | 8        | :heavy_check_mark:   | ✔️                  |                                      |
| Ubuntu            | 20.04    | :heavy_check_mark:   | 🔴                 |                                      |
| Debian            | 11       | :heavy_check_mark:   | 🔴                 |                                      |
