#!/bin/sh -x

alias aws="aws --endpoint-url=$URL"
export BUCKET1_NAME=bucket1
export BUCKET2_NAME=bucket2
export PRIMARY_SQS=queue
export SECONDARY_SQS=queue-secondary
export DLQ_SQS=queue-dead-letter

until aws iam get-user
do
    echo "########### Waiting for localstack to be available ###########"
done

echo "########### Create Buckets ###########"
aws s3api create-bucket --bucket $BUCKET1_NAME
aws s3api create-bucket --bucket $BUCKET2_NAME

echo "########### Create Dead Letter Queue and get ARN ###########"
aws sqs create-queue --queue-name $DLQ_SQS

DLQ_SQS_ARN=$(aws sqs get-queue-attributes --attribute-name QueueArn --queue-url=$URL_LOCAL/000000000000/"$DLQ_SQS"\
  |  sed 's/"QueueArn"/\n"QueueArn"/g' | grep '"QueueArn"' | awk -F '"QueueArn":' '{print $2}' | tr -d '"' | xargs)

echo "########### Create Seconday Queue and get ARN ###########"
aws sqs create-queue --queue-name $SECONDARY_SQS \
  --attributes '{
      "RedrivePolicy": "{\"deadLetterTargetArn\":\"'"$DLQ_SQS_ARN"'\",\"maxReceiveCount\":\"10\"}",
      "VisibilityTimeout": "1200"
    }'

SECONADRY_SQS_ARN=$(aws sqs get-queue-attributes --attribute-name QueueArn --queue-url=$URL_LOCAL/000000000000/"$SECONDARY_SQS"\
  |  sed 's/"QueueArn"/\n"QueueArn"/g' | grep '"QueueArn"' | awk -F '"QueueArn":' '{print $2}' | tr -d '"' | xargs)

echo "########### Create Primary Queue ###########"
aws sqs create-queue --queue-name $PRIMARY_SQS \
  --attributes '{
      "RedrivePolicy": "{\"deadLetterTargetArn\":\"'"$SECONADRY_SQS_ARN"'\",\"maxReceiveCount\":\"1\"}",
      "VisibilityTimeout": "1200"
    }'

echo "########### Listing Buckets ###########"
aws s3 ls
echo "########### Listing Queues ###########"
aws sqs list-queues 