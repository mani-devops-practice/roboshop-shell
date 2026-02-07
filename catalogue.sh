#!/bin/bash

USERID=$(id -u)
LOGS_FOLDER="/var/log/shell-roboshop"
LOGS_FILE="/var/log/shell-roboshop/$0.log"
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"
SCRIPT_DIR=$PWD
MONGODB_HOST=mongodb.manig.online


if [ $USERID -ne 0 ]; then
    echo -e "$R Please run this script with root user access $N" | tee -a $LOGS_FILE
    exit 1
fi

mkdir -p $LOGS_FOLDER

VALIDATE(){
    if [ $1 -ne 0 ]; then
        echo -e "$2 ... $R FAILURE $N" | tee -a $LOGS_FILE
        exit 1
    else
        echo -e "$2 ... $G SUCCESS $N" | tee -a $LOGS_FILE
    fi
}

dnf module disable nodejs -y &>>$LOGS_FILE
VALIDATE $? "Disabling nodejs default"

dnf module enable nodejs:20 -y &>>$LOGS_FILE
VALIDATE $? "enable Nodejs 20"

dnf install nodejs -y &>>$LOGS_FILE
VALIDATE $? "Install Nodejs 20"


id roboshop &>>$LOGS_FILE

if [ $? ne 0 ]; then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>>$LOGS_FILE
    VALIDATE $? "Added roboshop user"
else
    echo "Roboshop user already exists .. $Y skipping $N"
fi

mkdir /app
VALIDATE $? "Creating app directory"

curl -o /tmp/catalogue.zip https://roboshop-artifacts.s3.amazonaws.com/catalogue-v3.zip &>>$LOGS_FILE
VALIDATE $? "Dowloaing the code"

cd /app 
VALIDATE $? "changing to app directory"

rm -rf /app/*
VALIDATE $? "Removing Exisiting code"

unzip /tmp/catalogue.zip  &>>$LOGS_FILE
VALIDATE $? "unzip source code"

npm install &>>$LOGS_FILE
VALIDATE $? "Installing system dependencies"

cp $SCRIPT_DIR/catalogue.service /etc/systemd/system/catalogue.service
VALIDATE $? "Created systemctl service"

systemctl daemon-reload
VALIDATE $? "Deamon reload"

systemctl enable catalogue 
systemctl start catalogue &>>$LOGS_FILE
VALIDATE $? "Started catalogue service"


cp $SCRIPT_DIR/monogo.repo /etc/yum.repos.d/mongo.repo
VALIDATE $? "Copying mongo repo"

dnf install mongodb-mongosh -y &>>$LOGS_FILE
VALIDATE $? "Install mongo client"

# To check mangodb setup is ready for the catalogue
INDEX=$(mongosh --host $MONGODB_HOST --quiet  --eval 'db.getMongo().getDBNames().indexOf("catalogue")')

if [ $INDEX -le 0 ]; then
    mongosh --host $MONGODB_HOST </app/db/master-data.js
    VALIDATE $? "Loading catalogue"
else
    echo "ALready laoded $Y skipping $N"


systemctl restart catalogue &>>$LOGS_FILE
VALIDATE $? "Restarted catalogue service"

