# 🎮 Deploying the Game-2048 App on EKS


## Change directory to app folder
```bash
cd app
```

## Create the Game-2048 namespace
```bash
kubectl create namespace game-2048
```

### Expected Output:
```bash
namespace/game-2048 created
```

## Install OIDC Provider for EKS (if not installed already)

```bash
eksctl utils associate-iam-oidc-provider \
    --region us-east-1 \
    --cluster minimal-eks-cluster \
    --approve
```

### Expected Output:
```bash
[ℹ]  eksctl version 0.169.0
[ℹ]  using region us-east-1
[ℹ]  will create IAM OpenID Connect provider for cluster "minimal-eks-cluster" in "us-east-1"
[✔]  IAM OpenID Connect provider created for cluster "minimal-eks-cluster" in "us-east-1"
```
## Create IAM Policy for ALB Ingress Controller


```bash 
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://alb-ingress-iam-policy.json
```

### Expected Output:
```json
{
    "Policy": {
        "PolicyName": "AWSLoadBalancerControllerIAMPolicy",
        "PolicyId": "ANPAXXXXXXXXXXXXXXXXXXX",
        "Arn": "arn:aws:iam::123456789012:policy/AWSLoadBalancerControllerIAMPolicy",
        "Path": "/",
        "DefaultVersionId": "v1",
        "AttachmentCount": 0,
        "PermissionsBoundaryUsageCount": 0,
        "IsAttachable": true,
        "CreateDate": "2025-03-02T12:00:00+00:00",
        "UpdateDate": "2025-03-02T12:00:00+00:00"
    }
}
```

## Create an IAM Role for AWS ALB Ingress Controller (IRSA)

### 🛠️ Step 1: Create IAM Role

- Open **IAM** in AWS Console.
- Click **Roles** → **Create role**.
- For the Trusted entity type choose **Custom trust policy**

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
          "<OIDC-ISSUER-URL>:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }
  ]
}
```
- Attach these policies:
  - 📡 `AWSLoadBalancerControllerIAMPolicy`

### Step 3 Create AWS-Load-Balancer-Role and description

```
This IAM role is used by the AWS Load Balancer Controller to dynamically provision and manage Application Load Balancers (ALB) and Network Load Balancers (NLB) for Kubernetes workloads running on Amazon EKS.

Key Responsibilities:

- Automatically creates and manages AWS ALB/NLB resources for Kubernetes Ingress.
- Configures listeners, target groups, and security groups for traffic routing.
- Ensures proper IAM authentication for load balancer operations.
- Provides integration with AWS API Gateway and other networking services.
- Enables SSL/TLS termination and redirects at the ALB level.
- Supports Ingress traffic management based on Kubernetes rules.
```

### Create the Service Account Manually
```bash
kubectl create serviceaccount aws-load-balancer-controller -n kube-system
```

### Annotate the IRSA for ALB Controller
To properly link the ALB Ingress Controller with the IAM role, annotate it with:
```bash
kubectl annotate serviceaccount aws-load-balancer-controller \
    -n kube-system \
    eks.amazonaws.com/role-arn=arn:aws:iam::<ACCOUNT_ID>:role/AWS-Load-Balancer-Role
```

### Expected Output:
```bash
serviceaccount/aws-load-balancer-controller annotated
```

## Install AWS Load Balancer Controller
To install the AWS Load Balancer Controller, run:
```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=minimal-eks-cluster \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller
```

### Expected Output:
```bash
NAME: aws-load-balancer-controller
LAST DEPLOYED: Sat Mar 02 2025
NAMESPACE: kube-system
STATUS: deployed
REVISION: 1
```

## Deploy the Game-2048 App

```bash
kubectl apply -f game-2048.yaml -n game-2048
```

### Expected Output:
```bash
deployment.apps/game-2048 created
service/game-2048 created
```

## Verify the Deployment
```bash
kubectl get pods -n game-2048
```

### Expected Output:
```bash
NAME                         READY   STATUS    RESTARTS   AGE
game-2048-6bbc7f7897-xbtvh   1/1     Running   0          5s
```

### Create an Ingress Resource for Game-2048

```bash
kubectl apply -f game-2048-ingress.yaml
```

### Expected Output:
```bash
ingress.networking.k8s.io/game-2048-ingress created
```

### Verify the Deployment
Check if the ingress resource was created:
```bash
kubectl get ingress -n game-2048
```

### Expected Output:
```bash
NAME               CLASS    HOSTS   ADDRESS                                                                  PORTS   AGE
game-2048-ingress  <none>   *       k8s-game2048-game2048-xxxxxxxxxx-123456789.us-east-1.elb.amazonaws.com  80      30s
```

### Verify the ALB is properly configured:

```bash
kubectl describe ingress game-2048-ingress -n game-2048
```

### Expected Output:
```bash
Name:             game-2048-ingress
Namespace:        game-2048
Address:          k8s-game2048-game2048-xxxxxxxxxx-123456789.us-east-1.elb.amazonaws.com
Default backend:  default-http-backend:80 (...)
Rules:
  Host        Path  Backends
  ----        ----  --------
  *           
              /   game-2048:80 (192.168.xx.xx:80,192.168.xx.xx:80)
Annotations:  alb.ingress.kubernetes.io/healthcheck-path: /
              alb.ingress.kubernetes.io/listen-ports: [{"HTTP": 80}]
              alb.ingress.kubernetes.io/scheme: internet-facing
              alb.ingress.kubernetes.io/target-type: ip
              kubernetes.io/ingress.class: alb
Events:
  Type    Reason                  Age   From     Message
  ----    ------                  ----  ----     -------
  Normal  SuccessfullyReconciled  45s   ingress  Successfully reconciled
```

### Access the Application
Once the ALB is provisioned and the DNS is propagated, you can access the 2048 game using the ALB address:

### Expected Output:
```bash
http://k8s-game2048-game2048-xxxxxxxxxx-123456789.us-east-1.elb.amazonaws.com
```