# Terraform — AWS VPC + EKS

Provisions the production-style infrastructure for TaskBoard in `ap-south-1` (Mumbai):

| Resource | Details |
|---|---|
| VPC | `10.20.0.0/16`, DNS hostnames on |
| Public subnets (2) | `10.20.101.0/24`, `10.20.102.0/24`, tagged `kubernetes.io/role/elb=1` for internet-facing LBs |
| Private subnets (2) | `10.20.1.0/24`, `10.20.2.0/24`, tagged `kubernetes.io/role/internal-elb=1`; worker nodes live here |
| NAT gateway | single (cost-optimised), gives private nodes outbound internet to pull images |
| EKS cluster | Kubernetes `1.35`, public API endpoint, creator gets cluster-admin |
| Managed node group | 2 × `t3.medium` (min 2 / max 4), Amazon Linux 2023 AMI |
| Add-ons | vpc-cni, kube-proxy, coredns, eks-pod-identity-agent, **metrics-server** (for HPA), **aws-ebs-csi-driver** (for the Postgres PVC, IAM via EKS Pod Identity) |

Modules: `terraform-aws-modules/vpc/aws ~> 6.7`, `terraform-aws-modules/eks/aws ~> 21.29`,
`terraform-aws-modules/eks-pod-identity/aws ~> 2.10` on AWS provider `~> 6.0`. `.terraform.lock.hcl` is committed so
everyone gets identical provider builds.

## Usage

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # optional: adjust region / sizes (never put keys here)
terraform init
terraform fmt -check && terraform validate
terraform plan -out tfplan                      # expect: Plan: 61 to add, 0 to change, 0 to destroy
terraform apply tfplan                          # ~15 min
$(terraform output -raw configure_kubectl)      # aws eks update-kubeconfig --region ap-south-1 --name taskboard-eks
kubectl get nodes
kubectl apply -f ../k8s/storageclass-gp3.yaml   # default StorageClass (EKS >= 1.30 ships none)
```

Credentials come from the AWS CLI chain (`aws configure`, `AWS_PROFILE`, SSO). Nothing secret is stored in this folder;
`*.tfvars` and state files are git-ignored.

## Tear down (do this after grading)

Delete anything Kubernetes created *outside* Terraform first, otherwise the VPC cannot be deleted:

```bash
helm uninstall traefik -n traefik          # removes the AWS load balancer it created
kubectl delete pvc --all -n taskboard      # removes the EBS volume (the chart keeps the PVC on uninstall)
terraform destroy
```

## Cost (ap-south-1, approximate)

EKS control plane ≈ $0.10/h, 2 × t3.medium ≈ $0.09/h, NAT gateway ≈ $0.056/h + data, load balancer ≈ $0.025/h:
**≈ $0.27/hour (~$6.50/day)**. Apply, record the demo, destroy.

## Design notes

- **Why 1.35?** EKS no longer offers 1.31 (the original value); 1.32/1.33 are in paid extended support. Check with
  `aws eks describe-cluster-versions`.
- **Why AL2023?** Amazon Linux 2 EKS AMIs are not published for Kubernetes >= 1.33.
- **Why the EBS CSI driver?** Without it a `PersistentVolumeClaim` never binds on EKS, so PostgreSQL would stay Pending.
- **Why metrics-server?** The HPA reads CPU from the metrics API; EKS does not install it by default.
