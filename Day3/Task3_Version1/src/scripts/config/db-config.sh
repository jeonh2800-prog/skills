#!/bin/bash
REGION_CODE="ap-northeast-2"
RDS_INSTANCE_IDENTIFIER="apdev-rds-instance"
RDS_PROXY_NAME="apdev-rds-proxy"

while true; do
    RDS_INSTANCE_STATUS=$(aws rds describe-db-instances --db-instance-identifier $RDS_INSTANCE_IDENTIFIER --query "DBInstances[0].DBInstanceStatus" --output text --region $REGION_CODE)
    if [ $RDS_INSTANCE_STATUS == "available" ]; then
        echo $RDS_INSTANCE_STATUS
        break
    fi
    echo $RDS_INSTANCE_STATUS
    sleep 10
done

while true; do
    RDS_PROXY_STATUS=$(aws rds describe-db-proxies --db-proxy-name $RDS_PROXY_NAME --query "DBProxies[0].Status" --output text --region $REGION_CODE)
    if [ $RDS_PROXY_STATUS == "available" ]; then
        echo $RDS_PROXY_STATUS
        break
    fi
    echo $RDS_PROXY_STATUS
    sleep 10
done

SECRET_NAME="apdev-rds-proxy-secrets"
MYSQL_USER=$(aws secretsmanager get-secret-value --secret-id $SECRET_NAME --query "SecretString" --output text --region $REGION_CODE | jq -r ".MYSQL_USER")
MYSQL_PASSWORD=$(aws secretsmanager get-secret-value --secret-id $SECRET_NAME --query "SecretString" --output text --region $REGION_CODE | jq -r ".MYSQL_PASSWORD")
MYSQL_HOST=$(aws secretsmanager get-secret-value --secret-id $SECRET_NAME --query "SecretString" --output text --region $REGION_CODE | jq -r ".MYSQL_HOST")
MYSQL_PORT=$(aws secretsmanager get-secret-value --secret-id $SECRET_NAME --query "SecretString" --output text --region $REGION_CODE | jq -r ".MYSQL_PORT")
MYSQL_DBNAME=$(aws secretsmanager get-secret-value --secret-id $SECRET_NAME --query "SecretString" --output text --region $REGION_CODE | jq -r ".MYSQL_DATABASE")

sed -i "s|DB_USER|$MYSQL_USER|g" /home/ec2-user/eks/manifest/configmap.yaml
sed -i "s|DB_PASSWORD|$MYSQL_PASSWORD|g" /home/ec2-user/eks/manifest/secrets.yaml
sed -i "s|DB_HOST|$MYSQL_HOST|g" /home/ec2-user/eks/manifest/configmap.yaml
sed -i "s|DB_PORT|$MYSQL_PORT|g" /home/ec2-user/eks/manifest/configmap.yaml
sed -i "s|DB_NAME|$MYSQL_DBNAME|g" /home/ec2-user/eks/manifest/configmap.yaml

mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p$MYSQL_PASSWORD -D $MYSQL_DBNAME < /home/ec2-user/rds/init.sql