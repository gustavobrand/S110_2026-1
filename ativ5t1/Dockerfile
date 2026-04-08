FROM alpine:latest

RUN apk add --update apache2 git
RUN rm -rf /var/cache/apk/*
# RUN rm -rf /var/www/localhost/htdocs/index.html

EXPOSE 80/tcp
ENTRYPOINT ["httpd"]
CMD ["-D", "FOREGROUND"]