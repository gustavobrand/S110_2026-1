FROM node
RUN npm install -g phantomjs
COPY . /app
WORKDIR /app
CMD ["/app/tests.sh"]
