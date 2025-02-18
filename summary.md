# 🚀 ChatGPT Canvas Summary: EKS Cluster Deployment with VPC CNI and IRSA

## Initial Deployment YAML (No Add-ons)
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

## Explanation of Initial Deployment

When you deploy an EKS cluster using the above YAML, AWS automatically generates default add-ons like `coredns`, `kube-proxy`, `metrics-server`, and `vpc-cni` even if they are not explicitly specified in the configuration. This is because these add-ons are essential for the proper functioning of the cluster.

### Why AWS Generates Default Add-ons

- `CoreDNS` : Enables service discovery within the cluster.
- `Kube-Proxy` : Manages networking rules on the nodes.
- `Metrics-Server` : Collects resource usage data for autoscaling and monitoring.
- `VPC-CNI` : Manages ENIs and IP addresses in your VPC.

These add-ons are critical for the cluster's basic operations, so AWS includes them by default to ensure a functional cluster setup.

## 🛠️ Deploying with eksctl
```bash
eksctl create cluster -f cluster-config.yaml
```

### 🔄 Expected Output
The command will create an EKS cluster named `minimal-eks-cluster` in the `us-east-1` region with two worker nodes. The output will show the progress of the cluster creation, including the creation of the default add-ons.

### 📊 Current Output
After deployment, you can check the status of the add-ons using the EKS console or `kubectl`:

```bash
kubectl get pods -n kube-system
```

**Output:**
```bash
# Example output (actual results may vary)

NAME                                READY   STATUS    RESTARTS   AGE
aws-node-82dg6                      2/2     Running   0         2m7s
aws-node-l897v                      2/2     Running   0         2m15s
coredns-c8b897cb-2p5h4              1/1     Running   0         64m
coredns-c8b897cb-9chv2              1/1     Running   0         64m
kube-proxy-8v2tt                    1/1     Running   0         59m
kube-proxy-w6c6x                    1/1     Running   0         59m
metrics-server-7794986bdd-bvdns     1/1     Running   0         141m
metrics-server-7794986bdd-kzsnw     1/1     Running   0         141m
```

All pods should be in a `Running` state, indicating that the default add-ons (e.g., `aws-node`, `coredns`, `kube-proxy`, `metrics-server`) are functioning correctly.

## 🌐 OIDC and IRSA

OIDC (OpenID Connect) is a protocol used to authenticate users and services. In the context of EKS, it allows Kubernetes service accounts to assume IAM roles, providing fine-grained control over permissions.

IRSA (IAM Roles for Service Accounts) leverages OIDC to map Kubernetes service accounts to IAM roles, enabling pods to assume specific IAM roles directly.

### ⚠️ Why We Need IRSA for VPC CNI

Without IRSA, the VPC CNI plugin would rely on the node's IAM instance profile role, which provides broad permissions to all pods running on the node. This can be a security concern. IRSA allows the VPC CNI plugin to have its own IAM role, providing more granular control over permissions.

### ⚠️ What Happens When NO IRSA is Chosen

If IRSA is not chosen when deploying with `eksctl`, the VPC CNI plugin will use the node's IAM instance profile role. This means that all pods on the node will have the same broad permissions, which can be a security risk. Additionally, you may encounter issues with managing permissions for different pods or services.

## Updated Deployment YAML (Including Add-ons)

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
## Deploying with Updated YAML

```bash
eksctl create cluster -f updated-cluster-config.yaml
```

# Explanation of OICD Annotations

When you annotate a service account with the `eks.amazonaws.com/role-arn` annotation, you instruct Kubernetes to associate that service account with a specific IAM role. This enables pods running under the service account to assume the IAM role, granting them the required permissions with fine-grained control.

```bash
kubectl -n kube-system annotate serviceaccount aws-node eks.amazonaws.com/role-arn=arn:aws:iam::<account-id>:role/<role-name>
```
This ensures that the VPC CNI plugin has the necessary permissions to function correctly.

# Creating the IRSA Role

To create the IRSA role, follow these steps:

## 1. Create the IAM Role

- Navigate to the **IAM service** in the AWS Management Console.
- Click **Roles** in the left-hand menu.
- Click **Create role**.
- Select **EKS** as the trusted entity type.
- Choose **EKS - Amazon EKS** as the use case.
- Attach the following policies:
  - `AmazonEKSVPCResourceControllerPolicy`
  - `AmazonEKS_CNI_Policy`
- Review the role details and click **Create role**.

## 2. Update the Trust Policy

- After creating the role, click the **Trust relationships** tab.
- Click **Edit trust policy**.
- Replace the existing trust policy with the following JSON document:

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

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::637423582856:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/1C3048311BA17C39CB032AD73AEF0238"
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

# Creating the IRSA Role

## 2. Update the Trust Policy

- Replace `<oidc-provider-id>` in the trust policy JSON with the actual OIDC provider ID obtained from:
  ```bash
  aws iam list-open-id-connect-providers

## 3. Annotate the Service Account

- Use `kubectl` to annotate the `aws-node` service account:

```bash
kubectl -n kube-system annotate serviceaccount aws-node eks.amazonaws.com/role-arn=arn:aws:iam::637423582856:role/EKS-VPC-CNI-Addon-Role
```

# 🚀 Conclusion

By following the steps outlined above, you can successfully deploy an EKS cluster with the VPC CNI add-on configured with IRSA. This setup enhances security and provides granular permission control, ensuring a robust and secure cluster environment.