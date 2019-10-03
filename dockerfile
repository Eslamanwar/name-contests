FROM node:8.16.1-alpine

ARG NODE_ENV=production
ENV NODE_ENV=$NODE_ENV

# Set a working directory
WORKDIR /usr/src/app

# Install native dependencies
# RUN set -ex; \
#   apk add --no-cache ...


# Install Node.js dependencies
COPY package.json yarn.lock ./

# For production You don't want dev dependencies in a production image, also you need to make sure that Yarn's cache folder is not bundled into the image.
# For test and CI you still want to install NPM modules via Docker builder in order to utilize Docker layer caching. 
# The next time your image is being built on a CI server, these two steps will be skipped in favor of using an existing layer, unless either package.json or yarn.lock was changed.

RUN set -ex; \
  if [ "$NODE_ENV" = "production" ]; then \
    yarn install --no-cache --frozen-lockfile --production; \
  elif [ "$NODE_ENV" = "development" ]; then \
    yarn install --no-cache --frozen-lockfile; \
  fi;


# copy the nodejs app
COPY . /usr/src/app


EXPOSE 8081


CMD ["yarn", "start"]
