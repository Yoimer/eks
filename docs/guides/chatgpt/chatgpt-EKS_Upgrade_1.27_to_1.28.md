# 🚀 **EKS Upgrade from 1.27 to 1.28 - Troubleshooting & Lessons Learned**

## 📝 **Overview**
This guide documents the **step-by-step process** of upgrading an **Amazon EKS cluster** from **Kubernetes v1.27 to v1.28**. It includes **troubleshooting details, commands, outputs, and key insights** on why managed node groups did not update automatically.

---

## 🔹 **Step 1: Checking Add-on Compatibility Before Upgrade**
Before upgrading the EKS control plane, we **checked add-on compatibility** for Kubernetes 1.28. 

### ✅ **Command: List available add-on versions**
```bash
aws eks describe-addon-versions --addon-name vpc-cni --kubernetes-version 1.28
aws eks describe-addon-versions --addon-name coredns --kubernetes-version 1.28
aws eks describe-addon-versions --addon-name kube-proxy --kubernetes-version 1.28
```
### 📌 **Expected Output (Example)**
```json
{
    "addons": [
        {
            "addonName": "vpc-cni",
            "addonVersions": [
                {
                    "addonVersion": "v1.19.2-eksbuild.5",
                    "defaultVersion": false
                },
                {
                    "addonVersion": "v1.19.0-eksbuild.1",
                    "defaultVersion": true
                }
            ]
        }
    ]
}
```
✅ **Takeaway:** We identified **which add-on versions** were compatible with Kubernetes **1.28**.

---

## 🔹 **Step 2: Upgrading the EKS Control Plane (1.27 → 1.28)**
Once we confirmed add-on compatibility, we proceeded with the **EKS control plane upgrade**.

### ✅ **Command: Upgrade EKS Control Plane**
```bash
aws eks update-cluster-version --name minimal-eks-cluster --kubernetes-version 1.28
```
### 📌 **Expected Output**
```json
{
    "update": {
        "id": "eb6e98e0-348a-3838-9f75-1a6755342d0c",
        "status": "InProgress",
        "type": "VersionUpdate",
        "params": [
            {
                "type": "Version",
                "value": "1.28"
            }
        ],
        "createdAt": "2025-02-24T23:31:47.188000-04:00"
    }
}
```
### ✅ **Command: Check upgrade status**
```bash
aws eks describe-update --name minimal-eks-cluster --update-id eb6e98e0-348a-3838-9f75-1a6755342d0c
```
### 📌 **Final Output: Successful Upgrade**
```json
{
    "update": {
        "id": "eb6e98e0-348a-3838-9f75-1a6755342d0c",
        "status": "Successful",
        "type": "VersionUpdate",
        "params": [
            {
                "type": "Version",
                "value": "1.28"
            }
        ]
    }
}
```
✅ **EKS control plane is now running Kubernetes 1.28!** 🎉

---

## 🔹 **Step 3: Why Node Groups Did Not Automatically Update**
After upgrading the control plane, the worker nodes **remained on Kubernetes 1.27**.

### ❓ **Why?**
EKS **does not automatically update self-managed nodes**. The control plane and worker nodes are **decoupled**, meaning:
- The **control plane updates independently**.
- Worker nodes **must be manually upgraded** (if self-managed) or updated via **rolling replacement** (if managed).

### 🔎 **Difference Between Self-Managed vs. Managed Node Groups**
| Feature               | Self-Managed Nodes  | Managed Node Groups  |
|----------------------|-------------------|--------------------|
| Upgrade Behavior | Must be manually updated | AWS manages upgrades (with rollout strategy) |
| Scaling | Fully manual scaling | Autoscaling built-in |
| Patching | Manual AMI updates required | AWS updates node images automatically |
| IAM Integration | Requires manual role assignment | AWS assigns IAM roles automatically |

**✅ Takeaway:** Since our cluster had **self-managed nodes**, we had to **manually delete and recreate them** at v1.28.

---

## 🔹 **Step 4: Deleting the Old Node Group (v1.27)**
Since self-managed nodes **don’t auto-upgrade**, we **deleted the old node group**.

### ✅ **Command: Delete nodegroup**
```bash
eksctl delete nodegroup --cluster minimal-eks-cluster --name ng-public
```
### ❌ **Error: Node Drain Issues**
```
2025-02-25 00:07:44 [!]  1 pods are unevictable from node ip-192-168-39-23.ec2.internal
```
### 🛠 **Fix: Manually Delete Stuck Pods**
```bash
kubectl delete pod <POD_NAME> -n kube-system --force --grace-period=0
```
✅ **After deleting stuck pods, the nodegroup was successfully removed.**

---

## 🔹 **Step 5: Creating a New Node Group (v1.28)**
Once the old nodes were removed, we created **a new node group** running **Kubernetes 1.28**.

### ✅ **Command: Create new nodegroup**
```bash
eksctl create nodegroup --cluster minimal-eks-cluster --name ng-public   --node-type t3.medium   --nodes 2   --nodes-min 1   --nodes-max 3   --ssh-access=false   --managed=false
```
✅ **Now, worker nodes are running Kubernetes 1.28!** 🎉

---

## 🔹 **Step 6: Final Verification**
### ✅ **Command: Check nodes**
```bash
kubectl get nodes
```
✅ **Worker nodes are fully upgraded!**

---
# 🎯 **Final Summary**
✅ **EKS Control Plane upgraded from 1.27 → 1.28.**  
✅ **Self-managed nodegroups did NOT auto-upgrade (manual deletion required).**  
✅ **Old worker nodes (1.27) were removed manually.**  
✅ **New worker nodes (1.28) were created successfully.**  
✅ **All system components (`coredns`, `kube-proxy`, `aws-node`) are running normally.**  

---