## mboxed

One-click installation of [ScienceBox](https://github.com/sciencebox/sciencebox) on a single host, based on minikube. MBoxed is a self-contained, containerized demo for cloud storage and computing services for scientific and general-purpose use:

* [CERNBox](https://cernbox.web.cern.ch)
* [CVMFS](https://cvmfs.web.cern.ch)
* [EOS](https://eos.web.cern.ch)
* [SWAN](https://swan.web.cern.ch)


### Quick Setup
1. Clone this repository using `git clone https://github.com/sciencebox/mboxed.git`
2. Run (as sudo)
  ```
  SetupInstall.sh
  ScienceBox.sh
  ```
3. Open a browser and go to https://<your_host>/sciencebox to access sciencebox services.


### Stopping the services

In order to stop the ScienceBox service, run:

```bash
sudo bash ./ScienceBox_Stop.sh
```

### Deleting the services

In order to delete the ScienceBox service, run:

```bash
sudo bash ./ScienceBox_Delete.sh
```

### Documentation

To learn more about sciencebox and it's services, check out the documentation [here](https://sciencebox.web.cern.ch/). To learn more about the Helm charts themselves, check out [artifact hub](https://artifacthub.io/packages/helm/sciencebox/sciencebox).

### Limitations and known issues
- Software packages required by SWAN are fetched on demand via CVMFS. In case of slow Internet connection, starting a SWAN session may timeout and fail. Retrying immediately after helps in spawning the session successfully.
- The login page shows an ownCloud UI theme. We are working to align the login page theme to the CERNBox theme.

Since Minikube is configured to run with the `none` driver, one needs to have the root privileges to access the services deployed as a part of ScienceBox. More information about the `none` driver can be found [here](https://minikube.sigs.k8s.io/docs/drivers/none/).

Since, we need to root privilege to run ScienceBox, the user might run into following error when running `sudo ./ScienceBox.sh` or `sudo ./ScienceBox_Delete.sh`:
```
❌  Exiting due to HOST_JUJU_LOCK_PERMISSION: writing kubeconfig: Error writing file /root/.kube/config: failed to acquire lock for /root/.kube/config: {Name:mk72a1487fd2da23da9e8181e16f352a6105bd56 Clock:{} Delay:500ms Timeout:1m0s Cancel:<nil>}: unable to open /tmp/juju-mk72a1487fd2da23da9e8181e16f352a6105bd56: permission denied
```
In order to fix the above issue, user can run `sudo sysctl fs.protected_regular=0`. 

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
- CentOS 7, 8 or Ubuntu 20.04


### Tested (and developed) on
- OS: CentOS 7.9 (kernel version: 3.10), Ubuntu 20.04 (kernel version: 5.13.0-35-generic)
- Docker: 20.10.12
- Kubectl: 1.20.15
- minikube: 1.25.2
- Helm: 3.8.0


### Feedback, contributions, and issues
Feedback is welcome on ScienceBox and mboxed!
- For bug reports and suggestions for improvments, please open a GitHub Issue
- For contributing to the project and providing fixes, please send a Pull Request
