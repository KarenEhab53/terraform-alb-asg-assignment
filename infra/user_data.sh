
#!/bin/bash
# Update system and install Apache Web Server (httpd)
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd

# Write the index.html template file (injected dynamically via Terraform templatefile)
cat << 'EOF' > /var/www/html/index.html
${html_content}
EOF

# Fetch metadata from AWS EC2 IMDSv2
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)
LOCAL_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)

# Replace the placeholders in index.html with live metadata
sed -i "s/__INSTANCE_ID__/$INSTANCE_ID/g" /var/www/html/index.html
sed -i "s/__AVAILABILITY_ZONE__/$AZ/g" /var/www/html/index.html
sed -i "s/__LOCAL_IP__/$LOCAL_IP/g" /var/www/html/index.html