#!/bin/bash
set -e
CMD_NAME=$0
FROM_IMG=$1

function prompt(){
	echo "${CMD_NAME} FROM_IMG DIRNAME [PROXY]"
	exit 1
}


if [[ -z ${FROM_IMG} ]]; then
	prompt
fi

DIRNAME=$2

if [[ -z ${DIRNAME} ]]; then
	prompt
fi

PROXY=$3

cat > ${DIRNAME}/Dockerfile <<EOF
FROM ${FROM_IMG}
EOF

if [[ -n ${PROXY} ]]; then
	cat >> ${DIRNAME}/Dockerfile <<EOF
ENV http_proxy ${PROXY}
ENV https_proxy ${PROXY}
EOF
fi

cat >> ${DIRNAME}/Dockerfile <<EOF
RUN apt-get update && apt-get install -y --force-yes git wget
RUN cd / && git clone https://github.com/PaddlePaddle/Paddle.git && \
    cd Paddle && git checkout release/0.10.0
COPY run.sh /
COPY test.patch /
COPY gpu.patch /
RUN cd /Paddle && patch -p0 </test.patch && patch -p0 </gpu.patch
CMD /run.sh
EOF

IMG_NAME=paddle_regtest_${DIRNAME}_${RANDOM}

if [ -t 1 ] ; then  # if run this script in terminal
  TERM_OPT="-it"  # then alloc a tty for docker, so we can ctrl+c
else
  TERM_OPT=""
fi

cd ${DIRNAME}
docker build -t ${IMG_NAME} .
export CUDA_SO="$(\ls /usr/lib64/libcuda* | xargs -I{} echo '-v {}:{}') $(\ls /usr/lib64/libnvidia* | xargs -I{} echo '-v {}:{}')"
export DEVICES=$(\ls /dev/nvidia* | xargs -I{} echo '--device {}:{}')
docker run ${CUDA_SO} ${DEVICES} ${TERM_OPT} --rm ${IMG_NAME}
docker rmi ${IMG_NAME}
