#---------------------------------------------------------------
# Kubernetes Add-ons
#---------------------------------------------------------------
# module "eks_blueprints_kubernetes_addons" {
#   source = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/kubernetes-addons?ref=v4.24.0"
#   #source = "/home/aly/terraform-aws-eks-blueprints/modules/kubernetes-addons?ref=k8ssandra_operator"

#   # eks_cluster_id = local.name
#   eks_cluster_id       = module.eks.cluster_name
#   eks_cluster_endpoint = module.eks.cluster_endpoint
#   eks_oidc_provider    = module.eks.cluster_oidc_issuer_url
#   eks_cluster_version  = module.eks.cluster_version

#   # source = "github.com/aws-ia/terraform-aws-eks-blueprints-addons"

#   # cluster_name      = module.eks.cluster_name
#   # cluster_endpoint  = module.eks.cluster_endpoint
#   # cluster_version   = module.eks.cluster_version
#   # oidc_provider     = module.eks.cluster_oidc_issuer_url
#   # oidc_provider_arn = module.eks.oidc_provider_arn

#   # EKS Addons
#   enable_amazon_eks_vpc_cni            = true
#   enable_amazon_eks_coredns            = true
#   enable_amazon_eks_kube_proxy         = true
#   enable_amazon_eks_aws_ebs_csi_driver = true

#   enable_metrics_server     = true
#   enable_cluster_autoscaler = true
#   enable_aws_for_fluentbit            = true
#   enable_aws_load_balancer_controller = true
#   # enable_prometheus                   = true
#   # enable_grafana                      = true
# #   enable_kube_prometheus_stack = true
# #   kube_prometheus_stack_helm_config = {
# #     name             = "prometheus-grafana"
# #     chart            = "kube-prometheus-stack"
# #     repository       = "https://prometheus-community.github.io/helm-charts"
# #     version          = "43.2.1"
# #     namespace        = local.k8ssandra_operator_name
# #     create_namespace = true
# #     timeout          = 600
# #     values           = [templatefile("${path.module}/helm-values/prom-grafana-values.yaml", {})]
# #     description      = "Kube Prometheus Grafana Stack Operator Chart"
  
# #   }

#   # Install Cert Manager

#   # enable_cert_manager = true

#   # cert_manager_helm_config = {
#   #   name        = "cert-manager"
#   #   chart       = "cert-manager"
#   #   repository  = "https://charts.jetstack.io"
#   #   version     = "v1.10.0"
#   #   namespace   = local.k8ssandra_operator_name
#   #   description = "Cert Manager Add-on"
#   #   wait        = true
#   # }

#   # K8ssandra Operator add-on with custom helm config
#   # enable_k8ssandra_operator = true

#   # k8ssandra_operator_helm_config = {
#   #   name             = local.k8ssandra_operator_name
#   #   chart            = "k8ssandra-operator"
#   #   repository       = "https://helm.k8ssandra.io/stable"
#   #   version          = "0.39.1"
#   #   namespace        = local.k8ssandra_operator_name
#   #   create_namespace = false
#   #   timeout          = 600
#   #   values           = [templatefile("${path.module}/helm-values/values.yaml", {})]
#   #   description      = "K8ssandra Operator to run Cassandra DB on Kubernetes"
#   # }
#   tags = local.tags
# }


# resource "helm_release" "aws-ebs-csi-driver" {
# name        = local.csi_name
#     description = "The Amazon Elastic Block Store Container Storage Interface (CSI) Driver provides a CSI interface used by Container Orchestrators to manage the lifecycle of Amazon EBS volumes."
#     chart       = "aws-ebs-csi-driver"
#     version     = "2.12.1"
#     repository  = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
#     namespace   = "aws-ebs-csi-driver"
#     values = [
#       <<-EOT
#       image:
#         repository: public.ecr.aws/ebs-csi-driver/aws-ebs-csi-driver
#       controller:
#         k8sTagClusterId: ${module.eks_blueprints.eks_cluster_id}
#       node:
#         tolerateAllTaints: true
#       EOT
#     ]
# }





#---------------------------------------------------------------
# GP3 Storage Class
#---------------------------------------------------------------
resource "kubectl_manifest" "gp3_sc" {
  yaml_body = <<-YAML
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
  name: gp3
parameters:
  fsType: xfs
  type: gp3
  encrypted: "true"
allowVolumeExpansion: true
provisioner: ebs.csi.aws.com
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
YAML

  depends_on = [module.eks.cluster_id]
}

#---------------------------------------------------------------
# Install K8ssandra Operator
#---------------------------------------------------------------

resource "helm_release" "cert_manager" {
  name  = "cert-manager"
  chart = "cert-manager"
  repository  = "https://charts.jetstack.io"
  version     = "v1.10.0"
  namespace   = "cert-manager"
  create_namespace = true
  description = "Cert Manager Add-on"
  wait        = true
  set {
    name  = "installCRDs"
    value = true
  }
  depends_on = [module.eks.cluster_id]
}

resource "helm_release" "kube_prometheus_stack" {
  name             = "prometheus-grafana"
  chart            = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  version          = "43.2.1"    
  namespace        = local.k8ssandra_operator_name
  create_namespace = true
  description      = "Kube Prometheus Grafana Stack Operator Chart"
  timeout          = 600
  wait        = true
  values           = [templatefile("${path.module}/helm-values/prom-grafana-values.yaml", {})]
  depends_on = [module.eks.cluster_id]
}

resource "helm_release" "k8ssandra_operator" {
  name  = "k8ssandra-operator"
  chart = "k8ssandra-operator"
  repository  = "https://helm.k8ssandra.io/stable"
  version     = "0.39.1"
  namespace   = "k8ssandra-operator"
  create_namespace = true
  description = "K8ssandra Operator to run Cassandra DB on Kubernetes"
  wait        = true
  values           = [templatefile("${path.module}/helm-values/values.yaml", {})]
  depends_on = [helm_release.cert_manager]
}


# module "helm_addon" {
#   source            = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/kubernetes-addons/helm-addon"
#   helm_config       = local.k8ssandra_operator_helm_config
#   addon_context     = module.eks_blueprints_kubernetes_addons.addon_context
#   # manage_via_gitops = var.manage_via_gitops
#   depends_on = [helm_release.cert_manager]
# }

#---------------------------------------------------------------
# Install Cassandra Cluster
#---------------------------------------------------------------

resource "kubectl_manifest" "cassandra_namespace" {
  
  yaml_body = file("./examples/cassandra-ns.yml")
  depends_on = [helm_release.k8ssandra_operator]
}

resource "kubectl_manifest" "cassandra_cluster" {
  yaml_body = file("./examples/cassandra-manifests/cassandra-cluster.yml")
  depends_on = [helm_release.k8ssandra_operator]
}

# resource "kubectl_manifest" "grafana-prometheus-datasource" {
#   yaml_body = file("./kubernetes-manifests/grafana-manifests/grafana-operator-datasource-prometheus.yml")
# }

resource "kubectl_manifest" "grafana_cassandra_dashboard" {
  yaml_body = file("./examples/cassandra-manifests/grafana-dashboards.yml")
  depends_on = [helm_release.k8ssandra_operator]
}
