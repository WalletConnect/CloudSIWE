FROM nginx:1.23.0-alpine

COPY /conf-templates /etc/nginx/templates

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
