// Sample app to store and access files securely 
// 
// The app provides a simple web-based service to upload, store, and access
// files. Files can be shared via an expiring file link.
// The app uses IBM Cloudant to store file metadata and IBM Cloud Object Storage
// for the actual file object.
//
// The API functions are called from client-side JavaScript

var express = require('express'),
  formidable = require('formidable'),
  cookieParser = require('cookie-parser'),
  util = require('util'),
  fs = require("fs"),
  async = require('async');

// Load environment variables from .env file
require('dotenv').config({
  path: 'credentials.env'
});

var allowAnonymousAccess = process.env.allow_anonymous || false;

// some values taken from the environment
const CLOUDANT_APIKEY = process.env.cloudant_iam_apikey;
const CLOUDANT_URL = process.env.cloudant_url;
const CLOUDANT_DB = process.env.cloudant_database || 'secure-file-storage-metadata';

const COS_BUCKET_NAME = process.env.cos_bucket_name;
const COS_ENDPOINT = process.env.cos_endpoint;
const COS_APIKEY = process.env.cos_apiKey;
const COS_IAM_AUTH_ENDPOINT = process.env.cos_ibmAuthEndpoint || 'https://iam.cloud.ibm.com/identity/token';
const COS_INSTANCE_ID = process.env.cos_resourceInstanceID;
const COS_ACCESS_KEY_ID = process.env.cos_access_key_id;
const COS_SECRET_ACCESS_KEY = process.env.cos_secret_access_key;

// Initialize Cloudant
const { IamAuthenticator } = require('ibm-cloud-sdk-core');
const authenticator = new IamAuthenticator({
  apikey: CLOUDANT_APIKEY
});

const { CloudantV1 } = require('@ibm-cloud/cloudant');

const cloudant = CloudantV1.newInstance({ authenticator: authenticator });
cloudant.setServiceUrl(CLOUDANT_URL);

// Initialize the COS connection.
var CloudObjectStorage = require('ibm-cos-sdk');
// This connection is used when interacting with the bucket from the app to upload/delete files.
var config = {
  endpoint: COS_ENDPOINT,
  apiKeyId: COS_APIKEY,
  ibmAuthEndpoint: COS_IAM_AUTH_ENDPOINT,
  serviceInstanceId: COS_INSTANCE_ID,
};
var cos = new CloudObjectStorage.S3(config);

// Then this other connection is only used to generate the pre-signed URLs.
// Pre-signed URLs require the COS public endpoint if we want the users to be
// able to access the content from their own computer.
//
// We derive the COS public endpoint from what should be the private/direct endpoint.
let cosPublicEndpoint = COS_ENDPOINT;
if (cosPublicEndpoint.startsWith('s3.private')) {
  cosPublicEndpoint = `s3${cosPublicEndpoint.substring('s3.private'.length)}`;
} else if (cosPublicEndpoint.startsWith('s3.direct')) {
  cosPublicEndpoint = `s3${cosPublicEndpoint.substring('s3.direct'.length)}`;
}
console.log('Public endpoint for COS is', cosPublicEndpoint);

var cosUrlGenerator = new CloudObjectStorage.S3({
  endpoint: cosPublicEndpoint,
  credentials: new CloudObjectStorage.Credentials(
    COS_ACCESS_KEY_ID,
    COS_SECRET_ACCESS_KEY, sessionToken = null),
  signatureVersion: 'v4',
});

// Simple Express setup
var app = express();
app.use(cookieParser());
// Define routes
app.use('/', express.static(__dirname + '/public'));

// Decodes access and identity tokens sent by App ID in the Authorization header
//
// The token signature or expiration date are not verified here,
// the App ID / Kubernetes integration does this for us.
// The endpoint forbids API calls if the tokens are not found or
// can not be decoded - which should not never happen in the context
// of the App ID / Kubernetes integration.
app.use('/api/', (req, res, next) => {
  const auth = req.header('authorization') || process.env.TEST_AUTHORIZATION_HEADER;
  if (!auth) {
    if (allowAnonymousAccess) {
      next();
    } else {
      res.status(403).send();
    }
  } else {
    // authorization should be "Bearer <access_token> <identity_token>"
    const parts = auth.split(' ');
    if (parts.length !== 3) {
      res.status(403).send({ message: 'Invalid Authorization header. Expecting "Bearer access_token identity_token".' })
      return;
    }
    if (parts[0].toLowerCase() !== 'bearer') {
      res.status(403).send({ message: 'Invalid Authorization header. Bearer not found.' });
      return;
    }
    const jwt = require('jsonwebtoken');
    const access_token = jwt.decode(parts[1]);
    if (!access_token) {
      res.status(403).send({ message: 'Invalid access token' });
      return;
    }
    const identity_token = jwt.decode(parts[2]);
    if (!identity_token) {
      res.status(403).send({ message: 'Invalid identity token' });
      return;
    }

    req.appIdAuthorizationContext = {
      header: auth,
      access_token,
      identity_token,
    };
    next();
  }
});

// Extract the subject out of the access token
function getSub(req) {
  if (req.appIdAuthorizationContext) {
    return req.appIdAuthorizationContext.access_token.sub;
  } else if (allowAnonymousAccess) {
    return '__anonymous__';
  } else {
    throw new Error(403);
  }
}

// Returns all files associated to the current user
app.get('/api/files', async function (req, res) {
  // filter on the userId which is the subject in the access token
  const selector = {
    userId: {
      '$eq': getSub(req)
    }
  };
  // Cloudant API to find documents
  cloudant.postFind({
    db: CLOUDANT_DB,
    selector: selector,
  }).then(response => {
    // remove some metadata
    res.send(response.result.docs.map(function (item) {
      item.id = item._id
      delete item._id;
      delete item._rev;
      return item;
    }));
  }).catch(error => {
    console.log(error.status, error.message);
    res.status(500).send(error.message);
  }
  );
});


// Generates a pre-signed URL to access a file owned by the current user
app.get('/api/files/:id/url', async function (req, res) {
  const selector = {
    userId: {
      '$eq': getSub(req)
    },
    _id: {
      '$eq': req.params.id,
    }
  };
  // Cloudant API to find documents
  cloudant.postFind({
    db: CLOUDANT_DB,
    selector: selector,
  }).then(response => {
    if (response.result.docs.length === 0) {
      res.status(404).send({ message: 'Document not found' });
      return;
    }
    const doc = response.result.docs[0];
    const url = cosUrlGenerator.getSignedUrl('getObject', {
      Bucket: COS_BUCKET_NAME,
      Key: `${doc.userId}/${doc._id}/${doc.name}`,
      Expires: 60 * 5, // 5 minutes
    });

    console.log(`[OK] Built signed url for ${req.params.id}`);
    res.send({ url });
  }).catch(error => {
    console.log(`[KO] Could not retrieve document ${req.params.id}`, err);
    res.status(500).send(err);
  });
});

// Uploads files, associating them to the current user
app.post('/api/files', function (req, res) {
  const form = new formidable.IncomingForm();
  form.multiples = false;
  form.parse(req);

  form.on('error', (err) => {
    res.status(500).send(err);
  });

  form.on('file', (name, file) => {
    console.log(file);
    var fileDetails = {
      name: file.originalFilename,
      type: file.type,
      size: file.size,
      createdAt: new Date(),
      userId: getSub(req),
    };

    console.log(`New file to upload: ${fileDetails.originalFilename} (${fileDetails.size} bytes)`);

    // create Cloudant document
    cloudant.postDocument({
      db: CLOUDANT_DB,
      document: fileDetails
    }).then(async response => {
      fileDetails.id = response.result.id;

      // upload to COS
      await cos.upload({
        Bucket: COS_BUCKET_NAME,
        Key: `${fileDetails.userId}/${fileDetails.id}/${fileDetails.name}`,
        Body: fs.createReadStream(file.filepath),
        ContentType: fileDetails.type,
      }).promise()

      // reply with the document
      console.log(`[OK] Document ${fileDetails.id} uploaded to storage`);
      res.send(fileDetails);
      // delete the file once uploaded
      fs.unlink(file.filepath, (err) => {
        if (err) { console.log(err) }
      });
    }).catch(error => {
      console.log(`[KO] Failed to upload ${fileDetails.name}`, error.message);
      res.status(500).send(error.status, error.message);
    });
  });
});


// Deletes a file associated with the current user
app.delete('/api/files/:id', async function (req, res) {

  console.log(`Deleting document ${req.params.id}`);
  // get the doc from cloudant, ensuring it is owned by the current user
  // filter on the userId which is the subject in the access token
  // AND the document ID
  const selector = {
    userId: {
      '$eq': getSub(req)
    },
    _id: {
      '$eq': req.params.id,
    }
  };
  // Cloudant API to find documents
  cloudant.postFind({
    db: CLOUDANT_DB,
    selector: selector
  }).then(response => {
    if (response.result.docs.length === 0) {
      res.status(404).send({ message: 'Document not found' });
      return;
    }
    const doc = response.result.docs[0];
    // remove the COS object
    console.log(`Removing file ${doc.userId}/${doc._id}/${doc.name}`);

    cos.deleteObject({
      Bucket: COS_BUCKET_NAME,
      Key: `${doc.userId}/${doc._id}/${doc.name}`
    }).promise();

    // remove the cloudant object
    cloudant.deleteDocument({
      db: CLOUDANT_DB,
      docId: doc._id,
      rev: doc._rev
    }).then(response => {
      console.log(`[OK] Successfully deleted ${doc._id}`);
      res.status(204).send();
    }).catch(error => {
      console.log(error.status, error.message);
      res.status(500).send(error.message);
    });

  }).catch(error => {
    console.log(error.status, error.message);
    res.status(500).send(error.message);
  });

});

// Called by App ID when the authorization flow completes
app.get('/appid_callback', function (req, res) {
  res.send('OK');
});

app.get('/api/tokens', function (req, res) {
  res.send(req.appIdAuthorizationContext);
});

app.get('/api/user', function (req, res) {
  let result = {};
  if (req.appIdAuthorizationContext) {
    result = {
      name: req.appIdAuthorizationContext.identity_token.name,
      picture: req.appIdAuthorizationContext.identity_token.picture,
    }
  } else if (allowAnonymousAccess) {
    result = {
      name: 'Anonymous',
    }
  }
  res.send(result);
});

// start the server
const server = app.listen(process.env.PORT || 8081, () => {
  console.log(`Listening on port http://0.0.0.0:${server.address().port}`);
});
