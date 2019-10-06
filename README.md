# name-contests 


## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. 


### Prerequisites

- To deploy the app you need to install docker ,docker-compose

- add new record in /etc/hosts "127.0.0.1       yourapp.com"


### Installing

To get the app running

```
git clone https://github.com/Eslamanwar/name-contests.git
docker-compose up -d --force-recreate
```

### Testing
- open https://yourapp.com/graphql   
or 
- locally http://localhost:3000/graphql

### Uninstalling
To uninstal the app with delete all network and volumes and docker images
```
sudo docker-compose down
sudo docker-compose stop
sudo docker-compose rm -f
sudo docker-compose kill
sudo docker network prune
sudo docker volume prune
sudo docker rmi eslamanwar/name-contests:latest
```



# CI/CD
## Containerize NodeJS project
- I use docker for containerization
- created dockerfile
```
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
CMD dockerize -wait tcp://mongodb:27017 -wait tcp://postgres:5432 yarn start
```
- dockerize is used to Make sure services will start in the right order the nodejs app will start after mongodb and postgres DB


## Create a CI/CD pipeline with CircleCI
- create file .circleci/config.yml
- add project to circleci to point to github repo
- create 3 jobs unit_test , linting_rules , dockerized_aritifact 
- with sequentail workflows (first run unit_test and then  linting_rules and then dockerized_aritifact)   
- Merges to master branch generate a docker image and pushed to my docker-hub repo


```
version: 2
jobs: 
  unit_test: 
    docker:
      - image: circleci/node:10.16.3
        environment:
          NODE_ENV: development
          PGUSER: root 
          PGHOST: 127.0.0.1
      - image: circleci/mongo:4
        environment:
          MONGO_INITDB_DATABASE: contests      
      - image: circleci/postgres:10.3-alpine
        environment:
          POSTGRES_DB: contests
          POSTGRES_USER: root
          TEST_DATABASE_URL: postgresql://root@localhost/contests
    working_directory: ~/repo           
    steps:
      - checkout
      - run:
          name: install postgresql client to run sql script
          command: sudo apt install -y postgresql-client || true
      - run:
          name: Waiting for PostgreSQL to start
          command: |
            for i in `seq 1 10`;
            do
              nc -z localhost 5432 && echo Success && exit 0
              echo -n .
              sleep 2
            done
            echo Failed waiting for Postgres && exit 1
      - run:
          name: Wait for Mongo to start
          # preinstalled in circleci/* docker image
          command: dockerize -wait tcp://127.0.0.1:27017 -timeout 120s
      - run:
          name: install dependencies
          command: yarn install --no-cache --frozen-lockfile   
      - run:
          name: load data into Mongodb database
          command: node database/loadTestMongoData.js
      - run:
          name: load data into Postgre database
          command: psql -U root -d contests -a -f database/test-pg-data.sql
      - run: 
          yarn test
          
  linting_rules:
    docker:
      - image: circleci/node:10.16.3
    working_directory: ~/repo 
    steps:
      - checkout
      - run:
          name: install dependencies
          command: yarn install --no-cache --frozen-lockfile 
      - run:
          name: check all linting rules 
          command: ./node_modules/.bin/eslint ./lib/index.js  
  dockerized_aritifact:
    docker:
      - image: circleci/node:10.16.3
    working_directory: ~/repo 
    steps:
      - checkout
      - setup_remote_docker:   
          docker_layer_caching: true                  
      - run:
          name: login to docker hub
          command: echo "$DOCKER_PASS" | docker login --username $DOCKER_USER --password-stdin   
      - run: |
          TAG=0.1.$CIRCLE_BUILD_NUM
          docker build -t eslamanwar/name-contests:$TAG -t eslamanwar/name-contests:latest .
          docker push eslamanwar/name-contests:$TAG
          docker push eslamanwar/name-contests:latest
workflows:
  version: 2
  build:
    jobs:
      - unit_test:
          filters:
            branches:
              only:
                - master    
      - linting_rules:
          requires:
            - unit_test      
          filters:
            branches:
              only:
                - master                
      - dockerized_aritifact:
          requires:
            - linting_rules          
          filters:
            branches:
              only:
                - master
```



# Docker-compose
- create a docker-compose.yml file
- nodejs service that contain application
- webserver service that contain nginx acts as reverse proxy to application
- mongodb service to hold Mongodb database
- postgres service to hold postgres database
- datacontainer service acts Data container for files
- seedmongo service that runs to seed data into mongodb and exit
- create volumes for each container to make sure all data is persisted


```
version: '3'

services:
  nodejs:
    image: eslamanwar/name-contests:latest
    container_name: nodejs
    restart: unless-stopped
    environment:
      NODE_ENV: production
      PORT: 3000 
      MONGO_DB: contests
      MONGO_PORT: 27017
      MONGO_HOSTNAME: mongodb
      PGHOST: postgres
      PGUSER: user
      PGDATABASE: contests
      PGPASSWORD: pass
      PGPORT: 5432 
    ports:
      - "3000:3000"
    volumes:
      - .:/home/node/app
      - node_modules:/home/node/app/node_modules
    links:
      - mongodb
      - postgres        
    depends_on:
      - mongodb       
      - postgres        
    networks:
      - app-network

  
  webserver:
    image: nginx:alpine
    container_name: webserver
    restart: unless-stopped
    tty: true
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./nginx/yourapp.com.crt:/etc/nginx/yourapp.com.crt 
      - ./nginx/yourapp.com.key:/etc/nginx/yourapp.com.key
      - ./nginx/dhparam4096.pem:/etc/nginx/dhparam4096.pem        
    ports:
      - 80:80
      - 443:443   
    networks:
      - app-network

        
  seedmongo:
    image: eslamanwar/name-contests:latest
    environment:
      NODE_ENV: production
    deploy:
      restart_policy:
        condition: none
    container_name: seedmongo
    command: node database/loadTestMongoData.js    
    links:
      - mongodb
    networks:
      - app-network        

  mongodb:
    image: mongo:4
    container_name: mongodb
    restart: unless-stopped
    env_file: .env
    volumes:     
      - mongodbdata:/data/db
    networks:
      - app-network  

  postgres:
    image: postgres:10.4
    ports:
      - "35432:5432"
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass            
      POSTGRES_DB: contests
    volumes:
      - postgresdata:/var/lib/postgresql/data    
      - ./database:/docker-entrypoint-initdb.d/  
    networks:
      - app-network        

  datacontainer:
    image: busybox
    volumes:
      - datacontainer:/data    
    networks:
      - app-network
    command: /bin/echo

networks:
  app-network:
    driver: bridge

volumes:
  mongodbdata:
  node_modules:
  postgresdata:        
  datacontainer:
```


## Nginx custom configuration
- create nginx.conf file to hold nginx configuration
- Enable HTTPS
```
listen 443 ssl;
```
- redirect HTTP to HTTPS (in port 80 Block)
```
        location / {
            return 301 https://$host$request_uri;
        }  
```

- Create a self-signed certificate 
```
# create 4096 long RSA key names ca.key 
openssl genrsa -out ca.key 4096


# create root CA using the generated key. Enter following line and provide information for your root CA that may be asked.
openssl req -new -x509 -days 1826 -key ca.key -out ca.crt 


# create RSA key for subordinate
openssl genrsa -out yourapp.com.key 4096   

# generate CSR 
openssl req -new -key yourapp.com.key -out yourapp.com.csr


# generate certificate
openssl x509 -req -days 730 -in yourapp.com.csr -CA ca.crt -CAkey ca.key -set_serial 01 -out yourapp.com.crt
```
- use certificate
```
# ssl certificate
ssl_certificate     /etc/nginx/yourapp.com.crt;
ssl_certificate_key /etc/nginx/yourapp.com.key;
```

- Use TLS only
```
ssl_protocols TLSv1.2;
```

- Use strong ciphers only
```
ssl_prefer_server_ciphers on;
ssl_ciphers         EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH;
```

- Generate a DH key witj length 4096
```
openssl genpkey -genparam -algorithm DH -out ./nginx/dhparam4096.pem -pkeyopt dh_paramgen_prime_len:4096
```

- enable dhparam
```
ssl_dhparam         /etc/nginx/dhparam4096.pem;
```


- Enable HSTS
```
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
```

- Enable OCSP Stapling 
```
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4;
```

Because we are using a self-signed certificate, the SSL stapling will not be used. Nginx will simply output a warning, disable stapling for our self-signed cert, and continue to operate correctly.

- Enable Nginx Microcaching (see Cache section in nginx.conf file below)



- deny access to important files and folders
```
        location /dirdeny {
                deny all;
                return 403;
        }
```
## nginx.conf configuration

```
worker_processes 1;
 
events { worker_connections 1024; }
 
http {
 
    sendfile on;
 
 
    upstream docker-nodejs {
        server nodejs:3000;
    }
 

    server {
        listen 80;
        server_name yourapp.com;
        
        # redirect HTTP to HTTPS
        location / {
            return 301 https://$host$request_uri;
        }   
    }


  # Set cache dir
  proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=microcache:5m max_size=1000m;


    server {
        # Enable HTTPS
        listen 443 ssl;

        # Enable HSTS
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

        server_name yourapp.com;
       
        # Use TLS only 
        ssl_protocols TLSv1.2;

        # ssl certificate
        ssl_certificate     /etc/nginx/yourapp.com.crt;
        ssl_certificate_key /etc/nginx/yourapp.com.key;

        # Use strong ciphers
        ssl_prefer_server_ciphers on;
        ssl_ciphers         EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH;

        # enable dhparam 
        # to Generate a DH key $ openssl genpkey -genparam -algorithm DH -out ./nginx/dhparam4096.pem -pkeyopt dh_paramgen_prime_len:4096
        ssl_dhparam         /etc/nginx/dhparam4096.pem;
  
        # Enable OCSP Stapling
        ssl_stapling on;
        ssl_stapling_verify on;
        resolver 8.8.8.8 8.8.4.4;

        location / {
            proxy_pass         http://docker-nodejs;
            proxy_redirect     off;
            proxy_set_header   Host $host;
            proxy_set_header   X-Real-IP $remote_addr;
            proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header   X-Forwarded-Host $server_name;



            ##########Cache section############3
            # Setup var defaults
            set $no_cache "";
        
            # Disable caching fot admin area
            if ($request_uri ~* "/admin/") {
                set $no_cache "1";
            }
        

            # Disable caching for  logged in users based on http_cookie
            if ($http_cookie ~* "logged_in") {
                set $no_cache "1";
            }

            # If non GET/HEAD, don't cache & mark user as uncacheable for 1 second via cookie
            if ($request_method !~ ^(GET|HEAD)$) {
                set $no_cache "1";
            }


            # Bypass cache if flag is set
            proxy_no_cache $no_cache;
            proxy_cache_bypass $no_cache;

            # Set cache zone
            proxy_cache microcache;

            # Set cache key to include identifying components
            proxy_cache_key $scheme$host$request_method$request_uri;

            # Only cache valid HTTP 200 responses for 1 second
            proxy_cache_valid 200 1s;

            # Serve from cache if currently refreshing
            proxy_cache_use_stale updating;

            # Set files larger than 1M to stream rather than cache
            proxy_max_temp_file_size 1M;

        }



        # Deny access to important files
        location /dirdeny {
                deny all;
                return 403;
        }


    }
}

```




## To Do
- Enhance network between containers in docker-compose 


### GraphQL deep dive

Run `yarn start:dev` to test

Use `yarn start` in production setting

### Sample query and mutation
```

query MyContests {
  me(key: "0000") {
    id
    email
    fullName
    contestsCount
    namesCount
    votesCount
    contests {
      id
      title
      code
      status
      description
      createdAt
      names {
        label
        createdBy {
          fullName
        }
      }
    
    }
    activities {
      ... on ContestType {
        header: title
      }
      ... on Name {
        header: label
			}
    }
  }
}

mutation AddNewContest($input: ContestInput!) {
  AddContest(input: $input) {
    id
    code
    status
    description
  }
} 

```

