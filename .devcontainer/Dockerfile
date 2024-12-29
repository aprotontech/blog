FROM openanolis/anolisos:8.9-x86_64

RUN yum install -y git vim wget make docker net-tools gcc gcc-c++ 

ARG TARGETARCH=amd64

RUN ssh-keygen -t rsa -b 2048 -f /root/.ssh/id_rsa -q -N "" && \
    ssh-keyscan github.com >> /root/.ssh/known_hosts

RUN wget https://golang.google.cn/dl/go1.23.0.linux-${TARGETARCH}.tar.gz -O /tmp/go1.23.0.linux-${TARGETARCH}.tar.gz && \
    tar -C /usr/local -xzf /tmp/go1.23.0.linux-${TARGETARCH}.tar.gz && \
    rm -f /tmp/go1.23.0.linux-${TARGETARCH}.tar.gz && \
    echo 'export GOPATH=/var/aproton/go' >>/etc/profile.d/golang.sh && \
    echo 'export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin' >> /etc/profile.d/golang.sh && \
    chmod a+x /etc/profile.d/golang.sh

RUN export GOPATH=/var/aproton/go && \
    /usr/local/go/bin/go env -w GOPROXY=https://goproxy.cn,direct && \
    /usr/local/go/bin/go env -w GO111MODULE=on

RUN export GOPATH=/var/aproton/go && CGO_ENABLED=1 /usr/local/go/bin/go install -tags extended github.com/gohugoio/hugo@latest


