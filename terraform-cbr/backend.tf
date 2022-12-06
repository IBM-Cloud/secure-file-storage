data "terraform_remote_state" "e2e-resources" {
  backend = "local"

  config = {
    path = "../terraform/terraform.tfstate"
  }
}