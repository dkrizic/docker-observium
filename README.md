# Docker container for Observium Community Edition

Observium is a Network Monitoring system that uses SNMP to discovery details about each hosts and display graph about
memory, CPU and other details. Find more information at http://www.observium.org.

This Docker image is multi architecture. Supported archtictures include:

* amd64 ("normal PC)
* arm64 (Raspberry Pi 4 or newer running "real" OS like Ubuntu)

## Sources

The source for this Dockerimage can be found here: https://github.com/dkrizic/docker-observium

## Installation

### Requirements

* A Kubernetes cluster with amd64, arm32 or arm64 nodes (or any combination of that)
* An installed Ingress Controller

### Helm Chart

I created a Helm Chart for deploying Observium into a Kubernetes cluster which can be found here https://github.com/dkrizic/charts/tree/main/charts/observium

### Preparation

Create namespace using

```
kubectl create namespace observium
```

### Install MariaDB

Create a configuration file mariadb.yaml

```
userDatabase:
  name: observium
  user: observium
  password: passw0rd
  rootPassword: observium
storage:
  requestedSize: 10Gi
nodeSelector:
  kubernetes.io/arch: arm64
```

Change accordingly to you environment. The run

```
helm repo add groundhog2k https://groundhog2k.github.io/helm-charts/
helm repo update
helm -n observium upgrade --install observium-mariadb -f mariadb.yaml groundhog2k/mariadb
```

You should now have MariaDB up an running with is available as mysql://observium-mariadb:3306 inside the cluster which has a database observium preconfigured.

### Install Obserivum

Create a configuration file observium.yaml

```
odeSelector:
  kubernetes.io/arch: arm64
ingress:
  enabled: true
  hosts:
    - host: observium.krizic.net
      paths: 
      - path: "/"
observium:
  base_url: https://observium.example.com
  server_name: observium.example.com
  tz: "Europe/Berlin"
  admin:
    user: admin
    password: verySecretPassword
  db:
    host: observium-mariadb
    user: observium
    password: passw0rd
    name: observium

persistence:
  rrd:
    size: 20Gi
    storageClassName: rook-ceph-block-csi
  logs:
    size: 20Gi
    storageClassName: rook-ceph-block-csi
resources:
  requests:
    cpu: 1500m
  limits:
    cpu: 2800m
```

Note that the entries unter observium.db must match the entries from MariaDB in order to connect property. Also change the hostname to your own hostname. 
In this case observium should be available as https://observium.krizic.net
