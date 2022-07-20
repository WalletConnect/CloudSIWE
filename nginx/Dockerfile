FROM nginx:1.23.0

ENV NGINX_ENVSUBST_OUTPUT_DIR=/etc/nginx
ENV NGINX_ENVSUBST_TEMPLATE_DIR=/etc/nginx/templates

RUN rm /usr/share/nginx/html/*

COPY /conf-templates /etc/nginx/templates
