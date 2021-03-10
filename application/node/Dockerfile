# documentation https://nodejs.org/en/docs/guides/nodejs-docker-webapp/

# most recent node (security patches) and alpine (minimal, adds to security, possible libc issues)
FROM node:15.7-alpine 

# labels to add metadata
LABEL version="1.0" maintainer="Fernando Duran <duran.fernando@gmail.com>"

# Create app directory & copy app files
WORKDIR /usr/src/app

# we copy first package.json only, so we take advantage of cached Docker layers
COPY ../api/package*.json ./

# RUN npm ci --only=production
RUN npm install

# Copy app source
COPY ../api/* .

# port used by this app
EXPOSE 8080

# command to run
CMD [ "node", "server.js" ]
