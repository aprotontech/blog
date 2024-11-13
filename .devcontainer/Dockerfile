FROM openanolis/anolisos:8.9-x86_64

RUN yum install -y git vim wget make docker net-tools gcc gcc-c++

ARG TARGETARCH=amd64

RUN wget https://golang.google.cn/dl/go1.23.0.linux-${TARGETARCH}.tar.gz -O /tmp/go1.23.0.linux-${TARGETARCH}.tar.gz && \
    tar -C /usr/local -xzf /tmp/go1.23.0.linux-${TARGETARCH}.tar.gz && \
    rm -f /tmp/go1.23.0.linux-${TARGETARCH}.tar.gz

RUN adduser aproton -d /home/aproton -s /bin/bash --user-group
USER aproton

RUN echo 'export GOPATH=~/.go' >>~/.bashrc && \
    echo 'export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin' >>~/.bashrc && \
    export GOPATH=~/.go && \
    /usr/local/go/bin/go env -w GOPROXY=https://goproxy.cn,direct && \
    /usr/local/go/bin/go env -w GO111MODULE=on

RUN export GOPATH=~/.go && CGO_ENABLED=1 /usr/local/go/bin/go install -tags extended github.com/gohugoio/hugo@latest

RUN ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -q -N "" && \
    ssh-keyscan github.com >> ~/.ssh/known_hosts


