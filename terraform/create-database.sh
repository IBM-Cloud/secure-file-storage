# create a database
set -e

echo "Retrieving IAM tokens for Cloudant API key..."
IAM_TOKENS=$(curl -X POST 'https://iam.cloud.ibm.com/identity/token' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "grant_type=urn:ibm:params:oauth:grant-type:apikey&apikey=$CLOUDANT_IAM_APIKEY")

API_BEARER_TOKEN=$(echo $IAM_TOKENS | jq -r .access_token)

echo "Creating database..."
curl -f -H "Authorization: Bearer $API_BEARER_TOKEN" -X PUT "$CLOUDANT_URL/$CLOUDANT_DATABASE"
