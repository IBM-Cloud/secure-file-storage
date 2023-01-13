# create the toolchain
resource "ibm_cd_toolchain" "cd_toolchain_instance" {
  description       = "toolchain to deploy the secure-file-storage app"
  name              = "secure-file-storage-toolchain"
  resource_group_id = data.ibm_resource_group.cloud_development.id
}

# the Tekton definition for the pipeline
resource "ibm_cd_toolchain_tool_githubconsolidated" "pipeline_repo" {
  toolchain_id = ibm_cd_toolchain.cd_toolchain_instance.id
  name         = "repo"
  initialization {
    type     = "link"
    repo_url = "https://github.com/IBM-Cloud/secure-file-storage"
  }
  parameters {
  }
}

# the Tekton catalog
resource "ibm_cd_toolchain_tool_githubconsolidated" "catalog_repo" {
  toolchain_id = ibm_cd_toolchain.cd_toolchain_instance.id
  name         = "repo"
  initialization {
    type     = "link"
    repo_url = "https://github.com/open-toolchain/tekton-catalog"
  }
  parameters {
  }
}

# create the pipeline itself
resource "ibm_cd_toolchain_tool_pipeline" "cd_pipeline" {
  toolchain_id = ibm_cd_toolchain.cd_toolchain_instance.id
  parameters {
    name = "secure-file-storage-pipeline"
  }
}

# run the Tekton pipeline on a public worker
resource "ibm_cd_tekton_pipeline" "cd_pipeline_instance" {
  pipeline_id            = ibm_cd_toolchain_tool_pipeline.cd_pipeline.tool_id
  enable_notifications   = false    # default
  enable_partial_cloning = false    # default
  worker {
    id = "public"                   # default
  }
}

# Point to the Tekton pipeline definition in the pipeline repo
resource "ibm_cd_tekton_pipeline_definition" "cd_tekton_pipeline_definition_instance" {
  pipeline_id = ibm_cd_tekton_pipeline.cd_pipeline_instance.pipeline_id
  source {
    type = "git"
    properties {
      url    = ibm_cd_toolchain_tool_githubconsolidated.pipeline_repo.parameters[0].repo_url
      branch = "master"
      path   = ".tekton"
    }
  }
}

# Point to the definition of the build task in the catalog repo
resource "ibm_cd_tekton_pipeline_definition" "cd_tekton_pipeline_definition_instance2" {
  pipeline_id = ibm_cd_tekton_pipeline.cd_pipeline_instance.pipeline_id
  source {
    type = "git"
    properties {
      url    = ibm_cd_toolchain_tool_githubconsolidated.catalog_repo.parameters[0].repo_url
      branch = "master"
      path   = "container-registry"
    }
  }
}

# Create a manual trigger and link it to the listener
resource "ibm_cd_tekton_pipeline_trigger" "cd_tekton_pipeline_trigger_instance" {
  pipeline_id    = ibm_cd_tekton_pipeline.cd_pipeline_instance.pipeline_id
  type           = "manual"
  name           = "manual-trigger"
  event_listener = "manual-listener-builddeploy"
  worker {
    id = "public"
  }
  max_concurrent_runs = 1
}
