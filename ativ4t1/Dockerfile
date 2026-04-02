FROM alpine:latest

RUN apk add --update apache2 git
RUN rm -rf /var/cache/apk/*
RUN rm -rf /var/www/localhost/htdocs/index.html
RUN git clone https://github.com/s085sem201802/aula-com-docker-e-git-montando-um-ambiente-gustavobrand /var/www/localhost/htdocs
RUN mv /var/www/localhost/htdocs/inde.html /var/www/localhost/htdocs/index.html

EXPOSE 80/tcp
ENTRYPOINT ["httpd"]
CMD ["-D", "FOREGROUND"]