FROM node

WORKDIR /app

RUN npm install -g nodemon
ADD package.json /app/package.json
RUN npm config set registry http://registry.npmjs.org
RUN npm install && npm ls
RUN mv /app/node_modules /node_modules
RUN sed  -i "1i \\'use strict\\';" /usr/local/lib/node_modules/nodemon/lib/monitor/run.js
ADD . /app

ENV PORT 80
EXPOSE 80

CMD ["node", "server.js"]
