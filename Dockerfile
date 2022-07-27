FROM node:16.16.0-alpine3.16

RUN mkdir -p /usr/src/botalyzer
WORKDIR /usr/src/botalyzer

RUN apk update && apk upgrade && apk add curl python3

COPY . /usr/src/botalyzer/

RUN npm install && npm run build

EXPOSE 3000

CMD [ "npm", "run", "start" ]
