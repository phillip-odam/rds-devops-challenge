# rds-devops-challenge

## Dependencies
 - terraform [https://www.terraform.io/](https://www.terraform.io/)
 - AWS CLI [https://aws.amazon.com/cli/](https://aws.amazon.com/cli/)
   - configure profile named rds in ~/.aws/credentials setting aws_access_key_id and aws_secret_access_key

# Setup

After cloning this repository, from the terminal you will need to change your local working directory to the be where this repository is located and then initialize terraform by executing the following command

```
terraform init
```

To execute the terraform script first build the terraform plan and then apply the plan

```
terraform plan -out=create.tfplan
terraform apply create.tfplan
```

Once you are finished using the environment created using terraform you can dispose of the environment by first creating the destroy plan and the applying it

```
terraform plan -destroy -out=destroy.tfplan
terraform apply destroy.tflan
```

## Assumptions
 - It's permitted to provision more AWS resources than the exercise calls for, for example a NAT Gateway so the OS on EC2 in the private subnet can be updated and have NGINX installed with ease using apt retrieving from the internet
 - For ease and timeliness, used one terraform script and configuration is not flexible ie. no use of variables, looping. Instead the terraform script is very simple and involves duplication so not an example of best practices

## Verifying environment build using terraform

When the execution of ```terraform apply create.tfplan``` completes the last line of output will be of the form ```message = "ALB DNS name <hostname>, private IP of EC2 instance <IP address>"```

**Please note** after applying the terraform plan you will likely need to wait a number of seconds before being able to get a successful response from the ALB as everything isn't quite ready immediately after the terraform script completes.
If you issue a request using curl to the ALB too soon you may either see ```curl: (7) Failed to connect to <hostname> port <port> after <milliseconds> ms: Couldn't connect to server``` or

```
<html>
<head><title>502 Bad Gateway</title></head>
<body>
<center><h1>502 Bad Gateway</h1></center>
</body>
</html>
```

Where ```<hostname>``` is the hostname of ALB from the terminal execute the command ```curl http://<hostname>/``` and you will recieve the output ```<h1>Page created by Phillip Odam</h1>```

The same request except over HTTPS can be issued from the terminal by executing the command ```curl -k https://<hostname>/``` and again you will receive the output ```<h1>Page created by Phillip Odam</h1>```

