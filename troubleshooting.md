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
