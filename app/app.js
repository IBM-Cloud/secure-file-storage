// Sample app to store and access files securely 
// 
// The app provides a simple web-based service to upload, store, and access
// files. Files can be shared via an expiring file link.
// The app uses IBM Cloudant to store file metadata and IBM Cloud Object Storage
// for the actual file object.
//
// The API functions are called from client-side JavaScript


var express = require('express'),
  session=require('express-session'),
  formidable = require('formidable'),
  fs = require("fs");

const {Strategy, Issuer} = require('openid-client');

// Load environment variables from .env file
require('dotenv').config({
  path: 'credentials.env'
});
var CloudObjectStorage = require('ibm-cos-sdk');
const { IamAuthenticator } = require('ibm-cloud-sdk-core');
const { CloudantV1 } = require('@ibm-cloud/cloudant');
const passport = require('passport');

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

const APPID_OAUTH_SERVER_URL= process.env.appid_oauth_server_url;
const APPID_CLIENT_ID= process.env.appid_client_id;
const APPID_SECRET= process.env.appid_secret;
const APPID_REDIRECT_URIS=process.env.appid_redirect_uris.split(',');;

// Express setup, including session and passport support
var app = express();
app.use(session({
  secret:'keyboard cat',
  resave: true,
  saveUninitialized: true}));
app.use(passport.initialize());
app.use(passport.session());

// Configure the OIDC client
async function configureOIDC(req, res, next) {
  if (req.app.authIssuer) {
    return next();
  }
  const issuer = await Issuer.discover(APPID_OAUTH_SERVER_URL) // connect to oidc application
  const client = new issuer.Client({ // Initialize issuer information
      client_id: APPID_CLIENT_ID,
      client_secret: APPID_SECRET,
      redirect_uris: APPID_REDIRECT_URIS
  });
  const params = {
      redirect_uri: APPID_REDIRECT_URIS[0],
      scope:'openid',
      grant_type:'authorization_code',
      response_type:'code',
  }
  req.app.authIssuer = issuer;
  req.app.authClient = client;

  // Register oidc strategy with passport
  passport.use('oidc', new Strategy({ client }, (tokenset, userinfo, done) => {
    return done(null, userinfo); // return user information
  }));

  // Want to know more about the OpenID Connect provider? Uncomment the next line...
  // console.log('Discovered issuer %s %O', issuer.issuer, issuer.metadata);
  next();
}

// Initialize Cloudant
const authenticator = new IamAuthenticator({
  apikey: CLOUDANT_APIKEY
});

const cloudant = CloudantV1.newInstance({ authenticator: authenticator });
cloudant.setServiceUrl(CLOUDANT_URL);

// Initialize the COS connection.

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

// serialize and deserialize the user information
passport.serializeUser(function(user, done) {
  //console.log("Got authenticated user", JSON.stringify(user));
  done(null, {
    id: user["id"],
    name: user["name"],
    email: user["email"],
    picture: user["picture"],
  });
});

passport.deserializeUser(function(user, done) {
  done(null, user);
});

app.use(configureOIDC);

// default protected route /authtest
app.get('/authtest', (req, res, next) => {
  passport.authenticate('oidc', {
    redirect_uri: `http://${req.headers.host}/redirect_uri`,
  })(req, res, next);
});

// callback for the OpenID Connect identity provider
// in the case of an error go back to authentication
app.get('/redirect_uri', (req, res, next) => {
  passport.authenticate('oidc', {
    redirect_uri: `http://${req.headers.host}/redirect_uri`,
    successRedirect: '/',
    failureRedirect: '/authtest'
  })(req, res, next);
});


// check that the user is authenticated, else redirect
var checkAuthenticated = (req, res, next) => {
  if (req.isAuthenticated()) { 
      return next() 
  }
  res.redirect("/authtest")
}

//
// Define routes
//

// The index document already is protected
app.use('/', checkAuthenticated, express.static(__dirname + '/public'));


// Makes sure that all requests to /api are authenticated
app.use('/api/',checkAuthenticated , (req, res, next) => {
  next();
});


// Returns all files associated to the current user
app.get('/api/files', async function (req, res) {
  // filter on the userId (email)
  const selector = {
    userId: {
      '$eq': req.user.email
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
      '$eq': req.user.email,
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
    //console.log(file);
    var fileDetails = {
      name: file.originalFilename,
      type: file.type,
      size: file.size,
      createdAt: new Date(),
      userId: req.user.email,
    };

    console.log(`New file to upload: ${fileDetails.name} (${fileDetails.size} bytes)`);

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
      // delete the local file copy once uploaded
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
  // get the doc from Cloudant, ensuring it is owned by the current user
  // filter on the userId (email) AND the document ID
  const selector = {
    userId: {
      '$eq': req.user.email
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

    // remove the Cloudant object
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

// return user information
app.get('/api/user', function (req, res) {
  res.send(req.user);
});

// start the server
const server = app.listen(process.env.PORT || 8081, () => {
  console.log(APPID_REDIRECT_URIS[0]);
  console.log(`Listening on port http://localhost:${server.address().port}`);
});