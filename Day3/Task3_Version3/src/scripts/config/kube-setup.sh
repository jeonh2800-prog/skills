#!/bin/bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION_CODE="ap-northeast-2"
EKS_CLUSTER_NAME="apdev-eks-cluster"
EKS_APP_NODE_GROUP_SECURITY_GROUP_NAME="apdev-app-node-sg"
APP_ALB_SECURITY_GROUP_NAME="apdev-app-alb-sg"
MONITORING_ALB_SECURITY_GROUP_NAME="apdev-monitoring-alb-sg"

CLUSTER_YAML_PATH=$(sudo find / -name "cluster.yaml" 2>/dev/null)

eksctl create cluster -f $CLUSTER_YAML_PATH
aws eks --region $REGION_CODE update-kubeconfig --name $EKS_CLUSTER_NAME
su - ec2-user -c 'REGION_CODE="ap-northeast-2"; EKS_CLUSTER_NAME="apdev-eks-cluster"; aws eks --region $REGION_CODE update-kubeconfig --name $EKS_CLUSTER_NAME'

kubectl create ns apdev
kubectl create ns monitoring

ADDON_NODE_GROUP_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
kubectl taint nodes $ADDON_NODE_GROUP_NAME dedicated=addon:NoSchedule

EKS_APP_NODE_GROUP_SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --query "SecurityGroups[?GroupName=='$EKS_APP_NODE_GROUP_SECURITY_GROUP_NAME'].GroupId" --output text --region $REGION_CODE)
EKS_CLUSTER_SECURITY_GROUP_ID=$(aws eks describe-cluster --name $EKS_CLUSTER_NAME --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" --output text --region $REGION_CODE)

aws ec2 authorize-security-group-ingress --group-id $EKS_CLUSTER_SECURITY_GROUP_ID --protocol -1 --source-group $EKS_APP_NODE_GROUP_SECURITY_GROUP_ID --region $REGION_CODE > /dev/null
aws ec2 authorize-security-group-ingress --group-id $EKS_APP_NODE_GROUP_SECURITY_GROUP_ID --protocol -1 --source-group $EKS_CLUSTER_SECURITY_GROUP_ID --region $REGION_CODE > /dev/null
aws ec2 authorize-security-group-ingress --group-id $EKS_APP_NODE_GROUP_SECURITY_GROUP_ID --protocol -1 --source-group $EKS_APP_NODE_GROUP_SECURITY_GROUP_ID --region $REGION_CODE > /dev/null

sleep 30

kubectl patch deployment karpenter -n karpenter --type='json' -p='[
  {"op": "replace", "path": "/spec/replicas", "value": 1},
  {"op": "add", "path": "/spec/template/spec/nodeSelector", "value": {"type": "addon"}},
  {"op": "add", "path": "/spec/template/spec/tolerations/-", "value": {"key": "dedicated", "operator": "Equal", "value": "addon", "effect": "NoSchedule"}}
]'

/home/ec2-user/scripts/config/karpenter-tag.sh

KARPENTER_ROLE_NAME=$(aws iam list-roles --query 'Roles[].RoleName' --output text | tr '\t' '\n' | grep -i karpenter)
aws iam attach-role-policy --role-name $KARPENTER_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess --region $REGION_CODE
sed -i "s|KARPENTER_ROLE_NAME|$KARPENTER_ROLE_NAME|g" /home/ec2-user/eks/manifest/karpenter.yaml

kubectl apply -f /home/ec2-user/eks/manifest/karpenter.yaml

sleep 30

kubectl patch deployment coredns -n kube-system --type='json' -p='[
  {"op": "replace", "path": "/spec/replicas", "value": 1},
  {"op": "add", "path": "/spec/template/spec/nodeSelector", "value": {"type": "addon"}},
  {"op": "add", "path": "/spec/template/spec/tolerations/-", "value": {"key": "dedicated", "operator": "Equal", "value": "addon", "effect": "NoSchedule"}}
]'

kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
  {"op": "replace", "path": "/spec/replicas", "value": 1},
  {"op": "add", "path": "/spec/template/spec/nodeSelector", "value": {"type": "addon"}},
  {"op": "add", "path": "/spec/template/spec/tolerations/-", "value": {"key": "dedicated", "operator": "Equal", "value": "addon","effect": "NoSchedule"}}
]'

eksctl create iamserviceaccount \
  --name apdev-product-sa \
  --region=$REGION_CODE \
  --cluster $EKS_CLUSTER_NAME \
  --namespace=apdev \
  --attach-policy-arn "arn:aws:iam::aws:policy/AmazonS3FullAccess" \
  --override-existing-serviceaccounts \
  --approve

kubectl apply -f /home/ec2-user/eks/manifest/configmap.yaml
kubectl apply -f /home/ec2-user/eks/manifest/secrets.yaml

kubectl apply -f /home/ec2-user/eks/manifest/user/hpa.yaml
kubectl apply -f /home/ec2-user/eks/manifest/user/deployment.yaml
kubectl apply -f /home/ec2-user/eks/manifest/user/service.yaml

kubectl apply -f /home/ec2-user/eks/manifest/product/configmap.yaml
kubectl apply -f /home/ec2-user/eks/manifest/product/hpa.yaml
kubectl apply -f /home/ec2-user/eks/manifest/product/deployment.yaml
kubectl apply -f /home/ec2-user/eks/manifest/product/service.yaml

kubectl apply -f /home/ec2-user/eks/manifest/stress/hpa.yaml
kubectl apply -f /home/ec2-user/eks/manifest/stress/deployment.yaml
kubectl apply -f /home/ec2-user/eks/manifest/stress/service.yaml

helm repo add eks https://aws.github.io/eks-charts
helm repo update eks
helm upgrade -i aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$EKS_CLUSTER_NAME \
  -f /home/ec2-user/eks/manifest/ingress/values.yaml

APP_ALB_SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --query "SecurityGroups[?GroupName=='$APP_ALB_SECURITY_GROUP_NAME'].GroupId" --output text --region $REGION_CODE)
EKS_CLUSTER_SECURITY_GROUP_ID=$(aws eks describe-cluster --name $EKS_CLUSTER_NAME --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" --output text --region $REGION_CODE)
aws ec2 authorize-security-group-ingress --group-id $EKS_CLUSTER_SECURITY_GROUP_ID --protocol tcp --port 8080 --source-group $APP_ALB_SECURITY_GROUP_ID > /dev/null

sed -i "s|SECURITY_GROUP_ID|$APP_ALB_SECURITY_GROUP_ID|g" /home/ec2-user/eks/manifest/ingress/ingress.yaml

sleep 30

kubectl apply -f /home/ec2-user/eks/manifest/ingress/ingress.yaml

sleep 30

MONITORING_ALB_SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --query "SecurityGroups[?GroupName=='$MONITORING_ALB_SECURITY_GROUP_NAME'].GroupId" --output text --region $REGION_CODE)
EKS_CLUSTER_SECURITY_GROUP_ID=$(aws eks describe-cluster --name $EKS_CLUSTER_NAME --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" --output text --region $REGION_CODE)
aws ec2 authorize-security-group-ingress --group-id $EKS_CLUSTER_SECURITY_GROUP_ID --protocol tcp --port 3000 --source-group $MONITORING_ALB_SECURITY_GROUP_ID > /dev/null
aws ec2 authorize-security-group-ingress --group-id $EKS_CLUSTER_SECURITY_GROUP_ID --protocol tcp --port 9090 --source-group $MONITORING_ALB_SECURITY_GROUP_ID > /dev/null

sed -i "s|SECURITY_GROUP_ID|$MONITORING_ALB_SECURITY_GROUP_ID|g" /home/ec2-user/eks/manifest/grafana/ingress.yaml
sed -i "s|SECURITY_GROUP_ID|$MONITORING_ALB_SECURITY_GROUP_ID|g" /home/ec2-user/eks/manifest/prometheus/ingress.yaml

eksctl utils associate-iam-oidc-provider --region $REGION_CODE --cluster $EKS_CLUSTER_NAME --approve

eksctl create iamserviceaccount \
  --name ebs-csi-controller-sa \
  --region $REGION_CODE \
  --cluster $EKS_CLUSTER_NAME \
  --namespace kube-system \
  --role-name AmazonEKS_EBS_CSI_DriverRole \
  --role-only \
  --attach-policy-arn arn:aws:iam::aws:policy/AmazonEBSCSIDriverPolicyV2 \
  --approve

eksctl create addon \
  --name aws-ebs-csi-driver \
  --region $REGION_CODE \
  --cluster $EKS_CLUSTER_NAME \
  --service-account-role-arn arn:aws:iam::$ACCOUNT_ID:role/AmazonEKS_EBS_CSI_DriverRole \
  --force

sleep 30

kubectl patch deployment ebs-csi-controller -n kube-system --type='json' -p='[
  {"op": "replace", "path": "/spec/replicas", "value": 1},
  {"op": "add", "path": "/spec/template/spec/nodeSelector", "value": {"type": "addon"}},
  {"op": "add", "path": "/spec/template/spec/tolerations/-", "value": {"key": "dedicated", "operator": "Equal", "value": "addon", "effect": "NoSchedule"}}
]'

kubectl patch daemonset ebs-csi-node -n kube-system --type='json' -p='[
  {"op": "add", "path": "/spec/template/spec/nodeSelector", "value": {"type": "addon"}},
  {"op": "add", "path": "/spec/template/spec/tolerations/-", "value": {"key": "dedicated", "operator": "Equal", "value": "addon", "effect": "NoSchedule"}}
]'

sleep 10

kubectl apply -f /home/ec2-user/eks/manifest/prometheus/sc.yaml

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade -i prometheus prometheus-community/prometheus \
  -n monitoring \
  -f /home/ec2-user/eks/manifest/prometheus/values.yaml

sleep 30

# kubectl apply -f /home/ec2-user/eks/manifest/grafana/configmap.yaml

S3_BUCKET_NAME=$(aws s3api list-buckets --query "Buckets[?contains(Name, 'apdev-logs')].Name" --output text --region $REGION_CODE)
sed -i "s|S3_BUCKET_NAME|$S3_BUCKET_NAME|g" /home/ec2-user/eks/manifest/grafana/values.yaml

eksctl create iamserviceaccount \
  --name apdev-grafana-sa \
  --region=$REGION_CODE \
  --cluster $EKS_CLUSTER_NAME \
  --namespace=monitoring \
  --attach-policy-arn "arn:aws:iam::aws:policy/AdministratorAccess" \
  --override-existing-serviceaccounts \
  --approve

helm repo add grafana-community https://grafana-community.github.io/helm-charts
helm repo update
helm upgrade -i grafana grafana-community/grafana \
  -n monitoring \
  -f /home/ec2-user/eks/manifest/grafana/values.yaml

sleep 30

kubectl apply -f /home/ec2-user/eks/manifest/prometheus/ingress.yaml
kubectl apply -f /home/ec2-user/eks/manifest/grafana/ingress.yaml