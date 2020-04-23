# Financial Exchange System (Finex)

This is a simple stock exchange application system used to experiment with software architeture styles. The current version uses a distributed mircroservices arechitecture with deployment on AWS. The stock exchange application itself provides APIs to place orders which are then matched using an orderbook implementation using simple price-time order matching. Additionally it has APIs to retriev products available for trade, to view matched trades, and to retrieve orders. 

The distributed services of the system are individual Spring Boot applications. Together the services form an API-based system with API in the form of web services. The API is categorized into internal and external API. The internal API follow the path convention is `/finex/internal/api/domain`, and external API follows the path convention `/finex/api/domain`. The objective of the internal vs external API is to make external API potentially avaiable on the public Internet whereas the internal API is available only within the organization. The external API consists of capabilities such as placing and order whereas internal API consits of capabilities such as product maintanenance.

The services in the system use PostgreSQL for persistence. While an ideal microservices architecture calls for each service having its own decoupled persistence storage, the simplicity of the data model led to use of single PostgreSQL schema used by all services. The business data model itself provides signficant isolation, and the service implementations themselves only query and update only those database tables that are directly applicable to the service. So while there is no forced isolation by means of decoupled schemas or even decoupled database instances, the service implementations practice the decoupled storage use.

In addition to the application services, the system has Spring Cloud implementation for configuration service. See https://spring.io/projects/spring-cloud-config for details about Spring Cloud Config. The application services retrieve their application parameters from the configuration service. The application parameters may be different, for example, depending on the type of deployment such as local or AWS or any other mode of operation. The Spring Cloud configuration service, in turn, fetches the configurations from designated git repository on behalf of the requesting applicaiton service. The git repository should contain `.yml` files for each application and its mode of operation. The mode of operation is determined by the spring profile setting in each application.

The application services and configuration service are dockerized. Each docker image can be run in a docker container where the docker containers can be launced on a single bare-metal hardware, single VM, or multiple VMs. The objective of this impelementation is to deploy each service in a dedicated AWS t3.micro EC2 instance. The AWS deployment is supplemented with couple of application load balancers for routing API requests. One internal load balancer for internal API and one internet-facing load balancer for external API. The `/financial-exchange-env` contains the necessary AWS cloudformation configuration files and bash scripts that automate the maven and docker builds of the services as well as deployment of necessary infrastructure in AWS.

The diagram below gives a complete picture of all that is involved in this repo.

![Finex Complete Picture](https://github.com/hthakkar275/finex/blob/ht-0402/financial-exchange-docs/finex-complete-picture.png "Complete Picture")

Now that the system is described at a high-level, please refer to the subsequent sections for details information.

## Service Level Architecture View

The financial exchange employs a microservices architecture with independent services interacting with one another to provide a full order management system with a price-time priority orderbook. The figure below shows a high level view of the service level architecture. The services can be categorized into three types.

1. Application Services
2. Configuration Sesrvice
3. Info Service



