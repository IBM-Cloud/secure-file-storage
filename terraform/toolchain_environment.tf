## Environment variables / configuration for the toolchain with
## the delivery pipeline


resource "ibm_cd_tekton_pipeline_property" "cd_env_schematics_workspace_id" {
  pipeline_id = ibm_cd_tekton_pipeline.cd_pipeline_instance.pipeline_id
  name        = "schematics-workspace-id"
  type        = "text"
  value       = var.toolchain_schematics_workspace_id
}

resource "ibm_cd_tekton_pipeline_property" "cd_env_registry_namespace" {
  pipeline_id = ibm_cd_tekton_pipeline.cd_pipeline_instance.pipeline_id
  name        = "registry-namespace"
  type        = "text"
  value       = var.toolchain_registry_namespace
}

resource "ibm_cd_tekton_pipeline_property" "cd_env_registry_region" {
  pipeline_id = ibm_cd_tekton_pipeline.cd_pipeline_instance.pipeline_id
  name        = "registry-region"
  type        = "text"
  value       = var.toolchain_registry_region
}

resource "ibm_cd_tekton_pipeline_property" "cd_env_image_name" {
  pipeline_id = ibm_cd_tekton_pipeline.cd_pipeline_instance.pipeline_id
  name        = "image-name"
  type        = "text"
  value       = var.toolchain_image_name
}

resource "ibm_cd_tekton_pipeline_property" "cd_env_target_region" {
  pipeline_id = ibm_cd_tekton_pipeline.cd_pipeline_instance.pipeline_id
  name        = "target-region"
  type        = "text"
  value       = var.region
}

resource "ibm_cd_tekton_pipeline_property" "cd_env_git_repository" {
  pipeline_id = ibm_cd_tekton_pipeline.cd_pipeline_instance.pipeline_id
  name        = "git-repository"
  type        = "text"
  value       = var.toolchain_git_repository
}

resource "ibm_cd_tekton_pipeline_property" "cd_env_git_branch" {
  pipeline_id = ibm_cd_tekton_pipeline.cd_pipeline_instance.pipeline_id
  name        = "git-branch"
  type        = "text"
  value       = var.toolchain_git_branch
}

resource "ibm_cd_tekton_pipeline_property" "cd_env_deployment_apikey" {
  pipeline_id = ibm_cd_tekton_pipeline.cd_pipeline_instance.pipeline_id
  name        = "apikey"
  type        = "secure"
  value       = var.toolchain_apikey
}
