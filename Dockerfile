FROM nginx:1.27-alpine

LABEL maintainer="DevSecOps Team"
LABEL description="Tetris Game - DevSecOps CI/CD Pipeline Demo"
LABEL version="1.0"

RUN rm -rf /usr/share/nginx/html/*

COPY app/nginx.conf /etc/nginx/conf.d/default.conf

COPY app/index.html /usr/share/nginx/html/
COPY app/css/ /usr/share/nginx/html/css/
COPY app/js/ /usr/share/nginx/html/js/

RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chmod -R 755 /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    chown -R nginx:nginx /etc/nginx/conf.d && \
    touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid

USER nginx

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -qO- http://localhost/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
