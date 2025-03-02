<!-- User: Act as an AWS Expert with 30+ years of hands-on experience in Amazon EKS and Kubernetes. Your expertise includes deploying and managing EKS clusters efficiently. 

This cluster was deployed by running eksctl create cluster -f cluster-config.yaml

I already updated the control plain via aws eks update-cluster-version --name minimal-eks-cluster --kubernetes-version 1.28

I want you to guide me how to update the EKS self-managed nodegroups from version 1.27 to 1.28.

Generate a comprehensive step by step guide including commands and their expected outputs
Kimi: ### Step-by-Step Guide to Update EKS Self-Managed Node Groups from 1.27 to 1.28 -->

#### **Step 1: Verify Control Plane Version**
Ensure the EKS control plane is already updated to **1.28** (as confirmed by the user).

```bash
aws eks describe-cluster --name minimal-eks-cluster --query "cluster.version" --output text
```

**Expected Output:**
```
1.28
```

---

#### **Step 2: Identify the Correct AMI ID for Kubernetes 1.28**
1. **Get the current AMI type** of the existing node group:
   ```bash
   aws eks describe-nodegroup \
     --cluster-name minimal-eks-cluster \
     --nodegroup-name ng-public \
     --query "nodeGroup.amiType" \
     --output text
   ```

   **Expected Output:** `AL2_x86_64` (or another type like `AL2_ARM_64`).

2. **Find the AMI ID** for Kubernetes 1.28 in `us-east-1` using the AWS CLI:
   ```bash
   aws ec2 describe-images \
     --filters "Name=name,Values=amzn2-eks-node-*" "Name=description,Values=*1.28*" \
     --query "Images[*].[ImageId,Name]" \
     --output text
   ```

   **Example Output:**
   ```
   ami-0123456789abcdef0    amzn2-eks-node-1.28-v2024010
   ```

   **Note:** Use the AMI ID corresponding to your `amiType` (e.g., `AL2_x86_64`).

---

#### **Step 3: Create a New Node Group with Kubernetes 1.28**
1. **Create a new node group** (`ng-public-1-28`) with the updated AMI and Kubernetes version. Replace `<AMI_ID>` with the value from Step 2.

   ```bash
   eksctl create nodegroup \
     --cluster minimal-eks-cluster \
     --name ng-public-1-28 \
     --node-type t3.medium \
     --nodes 2 \
     --nodes-min 1 \
     --nodes-max 3 \
     --ami <AMI_ID> \
     --kubernetes-version 1.28 \
     --ssh-access false \
     --private-networking false \
     --subnet <SUBNET_ID_1>,<SUBNET_ID_2> \
     --region us-east-1
   ```

   **Replace:**
   - `<AMI_ID>`: The AMI ID for Kubernetes 1.28 (e.g., `ami-0123456789abcdef0`).
   - `<SUBNET_ID_1>,<SUBNET_ID_2>`: Subnets from your existing node group (use `aws eks describe-nodegroup` to find them).

   **Expected Output:**
   ```
   [ℹ]  nodegroup ng-public-1-28 will use Kubernetes 1.28
   [ℹ]  2 nodes will be created in existing subnets
   ... (node group creation progress)
   [✔]  created 1 nodegroup(s)
   ```

---

#### **Step 4: Validate New Nodes**
1. **Check node status** in the new node group:
   ```bash
   kubectl get nodes -l eks.amazonaws.com/nodegroup=ng-public-1-28
   ```

   **Expected Output:**
   ```
   NAME                                STATUS   ROLES    AGE   VERSION
   ip-192-168-1-1.ec2.internal        Ready    <none>   2m    1.28
   ip-192-168-1-2.ec2.internal        Ready    <none>   2m    1.28
   ```

---

#### **Step 5: Drain Old Nodes**
1. **Cordon and drain** nodes in the old node group (`ng-public`):
   ```bash
   kubectl label nodes -l eks.amazonaws.com/nodegroup=ng-public eksctl.io/cordon=true
   kubectl drain -l eks.amazonaws.com/nodegroup=ng-public \
     --ignore-daemonsets \
     --delete-emptydir-data \
     --force
   ```

   **Expected Output:**
   ```
   node/ip-192-168-0-1.cordoned
   node/ip-192-168-0-2.cordoned
   ... (pods evicted)
   ```

---

#### **Step 6: Delete the Old Node Group**
1. **Delete the old node group** (`ng-public`):
   ```bash
   eksctl delete nodegroup \
     --cluster minimal-eks-cluster \
     --name ng-public \
     --region us-east-1
   ```

   **Expected Output:**
   ```
   [ℹ]  deleting nodegroup ng-public
   [✔]  nodegroup deleted
   ```

---

#### **Step 7: Rename the New Node Group (Optional)**
If you want to rename `ng-public-1-28` to `ng-public`:
```bash
eksctl update nodegroup \
  --cluster minimal-eks-cluster \
  --name ng-public-1-28 \
  --new-name ng-public \
  --region us-east-1
```

**Expected Output:**
```
[ℹ]  updating nodegroup ng-public-1-28
[✔]  nodegroup updated
```

---

### **Final Verification**
1. **Check all nodes** are running Kubernetes 1.28:
   ```bash
   kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.nodeInfo.kubeletVersion}{"\n"}{end}'
   ```

   **Expected Output:**
   ```
   ip-192-168-1-1    v1.28.0-eks-1-28-2024-01-10
   ip-192-168-1-2    v1.28.0-eks-1-28-2024-01-10
   ```

---

### **Notes**
- **Pod Disruption Budgets (PDBs):** Ensure your workloads have PDBs configured to handle node drain operations.
- **AMI Updates:** Always validate the AMI ID against the [AWS EKS AMI documentation](https://docs.aws.amazon.com/eks/latest/userguide/eks-optimized-ami-versions.html).
- **Rollback:** If issues arise, you can recreate the old node group with Kubernetes 1.27 and restore pods.
