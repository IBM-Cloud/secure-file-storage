FROM node:20
ENV NODE_ENV production

# updates to fix vulnerabilities
RUN apt-get update; \
  apt-get install -yy libgnutls30; \
  apt-get remove -yy libtiff-dev libde265-0 libnghttp2-14 perl; \
  apt-get clean

# put app in /usr/src/app
WORKDIR /usr/src/app
COPY . .
RUN npm install --production --silent
EXPOSE 8081
CMD npm start