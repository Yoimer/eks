# 🌐🚀 ChatGPT Canvas Summary: EKS Cluster Deployment with VPC CNI and IRSA

## ⚙️ Initial Deployment YAML (No Add-ons)
```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: minimal-eks-cluster
  region: us-east-1
  version: "1.27"

nodeGroups:
  - name: ng-public
    instanceType: t3.medium
    desiredCapacity: 2
    minSize: 1
    maxSize: 3
    privateNetworking: false
    ssh:
      allow: false

vpc:
  autoAllocateIPv6: false
  cidr: 192.168.0.0/16
  clusterEndpoints:
    privateAccess: false
    publicAccess: true
  manageSharedNodeSecurityGroupRules: true
  nat:
    gateway: Disable
```

## 🧠 Explanation of Initial Deployment

When you deploy an EKS cluster using the above YAML, AWS automatically generates default add-ons like `coredns`, `kube-proxy`, `metrics-server`, and `vpc-cni` even if they are not explicitly specified. These add-ons are essential for the cluster's proper functioning.

### 🔍 Why AWS Generates Default Add-ons

- 🧭 **CoreDNS**: Enables service discovery within the cluster.
- ⚙️ **Kube-Proxy**: Manages networking rules on the nodes.
- 📊 **Metrics-Server**: Collects resource usage data for autoscaling.
- 🖧 **VPC-CNI**: Manages ENIs and IP addresses in your VPC.

These add-ons are crucial for cluster operations, so AWS includes them by default.

## 🛠️ Deploying with `eksctl`
```bash
eksctl create cluster -f cluster-config.yaml
```

### 🔄 Expected Output
The command creates an EKS cluster named `minimal-eks-cluster` in the `us-east-1` region with two worker nodes. The output will show the cluster's creation progress and add-ons installation.

### 📟 Current Output
Check the add-ons status with:
```bash
kubectl get pods -n kube-system
```

**Sample Output:**
```bash
NAME                                READY   STATUS    RESTARTS   AGE
aws-node-82dg6                      2/2     Running   0         2m7s
coredns-c8b897cb-2p5h4              1/1     Running   0         64m
kube-proxy-8v2tt                    1/1     Running   0         59m
metrics-server-7794986bdd-bvdns     1/1     Running   0         141m
```

All pods should be in `Running` state, ensuring the add-ons are functioning correctly.

## 🔐 OIDC and IRSA

- 🛡️ **OIDC (OpenID Connect)**: Authenticates users and services.
- 🎯 **IRSA (IAM Roles for Service Accounts)**: Maps Kubernetes service accounts to IAM roles.

### 🚨 Why We Need IRSA for VPC CNI

Without IRSA, the VPC CNI plugin uses the node's IAM role, granting broad permissions to all pods. IRSA provides more secure, granular permissions.

### ⚠️ Risks Without IRSA

If IRSA isn't chosen, all pods share the same broad permissions, posing security risks.

## 🔍 Updated Deployment YAML (Including Add-ons)
```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: minimal-eks-cluster
  region: us-east-1
  version: "1.27"

addons:
- name: coredns
  version: v1.10.1-eksbuild.18
- name: metrics-server
  version: v0.7.2-eksbuild.2
- name: kube-proxy
  version: v1.29.6-eksbuild.2
- name: vpc-cni
  version: v1.15.2-eksbuild.5

nodeGroups:
- name: ng-public
  instanceType: t3.medium
  desiredCapacity: 2
  minSize: 1
  maxSize: 3
  privateNetworking: false
  ssh:
    allow: false

vpc:
  autoAllocateIpv6: false
  cidr: 10.0.0.0/16
  clusterEndpoints:
    privateAccess: false
    publicAccess: true
  manageSharedNodeSecurityGroupRules: true
  nat:
    gateway: Disable
```

### 🚀 Deploying with Updated YAML
```bash
eksctl create cluster -f updated-cluster-config.yaml
```

## 🏷️ OIDC Annotations Explained

Use this command to link the `aws-node` service account with the IAM role:
```bash
kubectl -n kube-system annotate serviceaccount aws-node eks.amazonaws.com/role-arn=arn:aws:iam::<account-id>:role/<role-name>
```

## 🔨 Creating the IRSA Role (EKS-VPC-CNI-Addon-Role)

### 🛠️ Step 1: Create IAM Role

- Open **IAM** in AWS Console.
- Click **Roles** → **Create role**.
- Choose **EKS** as the trusted entity.
- Attach these policies:
  - 📡 `AmazonEKSVPCResourceController`
  - 🌐 `AmazonEKS_CNI_Policy`

### ✏️ Step 2: Update Trust Policy

Replace `<OIDC-ISSUER-URL>` with your cluster's OIDC URL:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/<OIDC-ISSUER-URL>"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "<OIDC-ISSUER-URL>:sub": "system:serviceaccount:kube-system:aws-node"
        }
      }
    }
  ]
}
```
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/1C3048311BA17C39CB032AD73AEF0238"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "oidc.eks.us-east-1.amazonaws.com/id/1C3048311BA17C39CB032AD73AEF0238:sub": "system:serviceaccount:kube-system:aws-node"
                }
            }
        }
    ]
}
```

### Step 3: Create the OIDC Provider

You need to create the OIDC provider for your EKS cluster. The OIDC provider allows the service account to assume the IAM role using IRSA (IAM Roles for Service Accounts).

### Action: Create the OIDC Provider Using `eksctl`

Run the following command to create the OIDC provider for your EKS cluster:

```bash
eksctl utils associate-iam-oidc-provider --cluster minimal-eks-cluster --approve
```
**This command will:**
1. Register the OIDC provider for your EKS cluster in AWS IAM.
2. Ensure that the `aws-node` service account can use IRSA to assume the IAM role.

### 🔍 Step 4: Annotate Service Account
```bash
kubectl -n kube-system annotate serviceaccount aws-node eks.amazonaws.com/role-arn=arn:aws:iam::637423582856:role/EKS-VPC-CNI-Addon-Role
```

## 🎯 Conclusion

By following these steps, you deploy an EKS cluster with the VPC CNI add-on secured by IRSA. This setup enhances security and ensures efficient, controlled access to AWS resources. 🚀🔐

