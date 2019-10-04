FROM node:8.16.1-alpine


# Set a working directory
WORKDIR /usr/src/app


# Install Node.js dependencies
COPY package.json yarn.lock ./

# Install dependencies
RUN yarn install --no-cache --frozen-lockfile

# copy the nodejs app
COPY . /usr/src/app

# install dockerize command utility to help Wait for other services to be available using TCP, HTTP(S)
RUN apk add --no-cache openssl
ENV DOCKERIZE_VERSION v0.6.1
RUN wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && rm dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz

# expose port 3000 for external
EXPOSE 3000

# start the app
CMD ["yarn", "start"]
