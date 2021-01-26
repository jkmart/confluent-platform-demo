# confluent-platform-demo
Bring up components of the Confluent Platforms in an AWS Cloud Environment that somewhat resembles an offline environment.

The offline portion is optional, but because it is also a bit more complicated it will be the focus of this demo.

# Requirements
* Kafka Server (See [Kafka Quickstart](https://kafka.apache.org/quickstart) for more information)
* AWS Account with a private key created for EC2 instances.
  This includes a valid AWS configuration, either through the AWS CLI or in `~/.aws/credentials`
  Assuming `us-east-1` region.
* Hashicorp Terraform >= 0.13
* Ansible >= 2.7
* Confluent [cp-ansible version 6.0.1](https://github.com/confluentinc/cp-ansible/tree/6.0.1-post) repository.
  Additional information and documentation for this Ansible playbook can be found [here](https://docs.confluent.io/ansible/6.0.1/overview.html).
* A *nix environment. 
  This demo has been tested on Windows using WSL, but it's much more involved and not necessarily supported.
  Ansible specifically calls out Windows machines as [not suitable as control nodes](https://docs.ansible.com/ansible/latest/network/getting_started/basic_concepts.html#control-node).

## Optional
### For "Offline" YUM repository and repository
* Hashicorp Packer >= 1.5.0

## Offline Installs
For secure and/or FIPS environments, we need to enable offline installation of components.

In AWS, we're not exactly "offline", but we can simulate it a bit.
We can create a Security Group that allows no egress traffic external to the Security Group.
We'll create an image that has hosts a YUM repository that contains the Confluent Platform 6.0.1 packages,
as well as an Apache webserver that hosts additional files:

* JMX agent
  
  https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.12.0/jmx_prometheus_javaagent-0.12.0.jar
  
* Jolokia
  
  https://search.maven.org/remotecontent?filepath=org/jolokia/jolokia-jvm/1.6.2/jolokia-jvm-1.6.2-agent.jar
  
* Kafka Connect Syslog Zip file
  
  https://www.confluent.io/hub/confluentinc/kafka-connect-syslog


# Create AMI Image for YUM Repository and Apache webserver

## Preparation
  * Download the files listed above.
  * Place these files in the `./packer/ansible/` directory.

## Packer
  * Change directory to `./packer`.
  * Run the command:
```
packer build repo.pkr.hcl
```
  * Make coffee, mirroring the repositories with the reposync command can take a while, to say nothing of finalizing the AMI.
  * Once created, an AMI called `confluent-repo-6.0.1-${timestamp}` should now be available.

# Create instances
## Terraform
  * Change directory to `./terraform`.
  * Run `terraform init`.
  * Create a `terraform.tfvars` file, or otherwise supply variables listed in `variables.tf`.
    For more information on Terraform variables, see [Terraform Variables](https://www.terraform.io/docs/language/values/variables.html#assigning-values-to-root-module-variables).
  * Run a `terraform plan`, check the output.
    It should resolve the AMI created in the above Packer steps, and list out the soon-to-be-created EC2 instances.
  * Run `terraform apply`, double-check the output, and proceed when prompted.

# Provision instances
## Ansible
  * Once Terraform has finished, two resources, `hosts.yml` and `local.repo` should be created in the `./terraform` directory.
  * Move these two files into the cp-ansible repository.
  * Change directories to the cp-ansible repository.
  * Run Ansible with the zookeeper tag to provision only the Apache Zookeeper nodes:
```
ansible-playbook -i hosts.yml -t zookeeper all.yml
```
  If there are any errors, they will need to be resolved before moving onto the Kafka Brokers.
  * Run Ansible with the kafka_broker tag to provision only the Apache Kafka broker nodes:
```
ansible-playbook -i hosts.yml -t kafka_broker all.yml
```
  * Run Ansible without any specific tag to provision the rest of the component nodes:
```
ansible-playbook -i hosts.yml all.yml
```
This command will also run Zookeeper and Kafka Brokers again as well, but at this point there should be nothing further to do on those nodes.

# Test setup
## Confluent Control Center
  * You should now be able to get into the Confluent Control Center to view the brokers, topics, Kafka Connect, and ksqlDB.
    This can be an easy way to ensure all the components came up.
## Produce and Consume messages on a topic
### Be sure to do this on a machine that can reach the nodes, either within the Security Group or from a location allowed by the Security Group.
  * Create a test topic
```
kafka-topics --create --topic test-topic --bootstrap-server <broker-0 address>:9092
```
  * Produce a message onto the topic
```
kafka-console-producer --topic test-topic --bootstrap-server <broker-0 address>:9092
```
This should open a prompt to input data:
```
test message 1
test message 2
it works!
```
  * Open another terminal window and consume messages on the topic
```
kafka-console-consumer --topic test-topic --from-beginning --bootstrap-server <broker-0 address>:9092
```
Expected output:
```
test message 1
test message 2
it works!
```

# Finish
## Terraform Destroy
  * Once finished with the setup, the EC2 instances and Security Groups can be removed with one command:
```
# bypass the prompt with the -auto-approve flag
terraform destroy -auto-approve
```
  * The AMI created for the YUM repository will need to be deregistered from the account as well.
    This can be found under Images -> AMIs within the EC2 console page.
    
