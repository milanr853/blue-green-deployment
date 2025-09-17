# Dockerfile (production)
FROM node:22-alpine AS builder
WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

# Build-time variables
ARG VITE_APP_VERSION=local
ARG VITE_DEPLOYMENT_COLOR=unknown

# Expose them to npm run build
ENV VITE_APP_VERSION=${VITE_APP_VERSION}
ENV VITE_DEPLOYMENT_COLOR=${VITE_DEPLOYMENT_COLOR}

# RUN VITE_APP_VERSION=$VITE_APP_VERSION VITE_DEPLOYMENT_COLOR=$VITE_DEPLOYMENT_COLOR npm run build

# Runtime image
FROM nginx:stable-alpine
COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
