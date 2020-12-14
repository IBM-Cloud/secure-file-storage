#!/bin/bash

wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc

echo "Configuring MINIO client...."
./mc config host add cos https://s3.$1.cloud-object-storage.appdomain.cloud $2 $3
./mc rm --recursive --force cos/$4