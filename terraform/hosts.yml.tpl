
all:
  vars:
    ansible_connection: ssh
    ansible_user: ec2-user
    ansible_become: true
    ansible_become_method: sudo
    ansible_ssh_private_key_file: ${private_key_path}

    installation_method: package

    #### TLS Configuration ####
    ## By default, data will NOT be encrypted. To turn on TLS encryption, uncomment this line
    ssl_enabled: false

    ## By default, the components will be configured with One-Way TLS, to turn on TLS mutual auth, uncomment this line:
    ssl_mutual_auth_enabled: false

    #### Monitoring Configuration ####
    ## Jolokia is enabled by default. The Jolokia jar gets pulled from the internet and enabled on all the components
    ## If you plan to use the upgrade playbooks, it is recommended to leave jolokia enabled because kafka broker health checks depend on jolokias metrics
    ## To disable, uncomment this line:
    jolokia_enabled: true
    ## During setup, the hosts will download the jolokia agent jar from Maven. To update that jar download set this var
    jolokia_jar_url: ${connector_download_url}/jolokia-jvm-1.6.2-agent.jar
    ## JMX Exporter is disabled by default. When enabled, JMX Exporter jar will be pulled from the Internet and enabled on the broker and zookeeper *only*.
    ## To enable, uncomment this line:
    jmxexporter_enabled: true
    ## To update that jar download set this var
    jmxexporter_jar_url: ${connector_download_url}/jmx_prometheus_javaagent-0.12.0.jar

    #### Custom Yum Repo File (Rhel/Centos) ####
    ## If you are using your own yum repo server to host the packages, in the case of an air-gapped environment,
    ## use the below variables to distribute a custom .repo file to the hosts and skip our repo setup.
    ## Note, your repo server must host all confluent packages
    repository_configuration: custom
    custom_yum_repofile_filepath: local.repo

    #### Schema Validation ####
    ## Schema Validation with the kafka configuration is disabled by default. To enable uncomment this line:
    ## Schema Validation only works with confluent_server_enabled: true
    # kafka_broker_schema_validation_enabled: true

    #### Fips Security ####
    ## To enable Fips for added security, uncomment the below line.
    ## Fips only works with ssl_enabled: true and confluent_server_enabled: true
    # Important: Breaks below configs in unusual ways if set to true -- only enable when *everything* is ready for FIPS
    fips_enabled: false

    #### Configuring Multiple Listeners ####
    ## CP-Ansible will configure two listeners on the broker: an internal listener for the broker to communicate and an external for the components and other clients.
    ## If you only need one listener uncomment this line:
    # kafka_broker_configure_multiple_listeners: false
    ## By default both of these listeners will follow whatever you set for ssl_enabled and sasl_protocol.
    ## To configure different security settings on the internal and external listeners set the following variables:
    kafka_broker_custom_listeners:
      broker:
        name: BROKER
        port: 9091
        ssl_enabled: false
        ssl_mutual_auth_enabled: false
        sasl_protocol: none
      internal:
        name: INTERNAL
        port: 9092
        ssl_enabled: false
        ssl_mutual_auth_enabled: false
        sasl_protocol: none
    ## You can even add additional listeners, make sure name and port are unique
#      client_listener:
#        name: CLIENT
#        port: 9093
#        ssl_enabled: true
#        ssl_mutual_auth_enabled: false
#        sasl_protocol: none

    ## By default the Confluent CLI will be installed on each host, to stop this download set:
    confluent_cli_download_enabled: false
    ## CLI will be downloaded from Confluent's webservers, to customize the location of the binary set:
    # confluent_cli_custom_download_url: <URL to custom webserver hosting for confluent cli>


    ## To set custom properties for each service
    ## Find property options in the Confluent Documentation
    # zookeeper_custom_properties:
    #   initLimit: 6
    #   syncLimit: 3
    # kafka_broker_custom_properties:
    #   num.io.threads: 15
    # schema_registry_custom_properties:
    #   key: val
    # control_center_custom_properties:
    #   key: val
    # kafka_connect_custom_properties:
    #   key: val
    # kafka_rest_custom_properties:
    #   key: val
    # ksql_custom_properties:
    #   key: val
    zookeeper_custom_java_args: "-Djavax.net.debug=all"
    kafka_broker_custom_java_args: "-Djavax.net.debug=all"

zookeeper:
  hosts:
%{ for id, zk_addr in zookeepers ~}
    ${zk_addr}:
      zookeeper_id: ${id}
      zookeeper:
        properties: {}
%{ endfor ~}

kafka_broker:
  hosts:
%{ for id, broker_addr in brokers ~}
    ${broker_addr}:
      broker_id: ${id}
      kafka_broker:
        properties: {}
%{ endfor ~}

schema_registry:
  hosts:
%{ for id, sr_addr in schema_registries ~}
    ${sr_addr}:
      schema_registry:
        properties: {}
%{ endfor ~}

kafka_connect:
  vars:
    kafka_connect_plugins_remote:
      - ${connector_download_url}/confluentinc-kafka-connect-syslog-1.3.2.zip
  children:
    syslog1:
      vars:
        kafka_connect_group_id: connect-syslog1
        kafka_connect_connectors:
          - name: Generic-Syslog-Ingest
            config:
              connector.class: "io.confluent.connect.syslog.SyslogSourceConnector"
              tasks.max: "16"
              syslog.listener: "TCP"
              syslog.port: 1514
              syslog.listen.address: "0.0.0.0"
              topic: "syslog"
              confluent.topic.bootstrap.servers: ${bootstrap_servers}
      hosts:
%{ for id, connect_syslog_addr in connect_syslog ~}
        ${connect_syslog_addr}:
          kafka_connect:
            properties:
              plugin.path: /usr/share/java,/usr/share/confluent-hub-components
%{ endfor ~}

kafka_rest:
  hosts:
%{ for id, rest_addr in kafka_rest ~}
    ${rest_addr}:
      kafka_rest:
        properties: {}
%{ endfor ~}

ksql:
  vars:
    ksql_group: syslog1
  hosts:
%{ for id, syslog_addr in ksql_syslog ~}
    ${syslog_addr}:
      ksql:
        properties: {}
%{ endfor ~}

control_center:
  vars:
    kafka_connect_cluster_ansible_group_names:
      - syslog1
  hosts:
%{ for id, c3_addr in control_center ~}
    ${c3_addr}:
      control_center_custom_properties: {}
%{ endfor ~}
