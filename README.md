## mboxed

One-click installation of ScienceBox on a single host, based on minikube.


### Quick Setup
1. Clone this repository
2. Run (as sudo)
  ```
  SetupInstall.sh
  ScienceBox.sh
  ```
3. Open a browser and go to https://<your_host>


### Limitations and known issues
- A valid TLS certificate must be provided to the nginx ingress controller (upstream documentation at https://kubernetes.github.io/ingress-nginx/user-guide/tls/)
  - If no valid TLS certificate is provided, SWAN's jupyterhub will refuse to start and integration with EOS storage will not be possible.
  - A workaround to tolerate self-signed certificates (or default nginx ingress certificate) is being worked on.
- Storage persistency is not provided in minikube at the moment. Data stored in ScienceBox will be lost when containers are removed // restarted.
- Software packages required by SWAN are fetched on demand via CVMFS. In case of slow Internet connection, starting a SWAN session may timeout and fail. Retrying immediately after helps in spawning the session successfully.


### Default users
Several default users are pre-configured in the Identity Provider. You can use these to access ScienceBox services.
- admin:admin
- reva:reva
- einstein:relativity
- marie:radioactivity
- moss:vista
- richard:superfluidity


### Requirements
- 4 GB memory
- 40 GB of free space on disk
- CentOS 7, 8


### Tested (and developed) on
- OS: CentOS 7.9 (kernel version: 3.10)
- Docker: 19.03.15
- Kubectl: 1.19.8
- minikube: 1.18.0
- Helm: 3.5.3


### Feedback, contributions, and issues
Feedback is welcome on ScienceBox and mboxed!
- For bug reports and suggestions for improvments, please open a GitHub Issue
- For contributing to the project and providing fixes, please send a Pull Request
