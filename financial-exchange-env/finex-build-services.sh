#!/bin/bash

# Create an AWS cloudformation stack. Accepts following arguments
# $1 is name of cloudformation json file
# $2 is AWS stack name
# $3 is optional AWS stack parameters
# Waits for the stack create operation to complete either successfully or in error.
function create_aws_stack() {

    echo "Creating $2 in AWS region $FINEX_AWS_REGION using cloudformation file $PATH_TO_CLOUDFORMAITON_FILES/$1"
    sleep 10   
    if [[ -z "$3" ]]; then
        CREATE_OUTPUT=`aws --region $FINEX_AWS_REGION cloudformation create-stack --stack-name $2 --template-body file://$PATH_TO_CLOUDFORMAITON_FILES/$1`
    else
        CREATE_OUTPUT=`aws --region $FINEX_AWS_REGION cloudformation create-stack --stack-name $2 --parameters $3 --template-body file://$PATH_TO_CLOUDFORMAITON_FILES/$1`
    fi

    if [[ "$CREATE_OUTPUT" =~ "StackId" ]]; then
        STACK_ID=`echo $CREATE_OUTPUT | tr '\n' ' ' | grep StackId | sed s/^.*StackId\"://  | tr '"' ' ' | tr -d [:space:]`
        echo "$2 creation in progress with stack-id $STACK_ID"
    else
    echo "Failed to create $2 stack"
    exit 1
    fi

    STACK_CREATED=0
    COUNTER=0
    while [ $STACK_CREATED -eq 0 ]
    do 
        sleep 30
        STACK_STATUS=`aws --region $FINEX_AWS_REGION cloudformation describe-stacks --stack-name $2 --query "Stacks[0].StackStatus" | tr '"' ' ' | tr -d [:space:]`
        if [[ "$STACK_STATUS" == "CREATE_COMPLETE" ]]; then
            echo "$2 stack creation is complete"
            STACK_CREATED=1
        elif [[ "$STACK_STATUS" == "CREATE_IN_PROGRESS" ]]; then 
            echo "$2 stack creation is in progress. Waiting for $2 stack creation to complete"
        elif [[ "$STACK_STATUS" == "CREATE_FAILED" ]]; then
            echo "$2 stack creation failed. Please investigate. Script will exit"
            exit 1
        elif [[ "$STACK_STATUS" == "ROLLBACK_IN_PROGRESS" ]];  then
            echo "$2 stack creation failed and it is being rolled back. Please investigate. Script will exit once rollback is completed"
            exit 1
        elif [[ "$STACK_STATUS" == "ROLLBACK_COMPLETE" ]];  then
            echo "$2 stack creation failed and rollback is complete. Please investigate. Script will exit"
            exit 1
        else 
            echo "f$2 stack creation status $STACK_STATUS is not one of the well recognized. Still will wait and monitor"
        fi
        (( COUNTER++ ))
        if [[ $COUNTER -ge 20 && $STACK_CREATED -eq 0 ]]; then
            echo "Giving up after 5 minutes. $2 stack is still not created. Last reported status is $STACK_STATUS. Exiting"
            exit 1
        fi
    done
}

# Collect the output values from created stack. Accepts following arguments
# $1 is AWS stack name
# $2 is OutputKey name
function get_aws_stack_output() {
    OUTPUT_VALUE=`aws --region $FINEX_AWS_REGION cloudformation describe-stacks --stack-name $1 --query "Stacks[0].Outputs[?OutputKey=='$2'].OutputValue" --output text`
    echo "$OUTPUT_VALUE"
}

# Doing maven builds on all services
# $1 Parent directory path of all services source code
function maven_build_all_services() {
    FAILED_MAVEN_BUILD_COUNT=0
    for SVC in "config" "info" "products" "participants" "orders" "orderbooks" "trades"; do
        POM_PATH=$PATH_TO_SOURCE_CODE/financial-exchange-$SVC/pom.xml
        echo "Building $SVC service ..."
        MAVEN_BUILD_STATUS=`mvn -f $POM_PATH clean package | grep BUILD | awk '{print $3}'`
        if [[ $MAVEN_BUILD_STATUS == "SUCCESS" ]]; then
            echo "$SVC service build successful"
        else 
            echo "$SVC service build failed"
            (( FAILED_MAVEN_BUILD_COUNT++ ))
        fi  
    done
    if [[ $FAILED_MAVEN_BUILD_COUNT -eq 0 ]]; then
        echo "All services built successfully. Will proceed with docker builds"
    else 
        echo "Not all services built successfully. Will not proceed with docker builds"
        exit 1
    fi
}

# Build docker image for Configuation Service and push to docker hub
# The git repo URI and credentials must be declared as environment variables
# GIT_URI, GIT_USER and GIT_PASSWORD
function docker_build_config_service() {

    # Doing docker build and docker push on config service
    DOCKER_BUILD_STATUS_OUTPUT=`docker build \
    -f $PATH_TO_SOURCE_CODE/financial-exchange-config/dockerfile.configserver \
    --build-arg GIT_URI_ARG=$FINEX_GIT_REPO \
    --build-arg GIT_USER_ARG=$FINEX_GIT_USER \
    --build-arg GIT_PASSWORD_ARG=$FINEX_GIT_PASSWORD \
    -t ${FINEX_DOCKER_USERNAME}/finex-config-server \
    $PATH_TO_SOURCE_CODE/financial-exchange-config | grep "Successfully tagged"`
    DOCKER_BUILD_STATUS=`echo $DOCKER_BUILD_STATUS_OUTPUT  | awk '{print $1, $2}'`
    if [[ $DOCKER_BUILD_STATUS == "Successfully tagged" ]]; then
        echo "Config service docker build successful"
        echo "Pushing Config service docker image to docker hub"
        DOCKER_TAG=`echo $DOCKER_BUILD_STATUS_OUTPUT  | awk '{print $3}'`
        DOCKER_PUSH_OUTPUT=`docker push $DOCKER_TAG | grep "latest"`
        if [[ "$DOCKER_PUSH_OUTPUT" =~ "latest" ]]; then
            echo "Config service docker image pushed to dockerhub successfully"
        else 
            echo "Something is not right. Config service docker image push may have failed"
        fi
    else 
        echo "Config service docker build failed. Exiting"
        exit 1
    fi
}

# Build docker image for all Application Services and push to docker hub
function docker_build_application_services() {
    for SVC in "info" "products" "participants" "orders" "orderbooks" "trades"; do
        DOCKER_BUILD_STATUS_OUTPUT=`docker build \
        -f $PATH_TO_SOURCE_CODE/financial-exchange-$SVC/dockerfile.$SVC \
        --build-arg SPRING_PROFILES_ARG=aws \
        --build-arg SERVICES_BASE_URL_ARG=http://$INTERNAL_ALB_DNS_NAME \
        --build-arg CONFIG_SERVER_URI_ARG=http://$CONFIG_SVC_IP_ADDRESS:8888 \
        -t ${FINEX_DOCKER_USERNAME}/finex-$SVC-aws:latest \
        $PATH_TO_SOURCE_CODE/financial-exchange-$SVC | grep "Successfully tagged"`

        DOCKER_BUILD_STATUS=`echo $DOCKER_BUILD_STATUS_OUTPUT  | awk '{print $1, $2}'`
        if [[ $DOCKER_BUILD_STATUS == "Successfully tagged" ]]; then
            echo "$SVC service docker build successful"
            echo "Pushing $SVC service docker image to docker hub"
            DOCKER_TAG=`echo $DOCKER_BUILD_STATUS_OUTPUT  | awk '{print $3}'`
            DOCKER_PUSH_OUTPUT=`docker push $DOCKER_TAG | grep "latest"`
            if [[ "$DOCKER_PUSH_OUTPUT" =~ "latest" ]]; then
                echo "$SVC service docker image pushed to dockerhub successfully"
            else 
                echo "Something is not right. $SVC service docker image push may have failed"
                exit 2
            fi
        else 
            echo "$SVC service docker build failed"
        fi
    done
}

# Maven build all services
maven_build_all_services 

# docker build configuration service
docker_build_config_service  

# Deploy the finex-nat-gateway so that all services in the private subnet
# have internet access to install docker and other packages
STACK_NAME="finex-nat-gateway-$FINEX_AWS_REGION"
create_aws_stack finex-nat-gateway.json $STACK_NAME 

# Deploy the config service EC2 and get its IP address which will be supplied
# into the docker images for all application services
STACK_NAME="finex-config-service-$FINEX_AWS_REGION-zone1"
create_aws_stack finex-config-service-zone1.json $STACK_NAME "ParameterKey=KeyName,ParameterValue=$FINEX_AWS_KEY_NAME ParameterKey=DockerUsername,ParameterValue=$FINEX_DOCKER_USERNAME"
CONFIG_SVC_IP_ADDRESS=`get_aws_stack_output $STACK_NAME ConfigSvcPrivateIpZone1`
echo "Configuration service is [$CONFIG_SVC_IP_ADDRESS]"

# Deploy internal application load balancer. The DNS name of the interanl ALB
# will be supplied into the docker images for all application services
STACK_NAME="finex-internal-alb-$FINEX_AWS_REGION"
create_aws_stack finex-internal-alb.json $STACK_NAME 
INTERNAL_ALB_DNS_NAME=`get_aws_stack_output $STACK_NAME InternalAlbDnsName`
echo "Internal ALB DNS Name is [$INTERNAL_ALB_DNS_NAME]"

# docker build for application services
docker_build_application_services

# Deploy all application services
STACK_NAME="finex-application-services-$FINEX_AWS_REGION-zone1"
create_aws_stack finex-application-services-zone1.json $STACK_NAME "ParameterKey=KeyName,ParameterValue=$FINEX_AWS_KEY_NAME ParameterKey=DockerUsername,ParameterValue=$FINEX_DOCKER_USERNAME"

# Add listener and API rules to the internal load balancer
STACK_NAME="finex-internal-alb-listener-$FINEX_AWS_REGION"
create_aws_stack finex-internal-alb-listener.json $STACK_NAME

# Deploy external application load balancer. The DNS name of the interanl ALB
# will be supplied into the docker images for all application services
STACK_NAME="finex-external-alb-$FINEX_AWS_REGION"
create_aws_stack finex-external-alb.json $STACK_NAME
EXTERNAL_ALB_ARN=`get_aws_stack_output $STACK_NAME ExternalAlbArn`
echo "External ALB ARN is [$EXTERNAL_ALB_ARN]"
EXTERNAL_ALB_DNS_NAME=`get_aws_stack_output $STACK_NAME ExternalAlbDnsName`
echo "External ALB DNS Name is [$EXTERNAL_ALB_DNS_NAME]"

# Add listener and API rules to the external load balancer
STACK_NAME="finex-external-alb-listener-$FINEX_AWS_REGION"
create_aws_stack finex-external-alb-listener.json $STACK_NAME

# Create DNS A-record tying http://finex.mydomain.com to the external ALB so
# external users can invoke the finex API in the public internet via http://finex.mydomain.com
# domain. For example:  To place an order --> http://finex.mydomain.com/finex/api/order
# The required DNS parameters must be declared in the environment before running this script
# If these environment variables are not defined, DNS record will not be created but the user
# can still invoke the API from public internet using the public DNS name of the internet-facing external ALB
if [[ -z $FINEX_R53_HOSTED_ZONE_ID || -z $FINEX_URL ]]; then
    echo "Route 53 hosted zone id and the finex URL are not defined as environment variables. Will not register a DNS record to the internet-facing load balancer"
else
    STACK_NAME="finex-dns-$FINEX_AWS_REGION"
    create_aws_stack finex-dns.json $STACK_NAME "ParameterKey=DNSHostedZoneId,ParameterValue=$FINEX_R53_HOSTED_ZONE_ID ParameterKey=FinexURL,ParameterValue=$FINEX_URL"
fi
