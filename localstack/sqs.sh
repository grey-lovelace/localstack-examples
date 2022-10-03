#!/bin/sh -x
export PRIMARY_SQS=queue
export SECONDARY_SQS=queue-secondary
export DLQ_SQS=queue-dead-letter

echo "########### Create Dead Letter Queue and get ARN ###########"
aws sqs create-queue --endpoint-url=$URL --queue-name $DLQ_SQS

DLQ_SQS_ARN=$(aws sqs get-queue-attributes --endpoint-url=$URL --attribute-name QueueArn --queue-url=$URL_LOCAL/000000000000/"$DLQ_SQS"\
  |  sed 's/"QueueArn"/\n"QueueArn"/g' | grep '"QueueArn"' | awk -F '"QueueArn":' '{print $2}' | tr -d '"' | xargs)

echo "########### Create Seconday Queue and get ARN ###########"
aws sqs create-queue --endpoint-url=$URL --queue-name $SECONDARY_SQS \
  --attributes '{
      "RedrivePolicy": "{\"deadLetterTargetArn\":\"'"$DLQ_SQS_ARN"'\",\"maxReceiveCount\":\"10\"}",
      "VisibilityTimeout": "1200"
    }'

SECONADRY_SQS_ARN=$(aws sqs get-queue-attributes --endpoint-url=$URL --attribute-name QueueArn --queue-url=$URL_LOCAL/000000000000/"$SECONDARY_SQS"\
  |  sed 's/"QueueArn"/\n"QueueArn"/g' | grep '"QueueArn"' | awk -F '"QueueArn":' '{print $2}' | tr -d '"' | xargs)

echo "########### Create Primary Queue ###########"
aws sqs create-queue --endpoint-url=$URL --queue-name $PRIMARY_SQS \
  --attributes '{
      "RedrivePolicy": "{\"deadLetterTargetArn\":\"'"$SECONADRY_SQS_ARN"'\",\"maxReceiveCount\":\"1\"}",
      "VisibilityTimeout": "1200"
    }'

echo "########### Listing queues ###########"
aws sqs list-queues --endpoint-url=$URL