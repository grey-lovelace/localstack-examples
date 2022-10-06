#!/bin/sh -x

alias aws="aws --endpoint-url=$LOCALSTACK_URL"
export AWS_ACCOUNT=000000000000
export BUCKET1_NAME=bucket1
export BUCKET2_NAME=bucket2
export PRIMARY_SQS=queue
export SECONDARY_SQS=queue-secondary
export DLQ_SQS=queue-dead-letter

# Wait till localstack is available
until aws iam get-user
do
    echo "########### Waiting for localstack to be available ###########"
done

# S3 setup
echo "########### Create Buckets ###########"
aws s3api create-bucket --bucket $BUCKET1_NAME
aws s3api create-bucket --bucket $BUCKET2_NAME

# SQS setup
getQueueArn() {
    aws sqs get-queue-attributes --attribute-name QueueArn --queue-url="$LOCALSTACK_URL/$AWS_ACCOUNT/$1"\
    |  sed 's/"QueueArn"/\n"QueueArn"/g' | grep '"QueueArn"' | awk -F '"QueueArn":' '{print $2}' | tr -d '"' | xargs | echo
}

echo "########### Create Dead Letter Queue and get ARN ###########"
aws sqs create-queue --queue-name $DLQ_SQS

DLQ_SQS_ARN=$(getQueueArn $DLQ_SQS)

echo "########### Create Seconday Queue and get ARN ###########"
aws sqs create-queue --queue-name $SECONDARY_SQS \
    --attributes '{
        "RedrivePolicy": "{\"deadLetterTargetArn\":\"'$DLQ_SQS_ARN'\",\"maxReceiveCount\":\"10\"}",
        "VisibilityTimeout": "1200"
    }'

SECONADRY_SQS_ARN=$(getQueueArn $SECONDARY_SQS)

echo "########### Create Primary Queue ###########"
aws sqs create-queue --queue-name $PRIMARY_SQS \
    --attributes '{
        "RedrivePolicy": "{\"deadLetterTargetArn\":\"'$SECONADRY_SQS_ARN'\",\"maxReceiveCount\":\"1\"}",
        "VisibilityTimeout": "1200"
    }'

# Echo out created resources
echo "########### Listing Buckets ###########"
aws s3 ls
echo "########### Listing Queues ###########"
aws sqs list-queues 