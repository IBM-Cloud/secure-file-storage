# Deploy services for "Secure File Storage" solution


This set of Terraform files can be used to provision the IBM Cloud services for the solution tutorial on applying end to end security to a cloud application. It is assumed that a Kubernetes cluster, e.g., in a VPC, is already available.

[Click here to deploy](https://cloud.ibm.com/schematics/workspaces/create?repository=https://github.com/IBM-Cloud/secure-file-storage/tree/terraform/terraform)


Steps:
1. Manually create a Schematics workspace and use this branch and directory. Specify Terraform v0.13. Or click this link: https://cloud.ibm.com/schematics/workspaces/create?repository=https://github.com/IBM-Cloud/secure-file-storage/tree/terraform/terraform&terraform_version=terraform_v0.13
2. Configure all required variables. This could be:
   - region: us-south, eu-de, ...
   - iks_cluster_name: name of your existing (VPC-based) Kubernetes cluster
   - iks_namespace: Kubernetes namespace into which to deploy
   - resource_group: the IBM Cloud resource group where to deploy the services
   - basename: project basename which is used as prefix for names
3. Optionally "Generate plan" to check for issues
4. Apply plan
5. Create a new toolchain in the Continuous Delivery service. Click this link: https://cloud.ibm.com/devops/setup/deploy?repository=https%3A//github.com/IBM-Cloud/secure-file-storage&env_id=ibm:yp:us-south&type=tekton&branch=terraform Configure the git repository, e.g. by picking "Existing" repository if you don't plan to change any code. On the pipeline dialog, add or reuse an API key. Add the ID of the Schematics workspace from above (can be found under workspace settings). 
6. Run pipeline by picking the "builddeploy" pipeline. The link to the deployed app should be shown in the logs of the last step.
