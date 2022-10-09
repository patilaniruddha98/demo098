#!/bin/bash
s3_bucket="my-s3-bucket-uhstgdjcgt"
first_name="Aniruddha"
current_time=$(date '+%d%m%Y-%H%M%S')
inventory_file_path="/var/www/html/inventory.html"

sudo apt update -y

install_apache2(){
    echo "[INFO] Installing apache2 server"
    sudo apt install apache2 -y
    
}
start_apache2(){
    echo "[INFO] Starting apache2 server"
    systemctl start apache2.service
}
enable_apache2(){
    echo "[INFO] Enabling apache2 server"
    sudo systemctl enable apache2
}
check_apache2(){
    systemctl is-active --quiet apache2
    if [ $? -eq 0 ]
    then
        echo "[INFO] Apache server is  Active"
        systemctl is-enabled -q apache2 && status=TRUE || status=FALSE
        case $status in
            TRUE)
            tar_creation ;;
            FALSE)
                enable_apache2
            check_apache2 ;;
        esac
        
    else
        start_apache2
    fi
}

tar_creation(){
    tar -cvf /tmp/${first_name}-httpd-logs-${current_time}.tar /var/log/apache2/*.log && echo "[INFO] tar file created"
}
send_file_to_s3(){
    SEND_TO_S3=$(aws s3 cp /tmp/${first_name}-httpd-logs-${current_time}.tar s3://${s3_bucket}/${first_name}-httpd-logs-${current_time}.tar)
    SEND_TO_S3_CHECK=$(echo $SEND_TO_S3 | grep -c "upload: ../../tmp/${first_name}-httpd-logs-${current_time}.tar to s3://${s3_bucket}/${first_name}-httpd-logs-${current_time}.tar" )
    if [ $SEND_TO_S3_CHECK = 1 ]
    then
        echo "[INFO] File uploaded to s3"
    else
        echo "[ERROR] Error while uplaoding file to s3"
        exit 1
    fi
}
bookkeeping(){
    echo $current_time
    size=$(du -sh /tmp/${first_name}-httpd-logs-${current_time}.tar | awk '{print $1}')
    echo -e "httpd-logs\t${current_time}\ttar\t${size}" >> "${inventory_file_path}" && echo "[INFO] Entry made in inventory file"
}

s3_transfer(){
    echo "Checking S3 bucket exists..."
    S3_CHECK=$(aws s3 ls "s3://${s3_bucket}" 2>&1)
    if [ $? != 0 ]
    then
        BUCKET_CHECK=$(echo $S3_CHECK | grep -c 'NoSuchBucket')
        if [ $BUCKET_CHECK = 1 ]; then
            echo "Bucket does not exist"
            MAKE_BUCKET=$(aws s3 mb "s3://${s3_bucket}" 2>&1)
            CHECK_BUCKET_CREATION=$(echo $MAKE_BUCKET | grep -c "make_bucket: ${s3_bucket}")
            if [ $CHECK_BUCKET_CREATION = 1 ]
            then
                send_file_to_s3
            else
                echo "[ERROR] Error while craeting bucket"
                exit 1
            fi
        else
            echo "[ERROR] Error checking S3 Bucket"
            echo "$S3_CHECK"
            exit 1
        fi
    else
        send_file_to_s3
    fi
}

if [ $(sudo dpkg --get-selections | grep apache2 | awk '{print $1 ":" $2}' | grep "apache2:install") -eq “apache2:install” ]
then
    check_apache2
else
    #install apache
    install_apache2
    #function active
    check_apache2
fi

if [ -f ${inventory_file_path} ];
then
    # if file exist the it will be printed
    echo "[INFO] Inventory file is exist"
else
    touch ${inventory_file_path} && echo "[INFO] ${inventory_file_path} created" && echo "[INFO]Inventory file is created"
    chmod -v 755 ${inventory_file_path}
    echo -e "Log Type\tTime Created\tType\tSize" > ${inventory_file_path}
fi

s3_transfer

exit 0