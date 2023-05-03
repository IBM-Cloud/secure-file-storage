## Environment variables / configuration for the toolchain with
## the delivery pipeline

# This is a "hack" to obtain the workspace ID without creating a variable.
# Else, it would be exposed as editable variable in Schematics which we
# don't want to avoid confusion and errors.
data "external" "env" {
  program = ["jq", "-n", "env"]
}

resource "ibm_cd_tekton_pipeline_property" "cd_env_schematics_workspace_id" {
  pipeline_id = ibm_cd_tekton_pipeline.cd_pipeline_instance.pipeline_id
  name        = "schematics-workspace-id"
  type        = "text"
  # extract the workspace ID, see above
  value       = "${lookup(data.external.env.result, "TF_VAR_IC_SCHEMATICS_WORKSPACE_ID")}"
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

resource "ibm_cd_tekton_pipeline_property" "cd_env_deployment_failscan" {
  pipeline_id = ibm_cd_tekton_pipeline.cd_pipeline_instance.pipeline_id
  name        = "fail-on-scanned-issues"
  type        = "text"
  value       = var.toolchain_failscan
}