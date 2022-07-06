#! /bin/bash

dns_back_dir="./"
polaris_server_addr=""
while getopts ':b:s:h' OPT; do #选项后面的冒号表示该选项需要参数
    case $OPT in
    b)
        dns_back_dir="$OPTARG"
        ;;
    s)
        polaris_server_addr="$OPTARG"
        ;;
    h)
        echo "./install-linux.sh -s \${polaris_server_addr} -d \${dns_back_dir}"
        exit 0
        ;;
    ?) #当有不认识的选项的时候arg为?
        echo "./install-linux.sh -s \${polaris_server_addr} -d \${dns_back_dir}"
        exit 1
        ;;
    esac
done

if [[ "${polaris_server_addr}" == "" ]]; then
    echo "[ERROR] need set polaris_server_addr, eg: ./install-linux.sh -s \${polaris_server_addr}"
    exit 1
fi

echo "[INFO] input param: dns_backdir = ${dns_back_dir}"
echo "[INFO] input param: polaris_server_addr = ${polaris_server_addr}"

function install_polaris_sidecar() {
    echo -e "[INFO] install polaris sidecar ... "
    ps -ef | grep polaris-sidecar | grep -v grep
    local polaris_sidecar_num=$(ps -ef | grep polaris-sidecar | grep -v grep | wc -l)
    if [ ${polaris_sidecar_num} -ge 1 ]; then
        echo -e "[ERROR] polaris-sidecar is running, exit"
        exit -1
    fi

    local polaris_sidecar_pkg_num=$(find . -name "polaris-sidecar-release*.zip" | wc -l)
    if [ ${polaris_sidecar_pkg_num} != 1 ]; then
        echo -e "[ERROR] number of polaris sidecar package not equals to 1, exit"
        exit -1
    fi

    local target_polaris_sidecar_pkg=$(find . -name "polaris-sidecar-release*.zip")
    local polaris_sidecar_dirname=$(basename ${target_polaris_sidecar_pkg} .zip)
    if [ -e ${polaris_sidecar_dirname} ]; then
        echo -e "[INFO] ${polaris_sidecar_dirname} has exists, now remove it"
        rm -rf ${polaris_sidecar_dirname}
    fi
    unzip ${target_polaris_sidecar_pkg} >/dev/null
    pushd ${polaris_sidecar_dirname}

    # 修改 polaris_server_addr 地址
    sed -i "s/##POLARIS_SERVER_ADDR##/${polaris_server_addr}/g" polaris.yaml
    /bin/bash ./tool/start.sh
    echo -e "[INFO] install polaris sidecar success"
    popd
}

function write_dns_conf() {
    ## 修改机器的 /etc/resolv.conf 文件
    old_cnf_str=""
    if [ -f "/etc/resolv.conf" ]; then
        current=$(date "+%Y-%m-%d %H:%M:%S")
        timeStamp=$(date -d "$current" +%s)
        currentTimeStamp=$(((timeStamp * 1000 + 10#$(date "+%N") / 1000000) / 1000))
        version="$currentTimeStamp"
        cp /etc/resolv.conf ${dns_back_dir}/resolv.conf.bak_${version}
    fi

    echo "# polaris-sidecar resolv.conf" >/etc/resolv.conf
    echo "# This file is automatically generated." >>/etc/resolv.conf
    echo ""
    echo "nameserver 127.0.0.1" >>/etc/resolv.conf
    echo "" >>/etc/resolv.conf
    echo "" >>/etc/resolv.conf
    echo "# old resolv.conf" >>/etc/resolv.conf
    cat ${dns_back_dir}/resolv.conf.bak_${version} | while read line; do
        echo "[DEBUG] ${line}"
        echo ${line} >>/etc/resolv.conf
    done
}

# 安装北极星 sidecar
install_polaris_sidecar
if [[ $? != 0 ]]; then
    exit 1
fi
# 写入 dns_conf 文件
write_dns_conf
