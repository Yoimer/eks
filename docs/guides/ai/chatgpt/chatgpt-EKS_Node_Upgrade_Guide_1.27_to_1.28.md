# Upgrading Self-Managed EKS Nodes from Kubernetes 1.27 to 1.28

## 📌 Introduction
This document outlines the step-by-step process of upgrading self-managed EKS nodes from Kubernetes version 1.27 to 1.28. It captures all the commands executed, validation checks, errors encountered, and the solutions applied during the upgrade process.

## 🛠️ Step-by-Step Upgrade Process

### 1️⃣ Retrieve Auto Scaling Group Information
```sh
aws autoscaling describe-auto-scaling-groups \
    --query "AutoScalingGroups[*].{Name:AutoScalingGroupName}"
```

### 2️⃣ Fetch the Launch Template ID
```sh
aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names eksctl-minimal-eks-cluster-nodegroup-ng-public-NodeGroup-z7SZSPz7IQbA \
    --query "AutoScalingGroups[0].LaunchTemplate.LaunchTemplateId" --output text
```

### 3️⃣ Retrieve the Latest EKS-Optimized AMI
```sh
aws ssm get-parameter --name "/aws/service/eks/optimized-ami/1.28/amazon-linux-2/recommended/image_id" --query "Parameter.Value" --output text
```

### 4️⃣ Create a New Launch Template Version
```sh
aws ec2 create-launch-template-version \
    --launch-template-id lt-0882655116b96bc3a \
    --source-version 1 \
    --launch-template-data "{\"ImageId\":\"ami-0c06fec3cb455dec0\"}"
```

### 5️⃣ Update the Auto Scaling Group to Use the New Launch Template Version
```sh
aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name eksctl-minimal-eks-cluster-nodegroup-ng-public-NodeGroup-z7SZSPz7IQbA \
    --launch-template LaunchTemplateId=lt-0882655116b96bc3a,Version=2
```

### 6️⃣ Increase Desired Capacity to Provision New Nodes
```sh
aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name eksctl-minimal-eks-cluster-nodegroup-ng-public-NodeGroup-z7SZSPz7IQbA \
    --desired-capacity 4
```

### 7️⃣ Verify New Nodes Are Running the Updated Version
```sh
kubectl get nodes -o wide
```

### 8️⃣ Drain and Remove Old Nodes
```sh
kubectl drain <old-node-name> --ignore-daemonsets --delete-emptydir-data
aws ec2 terminate-instances --instance-ids <old-instance-id>
```

### 9️⃣ Scale the ASG Back to Desired Capacity
```sh
aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name eksctl-minimal-eks-cluster-nodegroup-ng-public-NodeGroup-z7SZSPz7IQbA \
    --desired-capacity 2
```

## 🎯 Final Verification
- Check running instances:
```sh
aws ec2 describe-instances --query "Reservations[*].Instances[*].[InstanceId,ImageId]" --output table
```
- Validate node health:
```sh
kubectl get nodes -o wide
```

## 🚨 Errors Encountered & Solutions
- **Cannot evict pod due to PodDisruptionBudget**: Resolved by manually deleting pods that blocked eviction.
- **Desired capacity must be within min/max size**: Updated `max-size` before increasing capacity.

## ⚠️ Important Note: Rolling Updates vs. AWS-Managed Nodes
This upgrade process **does not convert self-managed nodes to AWS-managed nodes**. It only updates the existing nodes within the Auto Scaling Group. If you want to migrate to AWS-managed node groups:
1. Create an **AWS-managed node group**.
2. **Migrate workloads** to the new nodes.
3. **Delete the old self-managed node group**.

## 🏆 Best Practices for Production
- **Perform rolling updates** to avoid downtime.
- **Use `kubectl cordon` and `kubectl drain`** before terminating old nodes.
- **Ensure all workloads are rescheduled before terminating nodes.**
- **Monitor cluster health** using `kubectl get nodes` and `kubectl get pods -n kube-system`.
- **Test the upgrade in a non-production environment first** to prevent unexpected failures.

---
This document serves as a detailed guide for upgrading self-managed EKS nodes efficiently and with minimal downtime. 🚀

