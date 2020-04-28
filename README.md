# Financial Exchange System (Finex)

This is a simple stock exchange application system used to experiment with software architecture styles. The current version uses a distributed microservices architecture with deployment on AWS. The stock exchange application itself provides APIs to place orders which are then matched using an orderbook implementation using simple price-time order matching. Additionally it has APIs to retrieve products available for trade, to view matched trades, and to retrieve orders. 

The distributed services of the system are individual Spring Boot applications. Together the services form an API-based system with API in the form of web services. The API is categorized into internal and external API. The internal API follow the path convention is `/finex/internal/api/domain`, and external API follows the path convention `/finex/api/domain`. The objective of the internal vs external API is to make external API potentially avaiable on the public Internet whereas the internal API is available only within the organization. The external API consists of capabilities such as placing and order whereas internal API consists of capabilities such as product maintenance.

The services in the system use PostgreSQL for persistence. While an ideal microservices architecture calls for each service having its own decoupled persistence storage, the simplicity of the data model led to use of single PostgreSQL schema used by all services. The business data model itself provides significant isolation, and the service implementations themselves only query and update only those database tables that are directly applicable to the service. So while there is no forced isolation by means of decoupled schemas or even decoupled database instances, the service implementations practice the decoupled storage use.

In addition to the application services, the system has Spring Cloud implementation for configuration service. See https://spring.io/projects/spring-cloud-config for details about Spring Cloud Config. The application services retrieve their application parameters from the configuration service. The application parameters may be different, for example, depending on the type of deployment such as local or AWS or any other mode of operation. The Spring Cloud configuration service, in turn, fetches the configurations from designated git repository on behalf of the requesting Application Service. The git repository should contain `.yml` files for each application and its mode of operation. The mode of operation is determined by the spring profile setting in each application.

The application services and configuration service are dockerized. Each docker image can be run in a docker container where the docker containers can be launched on a single bare-metal hardware, single VM, or multiple VMs. The objective of this implementation is to deploy each service in a dedicated AWS t3.micro EC2 instance. The AWS deployment is supplemented with couple of application load balancers for routing API requests. One internal load balancer for internal API and one internet-facing load balancer for external API. The `/financial-exchange-env` contains the necessary AWS Cloudformation configuration files and bash scripts that automate the maven and docker builds of the services as well as deployment of necessary infrastructure in AWS.

The diagram below gives a complete picture of all that is involved in this repo.

![Finex Complete Picture](https://github.com/hthakkar275/finexv1/blob/master/financial-exchange-docs/finex-complete-picture.png "Complete Picture")

Now that the system is described at a high-level, please refer to the subsequent sections for details information.

# Service Level Architecture View

The financial exchange employs a microservices architecture with independent services interacting with one another to provide a full order management system with a price-time priority orderbook. The figure below shows a high level view of the service level architecture. The services can be categorized into three types.

1. Application Services
2. Configuration Service
3. Info Service

![Application Services](https://github.com/hthakkar275/finexv1/blob/master/financial-exchange-docs/ApplicaitonServicesView.png "Application Services")

Each service is a Java Spring Boot application. The table below identifies the location of the source code for each service within this repository.

| Service               | Repository Location                                                 |
| --------------------- | ------------------------------------------------------------------- |
| Info Service          | [financial-exchange-info](financial-exchange-info)                  |
| Config Service        | [financial-exchange-config](financial-exchange-config)              |
| Product Service       | [financial-exchange-product](financial-exchange-product)            |
| Participant Service   | [financial-exchange-participant](financial-exchange-participant)    |
| Order Service         | [financial-exchange-order](financial-exchange-order)                |
| Orderbook Service     | [financial-exchange-orderbook](financial-exchange-orderbook)        |
| Trade Service         | [financial-exchange-trade](financial-exchange-trade)                |

## Configuration Service

Configuration Service (CS) is not only a Java Spring Boot application, but also a Spring Cloud Config Server. It contains no dedicated application code. Instead it relies entirely on the the out-of-the-box Spring Cloud Config Server implementation. It uses a git repository as the source of configuration files to serve to the Application Services (AS). The git repository information such as git URI and git credentials are supplied to the docker build process for the CS. As such the git configuration repository details are pre-packaged into the docker image and ready to run when docker image is run in a docker container. The excerpt from the [Configuration Service Dockerfile](financial-exchange-config/dockerfile.configserver) show how the git details are passed into the docker build which are then exported as environment variable in the docker image.

```Dockerfile
ARG GIT_URI_ARG
ARG GIT_USER_ARG
ARG GIT_PASSWORD_ARG

ENV GIT_URI $GIT_URI_ARG
ENV GIT_USER $GIT_USER_ARG
ENV GIT_PASSWORD $GIT_PASSWORD_ARG
```

Then the docker build command is issued as follows to "bake" the git repo detais into the docker image.

```bash
# Supply appropriate --build-arg values for the 
# GIT_URI_ARG, GIT_USER_ARG, and GIT_PASSWORD_ARG

docker build -f dockerfile.configserver \
--build-arg GIT_URI_ARG=https://github.com/githubUser/configuraiton.git \
--build-arg GIT_USER_ARG=githubUser \
--build-arg GIT_PASSWORD=password \
-t dockerUser/finex-config-user .
```

Thea Spring Boot application.yml references the environment variables for git repository details.  

```yaml
spring:
  application:
    name: finex-config
  cloud:
    config:
      server:
        git:
          uri: ${git_uri}
          force-pull: true
          username: ${git_user}
          password: ${git_password}
server:
  port: 8888
```

## Application Services

The Application Services implement the business logic of the financial exchange system. Each Application Service is a Spring Boot application. Application Services depend on persistence of multiple domain object types.

* Equity (i.e. Product)
* Broker (i.e. Participant)
* Orders
* Trade

Market participants (i.e. Brokers) place a buy and sell Orders on a variety of products (i.e. Equity). The orders are matched by in an orderbook which implements price-time-priority algorithm. Matched orders are represented in trades.

All capabilities are supported via API offered by all services. The Application Services provide an internal API an an external API. The internal API follows the path pattern `/finex/internal/`, and it is intended for use by inter-service communication and for internal users to manage activities such as product and participant create, delete and updates. The external API follows the path pattern `/finex/external/`, and it is intended to be available to external users.

The Application Services are self-explanatory from the name itself, but the list below gives a brief overview of each service.

### Product Service

* Provides operations to manage financial instrument products data. Currently only supported product is Equity.
* Create, update and delete operations are available via the internal API.
* Retrieve operation is available via internal and external API.

### Participant Service

* Provides operations to manage market participants data. Currently only supported participant is Broker.
* Create, update and delete operations are available via the internal API.
* Retrieve operation is available via internal and external API.

### Order Service

* Provides order management operations.
* Add new order, update or cancel existing orders, or get order status via external API.
* Orderbook Service updates the order state (i.e. booked, filled) via internal API 

### Orderbook Service

* Price-time-priority orderbook for each product
* Order Service uses internal API to apply new and updated orders to the orderbook via internal API
* Does not offer external API

### Trade Service

* Provides operations to manage trades in the database.
* Orderbook Services adds new trades via internal API
* External users can query trade details via external API

Each service employs nearly identical structural architectural pattern with differences being in the business logic or business domain objects.

![Application Services Architecture](https://github.com/hthakkar275/finexv1/blob/master/financial-exchange-docs/IndividualApplicationSerivceStructure.png "Application Services Architecture")

Each Application Service has a `bootstrap.yml` that configures it with the Spring profile and the URI for the Configuration Service. Both values are taken directly from environment variables "baked-in" to the docker image during docker build. The active profile and Configuration Service URI are used during application startup to retrieve the full configuration for the application. Below is an example of a `bootstrap.yml` file in Order Service.

```yaml
spring:
  application:
    name: fienx-order
  profiles:
    active: ${spring_profiles}
  cloud:
    config:
      uri: ${config_server_uri}
      label: master
```

## PostgreSQL Database

There is a single database instance and single database schema for all services. Ideal microservices architecture should employ a dedicated database schema, but the simplicity of the data model and its inherent clean boundaries makes having separate schemas unwarranted. That said, it is just as easy to create separate schema without much departure from the overall architecture of the system. The [finexschema.sql](financial-exchange-env/finexschema.sql) contains the DDL for the data model shown below.

![Data Model](https://github.com/hthakkar275/finexv1/blob/master/financial-exchange-docs/DataModel.png "Data Model")

## Load Balancers

The architecture employs use of two AWS Application Load Balancers. 

* Internal load balancer for internal API via path pattern `/finex/internal/api`
* Internet-facing load balancer for external API via path pattern `/finex/api`

Actually the internal load balancer is configured to route both internal and external API, however the external API exposed through the internal load balancer is not visible to the public. The external API available in the internal load balancer for internal organization users to avoid having to route the calls through the DNS. The primary objective of the internal load balancer, however, is to make support inter-service communication. The Application Service instances and the internal load balancer together form a service mesh.

The internet-facing load balancer is configure to route only external API traffic adhering to the path pattern `finex/api`. External users API traffic is routed through the internet-facing load balancer via Route 53 DNS.

Although the internal and internet-facing load balancers described here are provisioned and tested on AWS platform, the same could be implemented on any cloud or on-prem configuration.

# Deployment

The system deployment has been tested on two deployment configurations.

* localhost
* AWS

## Localhost Deployment

The primary objective of the localhost deployment is for rapid unit test of the business logic of the system. It involves running all Application Services, Configuration Service, and the PostgreSQL database on a single machine. Every service and the PostgreSQL database was run as a docker container. Since all services are running on the same machine, each service has to expose its API on different TCP port. Obviously there are no load balancers deployed in the localhost configuration.

Note that there is no need for code change in any of the services. Simply deploy the applications with `localhost` profile as the active Spring profile and make corresponding Spring configuration files available in the git configuration repository. For example by having the spring profile set to `localhost` on `finex-product` service, the `finex-product` service will request its properties file titled `finex-product-localhost.yml` from the Configuration Service. The `finex-product-localhost.yml` should have the appropriate server listen port as well as database URI. 

## AWS Deployment

Similar to the `localhost` configuration the application properties for each service is configured with the combination of spring profile named `aws` and the matching `finex-xxxxx-aws.yml` in the configuration git repository where `xxxxx` is the service name.

The AWS deployment architecture is shown in the figure below. Each Application Service and Configuration Service run in a dedicated t2.micro EC2 instance. 

![AWS Deployment](https://github.com/hthakkar275/finexv1/blob/master/financial-exchange-docs/finex-aws.png "AWS Deployment")

The [financial-exchange-env](financial-exchange-env) directory contains several AWS Cloudformation stack JSON configuration files and shell scripts that stand up the entire deployment from setting up VPC with all the requisite subnets and security groups as well as deploying all services and the load balancers. The figure below shows the relationship between the shell scripts, Cloudformation files, and the maven/docker builds. Note that to minimize cost and to attempt to run in the AWS free tier as much as possible, the EC2 instances are launced in only one of the two availability zone. Hence the Cloudformation files are shown only for zone1. It's just as easy to replicate the zone2 cloud formation from the zone1 Cloudformation files.

![Build & Deployment](https://github.com/hthakkar275/finexv1/blob/master/financial-exchange-docs/finex-aws.png "Build & Deployment")

The build & deployment process is mostly automated except for the manual creation of PostgreSQL RDS in AWS. There are two possible scenarios to use the build & deployment scripts and Cloudformation.

* Fresh Installation 
* Rebuild & Deploy Services

Either scenario is triggered from the main entry point using the shell script [finex-build-main.sh](financial-exchange-env/finex-build-main.sh). The Rebuild & Deploy Services scenario is just a subset of the Fresh Installation Scenario.

The section below describes the procedure to do the full fresh installation as if this architecture had never been deployed in AWS. The fresh installation scenario will appear laborious and tedious due to the one-time procedures for initial workspace preparation and PostgreSQL deployment in Amazon RDS, but the routine updates after the fresh install only requires the rebuild & deploy of services which are fully automated with single command to run the `finex-main-build.sh`. Suppose, for example, after the initial fresh installation there is a new feature added in finex. Deploy of this new feature requires to rebuild the java applications, creating docker images and deploying the new images in AWS. All that could be performed with the Rebuild & Deploy Services scenario. Another useful aspect of the separation of the Rebuild & Deploy Services is the cost in AWS. Most everyone who will use this system will do so for experimental purposes. As such there is not an expectation to leave all EC2 instances and the load balancers running. Instead one will deploy the services and the load balancer for the duration of couple of hours. In that case the Cloudformation stacks for the services and the load balancers can be deleted and resurrected with the Rebuild & Deploy Service scenario when needed again while leaving the VPC stack running. The VPC stack as implemented here incurs minimal, if any, cost in AWS free tier.

### Using the Build Scripts to Deploy Fresh Installation to AWS

There are three steps necessary for full fresh installation. Two of the three steps (which are the most tedious and error-prone) are fully automated with shell script and AWS Cloudformation.

1. Prepare the working space
2. Automated build of the VPC 
3. Manual build of PostgreSQL RDS and creation of `finex` database schema
4. Create database tables in `finex` schema
5. Automated build of services. This includes
   1. Maven build of the java applications
   2. Docker build and push to Docker Hub
   3. AWS stacks for NAT Gateway, EC2, Load Balancers and DNS

Each of the two automated builds are invoked using the `finex-build-main.sh`. This main script has self-explanatory usage documentation that one can invoke with a `-h` option or simply execute the script without any options. The information in the usage/help document is adequate so it is not repeated here.

#### Prepare Working Space

In order to execute the automated build steps, the following prerequisite conditions must be available

1.  Clone this git repository so that all source code and build scripts are available locally. Note that in the future this step could also be automated in the build script, but for now the git clone of this repository is to be manually performed.
2.  Create a Docker Hub account, if you don't already have one. The docker images for the Application Services and Configuration Service will be pushed to this repository.
3.  Create a git repository for the Application Services configuration files. Use https://github.com/hthakkar275/finexv1-config as reference. If you create this repository in GitHub, you may want to make it a private repository as it will contain details specific to your own deployment configuration. The Configuration Service docker build will require the details of this git repository as described above in the Configuration Service section.
4.  Create an AWS account, if you don't already have one.
5.  Create an AWS key-pair in the AWS region where you wish to deploy finex.

#### Automated VPC Build

1. Change to directory `financial-exchange-env` in your local git repository where you cloned https://github.com/hthakkar275/finexv1.
2.  Run the `finex-build-main.sh` as shown below to build out the VPC in your desired AWS region. 

```console
finex-build-main.sh -b vpc -r <aws region name> -c <absolute path to financial-exchange-env  in your local git clone of https://github.com/hthakkar275/finexv1>
```
3. The shell script will take few minutes to build the VPC stack in AWS. You can monitor the output from the `finex-build-main.sh` to track the progress. The progress can also be tracked in the AWS Cloudformation console.

#### Manual PostgreSQL Deployment

Create a new PostgreSQL instance in AWS RDS console. Use the following values. Use default values for parameters not listed below.

1. Navigate to the RDS on AWS console. 
2. Proceed to create a new database instance with parameters shown below. The parameters below are just a suggestion to keep the RDS usage within the AWS free tier. The names of VPC and Security Group are those that were created in the Automated VPC Build step.

| Parameter                             | Value                                               |
| ------------------------------------- | --------------------------------------------------- |
| Create Database                       | Standard Create                                     |
| Engine Option                         | Choose latest stable release of PostgreSQL          |
| Templates                             | Free Tier                                           |
| DB Instance Identifier                | finex-database                                      |
| Credentials                           | Choose appropriate username and password            |
| DB Instance Size                      | db.t2.micro                                         |
| Storage Type                          | General Purpose SSD                                 |
| Allocated Storage                     | 20 GiB                                              |
| Enable storage autoscaling            | Disabled                                            |
| Connectivity                          | FinexVpc                                            |
| Publicly accessible                   | No                                                  |
| VPC Security Groups                   | Remove the Default security. Add FinexDbSg, FinexAppSg, FinexPubSg          |
| Availability Zone                     | Choose zone A                                       |
| Initial database name                 | finex                                               |
| Automatic backup                      | Disable                                             |
| Performance insights                  | Disable                                             |
| Enhanced Monitoring                   | Disable                                             |
| Log Exports                           | Disable                                             |
| Auto minor versiong upgrade           | Disable                                             |
| Maintenance window                    | Select date and time appropriate for you            |
| Delete protection                     | Disable                                             |

3. Once the database is available, create the database tables to support the finex data model as shown in the next section
4. Record the database address which will have the form `finex-database.xxxxxxxxx.us-east-2.rds.amazonaws.com/finex`. This will need to be added to the database configuration parameter in the application yaml files in the configuration repository. Example shown below

```yaml
spring: 
  application:
    name: finex-order
  datasource:
    url: jdbc:postgresql://finex-database.xxxxxxxxx.us-east-2.rds.amazonaws.com/finex
    username: myuser
    password: mypassword
```

#### DDL for `finex` Schema 

1. Launch an Amazon Linux AMI EC2 instance in FinexPubSubnetZone1 with security group FinexPubSg. Note that the names FinexPubSubnetZone1 and FinexPubSg are the names of the public subnet and security group, respectively, created in the VPC build step. Supply the following UserData when launching the EC2 instance to install a PostgreSQL client. This EC2 instance will also serve as a DMZ zone to allow you to SSH and troubleshoot areas that are not visible to public Internet such as the EC2 instances deployed in the private subnets.

```bash
yum update -y
yum install gcc -y
yum install python-pip -y
yum install postgresql-devel python-devel -y
pip install pgcli==2.2.0
```
2. SSH into the EC2 instance once it is available.
3. SFTP the [finexschema.sql](financial-exchange-env/finexschema.sql) to EC2
4. Connect to the finex schema in the PostgreSQL database created in the previous step. Example shown below. Get the PostgreSQL URL from the AWS RDS console.

```bash
pgcli postgres://username:password@finex-database.xxxxxxxxx.us-east-2.rds.amazonaws.com/finex
```
5. Load the `finexschema.sql` file into pgcli which will automatically run all DDL commands.

#### Automated Services Build

1. Change to directory `financial-exchange-env` in your local git repository where you cloned https://github.com/hthakkar275/finexv1.
2.  Run the `finex-build-main.sh` as shown below to build out the VPC in your desired AWS region. Note that the `-d` and `-f` are optional. These two optional argument allow you to create a DNS record in AWS Route 53 for your publicly registered domain to the external API available via the internet-facing load balancer. If you don't have a publicly registered domain name or do not wish to create a public DNS record, you may omit the `-d` and `-f` options.

```console
finex-build-main.sh -b services -r <aws region name> -c <absolute path to financial-exchange-env in your local git clone of https://github.com/hthakkar275/finexv1> -s <absolute path to parent directory of your local git repository> -g <URI of the configuration git repository> -u <git username of configuration git repository> -p <git password of configuraiton git repository> -k <AWS key-pair name> -i <Docker Hub username> -d <route 53 hosted zone id> -f <publicly registerd url>
```
3. The shell script will take upwards of 30 to 45 minutes to perform all maven builds, docker builds, docker push and create AWS infrastructure. You can monitor the output from the `finex-build-main.sh` to track the progress. The progress can also be tracked in the AWS Cloudformation console.

# Future Directions

This is just one of the many possible choice of architecture employing microservices. The objective is to explore other architecture styles and compare the benefits and drawbacks. Additionally there are certain aspects in the feature set of finex application itself that can be enhanced or improved. That said the following is a rough prioritized backlog of epics to address in the future.

1. Employ Spring Zuul with auto-discovery to remove the use of AWS load balancer for inter-service communication. This will eliminate the need to "hard-code" Configuration Service IP address and the internal load-balancer DNS in the docker images of Application Services.
2. Use Istio service mesh which would be an alternative to Spring Zuul and the Spring Cloud Configuration Server
3. Event-drive architecture for inter-service communication. This would be yet another alternative or a supplement to Spring Zuul or Istio
4. Provide push notifications to clients for trades
5. API improvement
6. Securing the finex API
7. Use of of CI/CD tools such as Jenkins 
8. Performance analysis & improvement



