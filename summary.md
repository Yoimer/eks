# 🌐🚀EKS Cluster Deployment with VPC CNI and IRSA

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
### Step 3 EKS-VPC-CNI-Addon-Role description

```
This IAM role is used by the Amazon EKS VPC CNI Add-on to manage networking resources within an Amazon EKS cluster. It grants permissions necessary for the AWS VPC CNI plugin to assign and manage IP addresses for Kubernetes pods. The role is assumed by the aws-node service account in the kube-system namespace through an OIDC-based federated identity trust.
```
### Step 4 Create the OIDC Provider

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
kubectl -n kube-system annotate serviceaccount aws-node eks.amazonaws.com/role-arn=arn:aws:iam::<ACCOUNT_ID>:role/EKS-VPC-CNI-Addon-Role
```
## The Role of the Annotation

The annotation step links the Kubernetes service account (`aws-node`) to the IAM role (`EKS-VPC-CNI-Addon-Role`). Here's why this is necessary:

### 1. Establishing Trust Between Kubernetes and AWS

When you annotate the service account, you're telling Kubernetes which IAM role the service account should use. This is done by adding the `eks.amazonaws.com/role-arn` annotation to the service account. For example:

```bash
kubectl -n kube-system annotate serviceaccount aws-node eks.amazonaws.com/role-arn=arn:aws:iam::<ACCOUNT_ID>:role/<ROLE_NAME>
```

This annotation tells Kubernetes that the `aws-node` service account should use the specified IAM role (`EKS-VPC-CNI-Addon-Role`) when interacting with AWS services.

### 2. Enabling Web Identity Token Authentication

The annotation works in conjunction with the **OpenID Connect (OIDC)** provider for your EKS cluster. When a pod starts, it uses the service account's associated **web identity token** (stored in `/var/run/secrets/eks.amazonaws.com/serviceaccount/token`) to authenticate with AWS. The annotation ensures that the token is mapped to the correct IAM role via the OIDC provider.

Without the annotation, the pod would not know which IAM role to assume, and AWS would reject the authentication request.

## What Happens Without the Annotation?

If you skip the annotation step:

- **AWS Node Pod IAM Role Assumption Failure**  
  The `aws-node` pod will not be able to assume the IAM role (`EKS-VPC-CNI-Addon-Role`).

- **Authentication Errors with AWS Services**  
  The pod will fail to authenticate with AWS services, leading to errors such as:  
  - `timeout: failed to connect service "50051" within 5s`  
  - Missing permissions for actions like managing **ENIs (Elastic Network Interfaces)** or assigning IP addresses.

- **Readiness/Liveness Probes Fail**  
  The pod's readiness and liveness probes will fail, causing it to crash or enter a **CrashLoopBackOff** state.

## How the Annotation Works

Here's a high-level overview of how the annotation enables secure communication between the pod and AWS:

### 1. Pod Starts with Service Account
- The `aws-node` pod is configured to use the `aws-node` service account.
- The service account has the `eks.amazonaws.com/role-arn` annotation pointing to the IAM role.

### 2. Web Identity Token Injection
- Kubernetes injects a web identity token into the pod at `/var/run/secrets/eks.amazonaws.com/serviceaccount/token`.

### 3. Assume IAM Role
- The pod uses the web identity token to authenticate with AWS STS (Security Token Service).
- AWS verifies the token against the OIDC provider and assumes the IAM role specified in the annotation.

### 4. Access AWS Resources
- The pod now has temporary AWS credentials (via the assumed role) to interact with AWS services.

## Why Not Just Use Environment Variables?

You might wonder why we don't simply pass the IAM role ARN as an environment variable instead of annotating the service account. The reason is that annotations are part of the Kubernetes API and are tightly integrated with the IRSA mechanism. They provide a standardized way to associate IAM roles with service accounts, ensuring consistency and security across the cluster.

## Summary

The annotation step is necessary because:

1. It links the Kubernetes service account to the IAM role, enabling fine-grained permissions.
2. It allows the pod to authenticate with AWS using the web identity token.
3. It ensures that the pod can securely access AWS resources without relying on overly permissive node-level IAM roles.

Without the annotation, the IRSA mechanism cannot function, and the pod will fail to authenticate with AWS services. This is why the annotation is a critical step in configuring IRSA for the `aws-node` service account.

## 🎯 Conclusion

By following these steps, you deploy an EKS cluster with the VPC CNI add-on secured by IRSA. This setup enhances security and ensures efficient, controlled access to AWS resources. 🚀🔐
