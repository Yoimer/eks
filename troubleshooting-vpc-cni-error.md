# Troubleshooting Amazon VPC CNI Update in EKS 1.27

When updating the **Amazon VPC CNI v1.19.0-eksbuild.1** on an **EKS 1.27 cluster**, I encountered an issue where the **aws-node pods failed to reach the expected 2/2 status**.

##

```bash
kubectl get pods -n kube-system
NAME READY STATUS RESTARTS AGE
aws-node-5npq4 1/2 Running 0 5s
aws-node-n7tf9 1/2 Running 0 18s
coredns-c8b897cb-mznwn 1/1 Running 0 14m
coredns-c8b897cb-t4rss 1/1 Running 0 14m
kube-proxy-srwmm 1/1 Running 0 13m
kube-proxy-zbm4q 1/1 Running 0 14m
metrics-server-7794986bdb-bxd2c 1/1 Running 0 61m
metrics-server-7794986bdb-rmhj4 1/1 Running 0 61m
```

```bash 
kubectl describe pod aws-node-5npq4 -n kube-system
```

```bash

Events:
  Type     Reason     Age                From               Message
  ----     ------     ----               ----               -------
  Normal   Scheduled  112s               default-scheduler  Successfully assigned kube-system/aws-node-qx287 to ip-192-168-2-155.ec2.internal
  Normal   Pulling    112s               kubelet            Pulling image "602401143452.dkr.ecr.us-east-1.amazonaws.com/amazon-k8s-cni-init:v1.19.2-eksbuild.5"
  Normal   Pulled     112s               kubelet            Successfully pulled image "602401143452.dkr.ecr.us-east-1.amazonaws.com/amazon-k8s-cni-init:v1.19.2-eksbuild.5" in 145.717297ms (145.730957ms including waiting)
  Normal   Created    112s               kubelet            Created container aws-vpc-cni-init
  Normal   Started    112s               kubelet            Started container aws-vpc-cni-init
  Normal   Pulled     110s               kubelet            Container image "602401143452.dkr.ecr.us-east-1.amazonaws.com/amazon-k8s-cni:v1.19.2-eksbuild.5" already present on machine
  Normal   Created    110s               kubelet            Created container aws-node
  Normal   Started    110s               kubelet            Started container aws-node
  Normal   Pulling    110s               kubelet            Pulling image "602401143452.dkr.ecr.us-east-1.amazonaws.com/amazon/aws-network-policy-agent:v1.1.6-eksbuild.2"
  Normal   Pulled     110s               kubelet            Successfully pulled image "602401143452.dkr.ecr.us-east-1.amazonaws.com/amazon/aws-network-policy-agent:v1.1.6-eksbuild.2" in 132.412679ms (132.423843ms including waiting)
  Normal   Created    110s               kubelet            Created container aws-eks-nodeagent
  Normal   Started    110s               kubelet            Started container aws-eks-nodeagent
  Warning  Unhealthy  104s               kubelet            Readiness probe failed: {"level":"info","ts":"2025-02-20T18:04:28.300Z","caller":"/usr/local/go/src/runtime/proc.go:271","msg":"timeout: failed to connect service \":50051\" within 5s"}
  Warning  Unhealthy  99s                kubelet            Readiness probe failed: {"level":"info","ts":"2025-02-20T18:04:33.327Z","caller":"/usr/local/go/src/runtime/proc.go:271","msg":"timeout: failed to connect service \":50051\" within 5s"}
  Warning  Unhealthy  94s                kubelet            Readiness probe failed: {"level":"info","ts":"2025-02-20T18:04:38.419Z","caller":"/usr/local/go/src/runtime/proc.go:271","msg":"timeout: failed to connect service \":50051\" within 5s"}
  Warning  Unhealthy  87s                kubelet            Readiness probe failed: {"level":"info","ts":"2025-02-20T18:04:45.582Z","caller":"/usr/local/go/src/runtime/proc.go:271","msg":"timeout: failed to connect service \":50051\" within 5s"}
  Warning  Unhealthy  77s                kubelet            Readiness probe failed: {"level":"info","ts":"2025-02-20T18:04:55.587Z","caller":"/usr/local/go/src/runtime/proc.go:271","msg":"timeout: failed to connect service \":50051\" within 5s"}
  Warning  Unhealthy  67s                kubelet            Readiness probe failed: {"level":"info","ts":"2025-02-20T18:05:05.555Z","caller":"/usr/local/go/src/runtime/proc.go:271","msg":"timeout: failed to connect service \":50051\" within 5s"}
  Warning  Unhealthy  57s                kubelet            Readiness probe failed: {"level":"info","ts":"2025-02-20T18:05:15.550Z","caller":"/usr/local/go/src/runtime/proc.go:271","msg":"timeout: failed to connect service \":50051\" within 5s"}
  Warning  Unhealthy  47s                kubelet            Readiness probe failed: {"level":"info","ts":"2025-02-20T18:05:25.571Z","caller":"/usr/local/go/src/runtime/proc.go:271","msg":"timeout: failed to connect service \":50051\" within 5s"}
  Warning  Unhealthy  37s                kubelet            Liveness probe failed: {"level":"info","ts":"2025-02-20T18:05:35.595Z","caller":"/usr/local/go/src/runtime/proc.go:271","msg":"timeout: failed to connect service \":50051\" within 5s"}
  Warning  Unhealthy  17s (x4 over 37s)  kubelet            (combined from similar events): Liveness probe failed: {"level":"info","ts":"2025-02-20T18:05:55.576Z","caller":"/usr/local/go/src/runtime/proc.go:271","msg":"timeout: failed to connect service \":50051\" within 5s"}
  Normal   Killing    17s                kubelet            Container aws-node failed liveness probe, will be restarted
  ```
  ## Key Observations

1. **Readiness Probe Failures**  
   - Repeated readiness probe failures with the error:  
     `timeout: failed to connect service ":50051" within 5s`.  
   - Indicates the `aws-node` container cannot connect to the gRPC service on port `50051`.  

2. **Liveness Probe Failure**  
   - After multiple readiness failures, the liveness probe also failed with the same error.  
   - Resulted in the `kubelet` restarting the `aws-node` container.  

3. **Pod Status**  
   - The pod remained in a `1/2` state (one container not ready).  
   - The `aws-node` container failed, while the `aws-eks-nodeagent` container ran successfully.

This output clearly shows the sequence of events leading to the `1/2` status and highlights the root cause: the inability of the `aws-node` container to connect to the gRPC service on port `50051`.

# After investigating, I realized I had **misconfigured multiple steps** during the update process.

## 1) Misconfigured IRSA Role (EKS-VPC-CNI-Addon-Role)

### Context
The **VPC CNI plugin** traditionally relies on the node’s IAM role, granting broad permissions to all pods. To enhance security, **IAM Roles for Service Accounts (IRSA)** allow fine-grained access control by associating a dedicated IAM role with the `aws-node` service account.

### Mistake
I accidentally used an incorrect **AWS account ID** when defining the IAM trust policy. Specifically, I copied and pasted the following JSON configuration but left the **wrong ACCOUNT_ID** from a separate sandbox account:

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

This caused the `aws-node` pod to **fail to assume the IAM role**, leading to authentication issues.

---

## 2) Missing OIDC Provider Association

I **forgot to associate the OIDC provider** with the EKS cluster, which is a critical step in enabling IRSA. Without this, the service account cannot assume the IAM role.

### Correct Command
```bash
eksctl utils associate-iam-oidc-provider --cluster minimal-eks-cluster --approve
```

### Why It Matters
- The **OIDC provider** allows Kubernetes service accounts to authenticate with AWS.
- Without it, AWS **cannot validate the web identity token**, preventing the `aws-node` pod from assuming its IAM role.

---

## 3) Missing Service Account Annotation

### What Happens If the Annotation is Missing?
Without the **`eks.amazonaws.com/role-arn`** annotation, the `aws-node` pod **fails to assume the IAM role**, leading to several issues:

- **Authentication Failures with AWS Services**
  - Errors such as:
    ```bash
    timeout: failed to connect service "50051" within 5s
    ```
  - Missing permissions for actions like:
    - Managing **Elastic Network Interfaces (ENIs)**
    - Assigning **IP addresses**

- **Readiness and Liveness Probe Failures**
  - The pod enters a **CrashLoopBackOff** state due to failed health checks.

### How the Annotation Enables Authentication
1. **Pod Initialization**  
   - The `aws-node` pod is assigned a **service account** with the required IAM role annotation.

2. **Web Identity Token Injection**  
   - Kubernetes injects a **web identity token** into the pod at:
     ```
     /var/run/secrets/eks.amazonaws.com/serviceaccount/token
     ```

3. **IAM Role Assumption via AWS STS**  
   - The pod presents the web identity token to **AWS Security Token Service (STS)**.
   - AWS validates the token against the **OIDC provider** and allows the pod to assume the IAM role.

---

## Resolution & Key Takeaways
After correcting the **IAM trust policy**, associating the **OIDC provider**, and adding the **service account annotation**, the `aws-node` pods successfully transitioned to **2/2 status**.

### Lessons Learned
- Always verify the **AWS account ID** when setting up trust policies.
- Ensure the **OIDC provider** is properly associated before using IRSA.
- Confirm that **service account annotations** are correctly applied to enable role assumption.

This experience reinforced the importance of **carefully validating IAM configurations** when working with EKS and IRSA.

### Here there are some steps the I tried when troubleshooting. These did not take me to the root issue, but made me learn another thing about Docker


## Step 1: Inspect the Container Image Locally

Since the container failed due to missing host mounts, we need to inspect the image directly to verify its contents and ensure it includes the necessary binaries (`ls`, `cat`, `curl`, etc.).

Run the following command to start an interactive shell inside the container without attempting to execute any commands:

```bash
docker run --rm -it --entrypoint sh 602401143452.dkr.ecr.us-east-1.amazonaws.com/amazon-k8s-cni:v1.19.2-eksbuild.5
```

Once inside the container, check the `$PATH` variable and verify whether common binaries are available:

```bash
echo $PATH
which ls cat curl printenv
```

## What to Expect

1. If the binaries (`ls`, `cat`, `curl`, etc.) are present, this confirms that the container image is correctly built and includes the necessary tools.
2. If the binaries are missing, this indicates that the container image is incomplete or misconfigured.

Here is the output if the suggested command.

```bash 
docker run --rm -it --entrypoint sh 602401143452.dkr.ecr.us-east-1.amazonaws.com/amazon-k8s-cni:v1.19.2-eksbuild.5  
docker: Error response from daemon: failed to create task for container: failed to create shim task: OCI runtime create failed: runc create failed: unable to start container process: error during container init: exec: "sh": executable file not found in $PATH: unknown  
Run 'docker run --help' for more information
```

The error message indicates that the `sh` shell is not available in the container image. This suggests that the container image is built with a minimal environment and does not include common shells like `sh` or `bash`. However, we can still inspect the contents of the image by using alternative methods.

## Step 2: Inspect the Image Using `docker export`

Since the container image does not include `sh`, we can use `docker export` to extract the filesystem of the container and inspect its contents locally.

Run the following commands:

1. Start a temporary container from the image:
```bash
docker create --name temp-container 602401143452.dkr.ecr.us-east-1.amazonaws.com/amazon-k8s-cni:v1.19.2-eksbuild.5
```

2. Export the container's filesystem to a tar archive:
```bash
docker export temp-container > cni-image.tar
```

3. Extract the tar archive to a local directory:
```bash
mkdir cni-inspect
tar -xvf cni-image.tar -C cni-inspect/
```

4. Inspect the extracted files:
```bash
ls -l cni-inspect/
```