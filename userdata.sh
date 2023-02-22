#!/bin/bash
sudo su
yum update -y
yum install -y httpd
systemctl start httpd.service
systemctl enable httpd.service
echo "<html><body><h1>Hello World from PlayQ Test</h1></body></html>" > /var/www/html/index.html
systemctl restart httpd.service
echo Listen 8082 >> /etc/httpd/conf/httpd.conf