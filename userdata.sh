#!/bin/bash
 
echo ubuntu | passwd -s ubuntu

(

while [ ! -f /var/lib/cloud/instance/boot-finished ]; do
  echo -e "\033[1;36mWaiting for cloud-init..."
  sleep 1
done

sudo apt-get update
sudo apt-get -y install nginx

cat <<EOF > /var/www/html/index.html
<h1>Page created by Phillip Odam</h1>
EOF

sudo chown root:root /var/www/html/index.html
sudo chmod a+r /var/www/html/index.html

)&
