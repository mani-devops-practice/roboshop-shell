
#!/bin/bash

USER_ID=$(id -u)
SG_ID="sg-0928fb36c1def6679"
IMAGE_ID="ami-0220d79f3f480ecf5"
ZONE_ID="Z0284894TI6GCPU6GNRN"
DOMAIN_NAME="manig.online"
INSTANCE_TYPE="t3.micro"


for services in $@
do 
   INSTANCE_ID=$( aws ec2 run-instances \
    --image-id $IMAGE_ID \
    --instance-type $INSTANCE_TYPE \
    --security-group-ids $SG_ID \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$service}]" \
    --query 'Instances[0].InstanceId' \
    --output text )
   
   if [ $service == "frontend" ]; then
        IP=$(
            aws ec2 describe-instances \
            --instance-ids $INSTANCE_ID \
            --query 'Reservations[].Instances[].PublicIpAddress' \
            --output text
        )
        
        RECORD_NAME=$DOMAIN_NAME     
  
   else
        IP=$(
            aws ec2 describe-instances \
            --instance-ids $INSTANCE_ID \
            --query 'Reservations[].Instances[].PrivateIpAddress' \
            --output text
        )
        RECORD_NAME=$service.$DOMAIN_NAME
   fi

   aws route53 change-resource-record-sets \
    --hosted-zone-id $ZONE_ID \
    --change-batch '
    {
        "Comment": "Updating record",
        "Changes": [
            {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "'$RECORD_NAME'",
                "Type": "A",
                "TTL": 1,
                "ResourceRecords": [
                {
                    "Value": "'$IP'"
                }
                ]
            }
            }
        ]
    }
    '

    echo "record updated for $service"

done 