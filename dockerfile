FROM node:8.16.1-alpine


# Set a working directory
WORKDIR /usr/src/app


# Install Node.js dependencies
COPY package.json yarn.lock ./

# Install dependencies
RUN yarn install --no-cache --frozen-lockfile

# copy the nodejs app
COPY . /usr/src/app

# expose port 3000 for external
EXPOSE 3000

# start the app
CMD ["yarn", "start"]
