# Rolling Update with Terraform

This code is just a representation on how you could apply rolling update to yours EC2 instances. Do not use it in production.


```bash
terraform --version
Terraform v0.13.1

packer --version
1.6.0
```

Instructions:

### Create the first image
```hcl
cd packer
packer build .
```

### Apply the terraform
```bash
cd ..
terraform init
terraform apply
```

### Check the current color of the page
In another terminal:
```bash
while true; do
curl $(terraform output lb_dns)
sleep 1
done
```

### Create another image with a different color
```hcl
cd packer
packer build -var 'color=blue' .
```

### Apply the new image version
```bash
cd ..
terraform apply
```

## Clean up
```bash
terraform destroy
```

Deregister AMI from the console.
