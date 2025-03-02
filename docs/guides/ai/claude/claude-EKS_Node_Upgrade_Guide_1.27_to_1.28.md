<!-- Act as an AWS Expert with 30+ years of hands-on experience in Amazon EKS and Kubernetes. Your expertise includes deploying and managing EKS clusters efficiently. 

This cluster was deployed by running eksctl create cluster -f cluster-config.yaml

I already updated the control plain via aws eks update-cluster-version --name minimal-eks-cluster --kubernetes-version 1.28

I want you to guide me how to update the EKS self-managed nodegroups from version 1.27 to 1.28.

Generate a comprehensive step by step guide including commands and their expected outputs -->

# Guide to Updating EKS Self-Managed NodeGroups from Version 1.27 to 1.28

Thank you for sharing your cluster configuration. I see you've already successfully updated the EKS control plane to version 1.28. Now you need to update the self-managed nodegroups to match this version.

Updating self-managed nodegroups requires replacing the existing nodes with new ones running the updated Kubernetes version. I'll guide you through this process systematically.

## Prerequisites Check

Before beginning, ensure you have:

1. Updated your eksctl to the latest version
2. AWS CLI configured with appropriate permissions
3. kubectl configured to access your cluster

## Step 1: Verify Current Cluster Status

```bash
aws eks describe-cluster --name minimal-eks-cluster --query "cluster.{Name:name,K8sVersion:version,Status:status}"
```

Expected output:
```json
{
    "Name": "minimal-eks-cluster",
    "K8sVersion": "1.28",
    "Status": "ACTIVE"
}
```

## Step 2: Check Current NodeGroup Configuration

```bash
eksctl get nodegroup --cluster minimal-eks-cluster
```

Expected output:
```
CLUSTER             NODEGROUP       STATUS  CREATED                 MIN SIZE        MAX SIZE        DESIRED CAPACITY        INSTANCE TYPE   IMAGE ID
minimal-eks-cluster ng-public       ACTIVE  2023-07-15T10:23:45Z   1               3               2                       t3.medium       ami-0123456789abcdef
```

## Step 3: Update the YAML Configuration File

Update your `cluster-config.yaml` to specify the new AMI ID compatible with Kubernetes 1.28:

```bash
# First, get the appropriate AMI ID for your region and K8s version
aws ssm get-parameter --name /aws/service/eks/optimized-ami/1.28/amazon-linux-2/recommended/image_id --region us-east-1 --query "Parameter.Value" --output text
```

Expected output:
```
ami-0a87d6c192c7096c5
```

Now edit your cluster-config.yaml file to include this AMI:

```yaml
nodeGroups:
  - name: ng-public
    instanceType: t3.medium
    desiredCapacity: 2
    minSize: 1
    maxSize: 3
    privateNetworking: false
    ssh:
      allow: false
    ami: ami-0a87d6c192c7096c5  # Add the AMI ID here
    kubernetes-version: 1.28  # Add the K8s version here
```

## Step 4: Create a New NodeGroup with Updated Version

To minimize disruption, create a new nodegroup before removing the old one:

```bash
eksctl create nodegroup --config-file=cluster-config.yaml --include=ng-public-v2
```

Note: You'll need to first modify your YAML to include a new nodegroup named `ng-public-v2` with the updated configuration.

Expected output:
```
2023-07-15 12:34:56 [ℹ]  will use version 1.28 for new nodegroup(s)
2023-07-15 12:34:58 [ℹ]  nodegroup "ng-public-v2" will use "ami-0a87d6c192c7096c5" [AmazonLinux2/1.28]
2023-07-15 12:35:00 [ℹ]  created 1 nodegroup(s) in cluster "minimal-eks-cluster"
2023-07-15 12:38:20 [ℹ]  nodegroup "ng-public-v2" has 2 node(s)
2023-07-15 12:38:20 [ℹ]  node "ip-192-168-12-34.ec2.internal" is ready
2023-07-15 12:38:20 [ℹ]  node "ip-192-168-56-78.ec2.internal" is ready
```

## Step 5: Verify New Nodes are Running and Ready

```bash
kubectl get nodes -o wide
```

Expected output:
```
NAME                             STATUS   ROLES    AGE     VERSION   INTERNAL-IP      EXTERNAL-IP      OS-IMAGE         KERNEL-VERSION                  CONTAINER-RUNTIME
ip-192-168-12-34.ec2.internal    Ready    <none>   5m      v1.28.x   192.168.12.34    54.12.34.56      Amazon Linux 2   5.10.x-x.amzn2.x86_64           containerd://1.6.x
ip-192-168-56-78.ec2.internal    Ready    <none>   5m      v1.28.x   192.168.56.78    54.56.78.90      Amazon Linux 2   5.10.x-x.amzn2.x86_64           containerd://1.6.x
ip-192-168-11-22.ec2.internal    Ready    <none>   1d      v1.27.x   192.168.11.22    54.11.22.33      Amazon Linux 2   5.4.x-x.amzn2.x86_64            containerd://1.5.x
ip-192-168-33-44.ec2.internal    Ready    <none>   1d      v1.27.x   192.168.33.44    54.33.44.55      Amazon Linux 2   5.4.x-x.amzn2.x86_64            containerd://1.5.x
```

## Step 6: Cordon and Drain Old Nodes

Prevent new pods from being scheduled on the old nodes:

```bash
# For each old node (replace with your actual node names)
kubectl cordon ip-192-168-11-22.ec2.internal
kubectl cordon ip-192-168-33-44.ec2.internal
```

Expected output:
```
node/ip-192-168-11-22.ec2.internal cordoned
node/ip-192-168-33-44.ec2.internal cordoned
```

Drain the old nodes (evict all pods):

```bash
# For each old node (replace with your actual node names)
kubectl drain ip-192-168-11-22.ec2.internal --ignore-daemonsets --delete-emptydir-data
kubectl drain ip-192-168-33-44.ec2.internal --ignore-daemonsets --delete-emptydir-data
```

Expected output:
```
node/ip-192-168-11-22.ec2.internal drained
node/ip-192-168-33-44.ec2.internal drained
```

## Step 7: Delete the Old NodeGroup

```bash
eksctl delete nodegroup --cluster minimal-eks-cluster --name ng-public
```

Expected output:
```
2023-07-15 13:10:12 [ℹ]  will delete 1 nodegroup(s) from cluster "minimal-eks-cluster"
2023-07-15 13:10:15 [ℹ]  deleted 1 nodegroup(s) from cluster "minimal-eks-cluster"
```

## Step 8: Verify Cluster Status After Update

```bash
kubectl get nodes -o wide
```

Expected output:
```
NAME                             STATUS   ROLES    AGE     VERSION   INTERNAL-IP      EXTERNAL-IP      OS-IMAGE         KERNEL-VERSION                  CONTAINER-RUNTIME
ip-192-168-12-34.ec2.internal    Ready    <none>   30m     v1.28.x   192.168.12.34    54.12.34.56      Amazon Linux 2   5.10.x-x.amzn2.x86_64           containerd://1.6.x
ip-192-168-56-78.ec2.internal    Ready    <none>   30m     v1.28.x   192.168.56.78    54.56.78.90      Amazon Linux 2   5.10.x-x.amzn2.x86_64           containerd://1.6.x
```

```bash
kubectl version --short
```

Expected output:
```
Client Version: v1.28.x
Server Version: v1.28.x
```

## Step 9: Update Your Local Configuration

Update your local cluster-config.yaml to reflect the current state:

```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: minimal-eks-cluster
  region: us-east-1
  version: "1.28"  # Updated version

nodeGroups:
  - name: ng-public-v2  # Updated nodegroup name
    instanceType: t3.medium
    desiredCapacity: 2
    minSize: 1
    maxSize: 3
    privateNetworking: false
    ssh:
      allow: false
    ami: ami-0a87d6c192c7096c5  # Updated AMI
    kubernetes-version: 1.28  # Explicit K8s version

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

## Post-Update Verification

Ensure all your workloads are running properly:

```bash
kubectl get pods --all-namespaces
```

Expected output will show all your pods in Running state.

This completes the update process for your self-managed EKS nodegroups from version 1.27 to 1.28.