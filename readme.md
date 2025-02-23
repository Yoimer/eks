# 📌 Amazon EKS Cluster Deployment Guide

Welcome to the **Amazon EKS Deployment Repository**! This repository contains essential configurations and documentation for deploying and managing an Amazon EKS cluster. 🚀

---

## 📂 Repository Structure

```
Root/
├── cluster-config.yaml       # 🔧 EKS Cluster Configuration
├── eks-addons.jpg            # 📸 EKS Addons Overview
├── eks-version.jpg           # 🏷️ EKS Version Details
├── summary.md                # 📖 Summary of the Deployment
├── troubleshooting.md        # 🛠️ Troubleshooting Guide
```

---

## 📜 EKS Default Addons (Pre-installed by AWS)
Amazon EKS automatically includes several default addons, even when not explicitly assigned in your manifests. These are crucial for the basic functionality and security of the cluster.

### ✅ Pre-installed EKS Addons

1. **Amazon VPC CNI (aws-node)** 🏗️
   - Manages pod networking and assigns VPC IP addresses to pods.
   - Ensures efficient network performance within AWS.

2. **CoreDNS** 🌐
   - Handles DNS resolution for services within the Kubernetes cluster.
   - Essential for service discovery and pod communication.

3. **Kube Proxy** 🔌
   - Maintains network rules on each node for inter-pod connectivity.
   - Implements Kubernetes services using IPTables/IPVS.

### 🔎 Why are these addons pre-installed?
- **Network Connectivity**: `aws-node` (Amazon VPC CNI) ensures pods receive proper networking and can communicate effectively within the AWS environment.
- **DNS Resolution**: `CoreDNS` is required for internal name resolution inside the Kubernetes cluster.
- **Service Routing**: `kube-proxy` enables efficient communication between services and workloads running within the cluster.

Although these addons are included by default, you can upgrade or modify them using the `eksctl` tool or AWS CLI.

---

## 🚀 Getting Started
To deploy the EKS cluster using the provided configuration:

```sh
eksctl create cluster -f cluster-config.yaml
```

For addon management:

```sh
eksctl get addons --cluster <your-cluster-name>
```
---

With ❤️ from 🇻🇪

Happy Deploying! 🎉



