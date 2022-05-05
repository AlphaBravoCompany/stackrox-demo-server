# StackRox Demo Server

## About StackRox OSS

The StackRox Kubernetes Security Platform performs a risk analysis of the container environment, delivers visibility and runtime alerts, and provides recommendations to proactively improve security by hardening the environment. StackRox integrates with every stage of container lifecycle: build, deploy and runtime.

Note: the StackRox Kubernetes Security platform is built on the foundation of the product formerly known as Prevent, which itself was called Mitigate and Apollo. You may find references to these previous names in code or documentation.

- Docs: https://open-docs.StackRox.com
- Git Repo: https://github.com/stackrox/stackrox
- StackRox Open Source Announcement: https://www.stackrox.io/blog/open-source-stackrox-is-now-available/
- StackRox Community Website: https://www.stackrox.io/

## Learn more about StackRox

- StackRox - Quick Demo: https://www.youtube.com/watch?v=3QNIzsyyIpU
- OCB: StackRox Overview and Demo: https://www.youtube.com/watch?v=Fu62ztu_xFc
- StackRox Overview and Demo Ali Golshan (StackRox) and Kirsten Newcomer (Red Hat) | OpenShift Commons: https://www.youtube.com/watch?v=7NL-DwJvrig
- StackRox Office Hours (Ep 8): Get Started with the Open Source StackRox Project: https://www.youtube.com/watch?v=pdW3ehxRLFU
- StackRox Community YouTube Channel: https://www.youtube.com/channel/UC2RxjDIpHyv5UXny4AxGuyA/videos 

## Intended usage of this script

This script is for demo purposes only. It deploys a bare minimum, single-node K3s Kubernetes cluster, Longhorn Storage, and StackRox OSS and provides links to the interfaces and login information.

## Prerequisites
- Ubuntu 20.04+ Server
- Minimum Recommended 8vCPU and 8GB (16GB may be better if you want to run test workloads) of RAM (Try Hetzner or DigitalOcean)
- DNS or Hosts file entry pointing to server IP

## Installed as part of script

- Helm
- K3s
- Rancher UI
- Longhorn Storage
- cert-manager
- StackRox OSS

## Full Server Setup with roxctl tool

1. `git clone https://github.com/AlphaBravoCompany/StackRox-demo-server.git`
2. `cd StackRox-demo-server`
3. `chmod +x install-StackRox.sh`
4. `./install-StackRox.sh subdomain.yourdomain.tld`
5. Install will take approximately 10 minutes and will output links and login information for Rancher and your StackRox installation.
6. Details for accessing StackRox and Rancher will be printed to the screen once the script completes and saved to `server-details.txt`

## Updating the StackRox OSS Version

- Visit the `https://quay.io/organization/stackrox-io/` registry page and find the image tag you want to use. Choosing main and viewing the tags will likely be sufficient as it seems all images have the same tagging applied.
- Edit the `install-stackrox.sh` file and update the `rox_version` variable to use the new image tag.
- Uninstall using the below method and rerun the `install-stackrox.sh` script as before.

## Uninstall Methods

1. From within the `stackrox-demo-server` directory, run `/usr/local/bin/k3s-uninstall.sh && rm -rf central-bundle/ sensor-k3s/ && rm server-details.txt` (removes K3s, Rancher, Longhorn and StackRox)

## Special Thanks

Thanks to Andy Clemenko for his expertise and repos for providing the foundation for this script.

- StackRox OSS Script: https://github.com/clemenko/sr_tools/blob/main/StackRox_oss.sh
- Andy's Github: https://github.com/clemenko/sr_tools

## About Alphabravo

**AlphaBravo** provides products, services, and training for Kubernetes, Cloud, and DevSecOps.

Contact **AB** today to learn how we can help you.

* **Web:** https://alphabravo.io
* **Email:** info@alphabravo.io
* **Phone:** 301-337-8141
