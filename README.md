# Apply end to end security to securely store files

The repository features a sample application that enables groups of users to upload files to a common storage pool and to provide access to those files via shareable links. The application is written in Node.js and deployed as Docker container to the IBM Cloud Kubernetes service. It leverages several security-related services and features to improve app security. It includes data encrypted with your own keys, user authentication, and security auditing.

Refer to [this tutorial](https://console.bluemix.net/docs/tutorials/cloud-e2e-security.html) for instructions.

![Architecture](Architecture.png)

1. The user connects to the application.
2. [App ID](https://console.bluemix.net/catalog/services/AppID) secures the application and redirects the user to the authentication page. Users can sign up from there too.
3. The application is running in a [Kubernetes cluster](https://console.bluemix.net/containers-kubernetes/catalog/cluster) from an image stored in the [container registry](https://console.bluemix.net/containers-kubernetes/launchRegistryView). The image is automatically scanned for vulnerabilities.
4. Files uploaded by the user are stored in [Cloud Object Storage](https://console.bluemix.net/catalog/services/cloud-object-storage).
5. The bucket where the files are stored is using a user-provided key to encrypt the data.
6. All activities related to managing the solution are logged by [Activity Tracker](https://console.bluemix.net/catalog/services/activity-tracker).

## Deploy with a toolchain

This project comes with a partially automated toolchain capable of deploying the application to IBM Cloud while provisioning all required services.

### Prerequisites

1. Create a **standard** Kubernetes cluster

1. Create a registry namespace

1. Optionally create a specific resource group for this project

### And then

[![Create toolchain](https://console.bluemix.net/devops/graphics/create_toolchain_button.png)](https://console.bluemix.net/devops/setup/deploy/?repository=https%3A//github.com/IBM-Cloud/secure-file-storage)

Once the toolchain has completed, the application will be available at `https://secure-file-storage.<your-cluster-ingress-domain>`.

The toolchain includes a stage named **UNINSTALL (manual)**. This stage can only be triggered manually and will remove all resources created by the toolchain (app and services).

## Code Structure

| File | Description |
| ---- | ----------- |
|[app.js](app.js)|Implementation of the application.|
|[credentials.template.env](credentials.template.env)|To be copied to `credentials.env` and filled with credentials to access services. `credentials.env` is used when running the app locally and to create a Kubernetes secret before deploying the application to a cluster manually.|
|[Dockerfile](Dockerfile)|Docker image description file.|
|[secure-file-storage.template.yaml](secure-file-storage.template.yaml)|Kubernetes deployment file with placeholders. To be copied to `secure-file-storage.yaml` and edited to match your environment.|

### To test locally

1. Follow the tutorial instructions to have the app deployed to a cluster. Specially the sections to create all the services and to populate the `credentials.env` file.
1. Access the tokens with `https://secure-file-storage.<INGRESS_SUBDOMAIN>/api/tokens`. This will shows the raw App ID authorization header together with the decode JWT tokens for your session.
1. In your local shell:
   ```
   export TEST_AUTHORIZATION_HEADER="<value of the header attributes 'Bearer ... ...'>"
   ```
1. npm start

## License

See [License.txt](License.txt) for license information.
