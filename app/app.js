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

// Initialize Cloudant
var Cloudant = require('@cloudant/cloudant');
var cloudant = new Cloudant({
  url: process.env.cloudant_url,
  plugins: [
    'promises',
    {
      iamauth: {
        iamApiKey: process.env.cloudant_iam_apikey
      }
    }
  ]
});
var db = cloudant.db.use(process.env.cloudant_database || 'secure-file-storage-metadata');

var CloudObjectStorage = require('ibm-cos-sdk');

// Initialize the COS connection.
// This connection is used when interacting with the bucket from the app to upload/delete files.
var config = {
  endpoint: process.env.cos_endpoint,
  apiKeyId: process.env.cos_apiKey,
  ibmAuthEndpoint: process.env.cos_ibmAuthEndpoint || 'https://iam.cloud.ibm.com/identity/token',
  serviceInstanceId: process.env.cos_resourceInstanceID,
};
var cos = new CloudObjectStorage.S3(config);

// Then this other connection is only used to generate the pre-signed URLs.
// Pre-signed URLs require the COS public endpoint if we want the users to be
// able to access the content from their own computer.
//
// We derive the COS public endpoint from what should be the private/direct endpoint.
let cosPublicEndpoint = process.env.cos_endpoint;
if (cosPublicEndpoint.startsWith('s3.private')) {
  cosPublicEndpoint = `s3${cosPublicEndpoint.substring('s3.private'.length)}`;
} else if (cosPublicEndpoint.startsWith('s3.direct')) {
  cosPublicEndpoint = `s3${cosPublicEndpoint.substring('s3.direct'.length)}`;
}
console.log('Public endpoint for COS is', cosPublicEndpoint);

var cosUrlGenerator = new CloudObjectStorage.S3({
  endpoint: cosPublicEndpoint,
  credentials: new CloudObjectStorage.Credentials(
    process.env.cos_access_key_id,
    process.env.cos_secret_access_key, sessionToken = null),
  signatureVersion: 'v4',
});

const COS_BUCKET_NAME = process.env.cos_bucket_name;

// Define routes
var app = express();
app.use(cookieParser());
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
  try {
    const body = await db.find({
      selector: {
        userId: getSub(req),
      }
    });
    res.send(body.docs.map(function (item) {
      item.id = item._id
      delete item._id;
      delete item._rev;
      return item;
    }));
  } catch (err) {
    console.log(err);
    res.status(500).send(err);
  }
});

// Generates a pre-signed URL to access a file owned by the current user
app.get('/api/files/:id/url', async function (req, res) {
  try {
    const result = await db.find({
      selector: {
        _id: req.params.id,
        userId: getSub(req),
      }
    });
    if (result.docs.length === 0) {
      res.status(404).send({ message: 'Document not found' });
      return;
    }
    const doc = result.docs[0];
    const url = cosUrlGenerator.getSignedUrl('getObject', {
      Bucket: COS_BUCKET_NAME,
      Key: `${doc.userId}/${doc._id}/${doc.name}`,
      Expires: 60 * 5, // 5 minutes
    });

    console.log(`[OK] Built signed url for ${req.params.id}`);
    res.send({ url });
  } catch (err) {
    console.log(`[KO] Could not retrieve document ${req.params.id}`, err);
    res.status(500).send(err);
  }
});

// Uploads files, associating them to the current user
app.post('/api/files', function (req, res) {
  const form = new formidable.IncomingForm();
  form.multiples = false;
  form.parse(req);

  form.on('error', (err) => {
    res.status(500).send(err);
  });

  form.on('file', async (name, file) => {
    var fileDetails = {
      name: file.name,
      type: file.type,
      size: file.size,
      createdAt: new Date(),
      userId: getSub(req),
    };

    try {
      console.log(`New file to upload: ${fileDetails.name} (${fileDetails.size} bytes)`);

      // create Cloudant document
      const doc = await db.insert(fileDetails);
      fileDetails.id = doc.id;

      // upload to COS
      await cos.upload({
        Bucket: COS_BUCKET_NAME,
        Key: `${fileDetails.userId}/${fileDetails.id}/${fileDetails.name}`,
        Body: fs.createReadStream(file.path),
        ContentType: fileDetails.type,
      }).promise();

      // reply with the document
      console.log(`[OK] Document ${fileDetails.id} uploaded to storage`);
      res.send(fileDetails);
    } catch (err) {
      console.log(`[KO] Failed to upload ${fileDetails.name}`, err);
      res.status(500).send(err);
    }

    // delete the file once uploaded
    fs.unlink(file.path, (err) => {
      if (err) { console.log(err) }
    });
  });
});

// Deletes a file associated with the current user
app.delete('/api/files/:id', async function (req, res) {
  try {
    console.log(`Deleting document ${req.params.id}`);

    // get the doc from cloudant, ensuring it is owned by the current user
    const result = await db.find({
      selector: {
        _id: req.params.id,
        userId: getSub(req),
      }
    });
    if (result.docs.length === 0) {
      res.status(404).send({ message: 'Document not found' });
      return;
    }
    const doc = result.docs[0];

    // remove the COS object
    console.log(`Removing file ${doc.userId}/${doc._id}/${doc.name}`);
    await cos.deleteObject({
      Bucket: COS_BUCKET_NAME,
      Key: `${doc.userId}/${doc._id}/${doc.name}`
    }).promise();

    // remove the cloudant object
    await db.destroy(doc._id, doc._rev);

    console.log(`[OK] Successfully deleted ${doc._id}`);
    res.status(204).send();
  } catch (err) {
    res.status(500).send(err);
  }
});

// Called by App ID when the authorization flow completes
app.get('/appid_callback', function (req, res) {
  res.send('OK');
});

app.get('/api/tokens', function (req, res) {
  res.send(req.appIdAuthorizationContext);
});

app.get('/api/user', function(req, res) {
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

const server = app.listen(process.env.PORT || 8081, () => {
  console.log(`Listening on port http://0.0.0.0:${server.address().port}`);
});
