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
### Create an IAM policy document for the ALB Ingress Controller:

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

AWS ALB Ingress Controller requires an IAM role with the necessary permissions. Run:
```bash
eksctl create iamserviceaccount \
    --region us-east-1 \
    --name aws-load-balancer-controller \
    --namespace kube-system \
    --cluster minimal-eks-cluster \
    --attach-policy-arn arn:aws:iam::aws:policy/AWSLoadBalancerControllerIAMPolicy \
    --approve
```
### Expected Output:
```bash
[ℹ]  eksctl version 0.162.0
[ℹ]  using region us-east-1
[ℹ]  1 iamserviceaccount (kube-system/aws-load-balancer-controller) was included
[ℹ]  1 task: {
    2 sequential sub-tasks: {
        create IAM role for serviceaccount "kube-system/aws-load-balancer-controller",
        create serviceaccount "kube-system/aws-load-balancer-controller",
    } }
[ℹ]  building iamserviceaccount stack "eksctl-minimal-eks-cluster-addon-iamserviceaccount-kube-system-aws-load-balancer-controller"
[ℹ]  deploying stack "eksctl-minimal-eks-cluster-addon-iamserviceaccount-kube-system-aws-load-balancer-controller"
[ℹ]  waiting for CloudFormation stack "eksctl-minimal-eks-cluster-addon-iamserviceaccount-kube-system-aws-load-balancer-controller"
[ℹ]  created serviceaccount "kube-system/aws-load-balancer-controller"
```

### Annotate the IRSA for ALB Controller
To properly link the ALB Ingress Controller with the IAM role, annotate it with:
```bash
kubectl annotate serviceaccount \
    aws-load-balancer-controller \
    -n kube-system \
    eks.amazonaws.com/role-arn=arn:aws:iam::<YOUR_AWS_ACCOUNT_ID>:role/<IAM_ROLE_NAME>
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
Now, let's deploy the game using the provided game-2048.yaml file.
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