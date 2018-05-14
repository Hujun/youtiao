## Youtiao

Youtiao is a project for Micro-Service scaffold generation and provides a set of related tools.

---

* [Prerequisites](#prerequisites)
* [Installation](#installation)
* [Usage](#usage)
  * [Project Init](#project-init)
  * [Docker image build](#docker-image-build)
  * [gRPC protobuf file compile](#grpc-protobuf-file-compile)
  * [Rancher deployment (CI/CD)](#rancher-deployment-(CI/CD))
* [About "Youtiao"](#about-"youtiao")
* [Support the project](#support-the-project)

### Prerequisites

Youtiao requires python version >= 3.6.0. If you don't have appropriate python version installed on your computer, we recommand use [pyenv](https://github.com/pyenv/pyenv) to prepare one.

### Installation

From pypi:

```
pip install -U Youtiao
```

From source code:

```
git clone git@github.com:Hujun/youtiao.git && cd Youtiao && python setup.py install
```

### Usage

When you successfully installed youtiao in your python environment, type ``youtiao`` or ``youtiao —help`` in your console, you will see following outputs:

```
Usage: youtiao [OPTIONS] COMMAND [ARGS]...

  Micro Service Toolkit

Options:
  --help  Show this message and exit.

Commands:
  build_image     Build docker image
  init            Generate Python service boilerplate
  protoc          Shortcut of grpc_tools.protoc to compile...
  rancher_deploy  Deploy using rancher (v1.6) API (v2.0 beta)
```

You can get detailed guide for each command if you type:

```
youtiao [command] --help
```

#### Project init

Create a new project by command:

```
youtiao init --language=python [directory]
```

A dialog will be launched for service name and service mode confirmation. If everything goes well, a project skeleton will be generated. The command will not generate any file under given directory path if the process is abort or any exception is raised.

Now available language and service templates:

| Programming Language | Servcie Template |
| :------------------: | :--------------: |
|        Python        |       HTTP       |
|        Python        |       gRPC       |

#### Docker image build

```
Usage: youtiao build_image [OPTIONS]

  Build docker image

Options:
  --project-name TEXT     project name  [required]
  --commit-ref-name TEXT  name of git branch or tag  [required]
  --commit-sha TEXT       git commit hash  [required]
  --workdir DIRECTORY     [required]
  --registry-url TEXT     Docker registry URL
  --help                  Show this message and exit.
```

This command is just a wrapper of docker engine HTTP API using official docker python package. You can use it in some CI/CD scenarios when docker native shell commands are not available.

#### gRPC protobuf file compile

```
Usage: youtiao protoc [OPTIONS]

  Shortcut of grpc_tools.protoc to compile .proto file.

Options:
  --proto-path PATH  path of protobuf file  [required]
  --out DIRECTORY    output files location
  --help             Show this message and exit.
```

Wrapper of grpcio tool.

#### Rancher deployment (CI/CD)

```
Usage: youtiao rancher_deploy [OPTIONS]

  Deploy using rancher (v1.6) API (v2.0 beta)

Options:
  --rancher-url TEXT              rancher server API endpoint URL  [required]
  --rancher-key TEXT              rancher account or environment API access
                                  key  [required]
  --rancher-secret TEXT           rancher account or environment API secret
                                  corresponding to the access key  [required]
  --rancher-env TEXT              used to specify environemnt if account key
                                  is provided
  --stack TEXT                    stack name defined in rancher  [required]
  --service TEXT                  service name defined in rancher  [required]
  --batch-size INTEGER            number of containers to upgrade at once
  --batch-interval INTEGER        interval (in second) between upgrade batches
  --sidekicks / --no-sidekicks    upgrade sidekicks services at the same time
  --start-before-stopping / --no-start-before-stopping
                                  start new containers before stopping the old
                                  ones
  --help                          Show this message and exit.
```

You can have more details about Rancher CI/CD in your [blog](https://github.com/Hujun/blog/issues/2).

### About "Youtiao"

["Youtiao"](https://en.wikipedia.org/wiki/Youtiao) is a long golden-brown deepfried strip of dough eaten in China and (by a variety of other names) in other East and Southeast Asian cuisines. Conventionally, youtiao are lightly salted and made so they can be born lengthwise in two. Youtiao are normally eaten at breakfast as an accompaniment for rice congee, soy milk or regular milk blended with suger.

![youtiao](https://upload.wikimedia.org/wikipedia/commons/thumb/7/78/Youtiao.jpg/500px-Youtiao.jpg)

### Support the project

Donate ETH if you find the project is helpful:

```
0x7744F44ecB64ce24b09e1F924DD48a4Ada32A835
```

