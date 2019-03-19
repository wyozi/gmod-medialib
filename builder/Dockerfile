FROM node:alpine

RUN apk add --no-cache git 

RUN mkdir /builder
COPY build.js /builder
COPY package.json /builder
RUN cd /builder && npm install

CMD [ "sh", "-c", "node /builder/build.js --no-git build"]