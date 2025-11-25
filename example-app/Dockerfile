FROM nginx:alpine

# Копируем наш HTML файл
COPY src/index.html /usr/share/nginx/html/index.html

# Nginx конфигурация (опционально)
# COPY nginx.conf /etc/nginx/nginx.conf

# Экспонируем порт 80
EXPOSE 80

# Nginx запускается автоматически в базовом образе
CMD ["nginx", "-g", "daemon off;"]
