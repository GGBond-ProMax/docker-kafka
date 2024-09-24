#!/bin/bash

# 设置 Kafka 版本
KAFKA_VERSION="3.8.0"  # 使用 Confluent 的 Kafka 版本

# 容器名称
KAFKA_CONTAINER_NAME="kafka-server"

# Kafka 端口
KAFKA_PORT="9092"
KAFKA_CONTROLLER_PORT="9093"

# 持久化数据的目录
KAFKA_NAME="/kafka"
KAFKA_DATA_DIR="/kafka/data"
KAFKA_CONF_DIR="/kafka/conf"

# 检查 Docker 是否安装
if ! [ -x "$(command -v docker)" ]; then
  echo "Error: Docker is not installed." >&2
  echo "[$(date)] Error: Docker is not installed."
  exit 1
fi

# 创建持久化存储目录
echo "创建 Kafka 目录..."
echo "[$(date)] 创建 Kafka 的数据目录..."
sudo mkdir -p $KAFKA_DATA_DIR $KAFKA_CONF_DIR
sudo chmod -R 777 $KAFKA_NAME

# 拉取Kafka镜像
docker pull apache/kafka:$KAFKA_VERSION

# 启动一个临时容器以复制配置文件
echo "启动临时 Kafka 容器以获取配置文件..."
docker run -d --name temp-kafka apache/kafka:$KAFKA_VERSION sleep infinity

# 复制配置文件到本地
echo "复制 Kafka 配置文件到本地目录..."
docker cp temp-kafka:/opt/kafka/config $KAFKA_CONF_DIR

# 删除临时容器
docker rm -f temp-kafka

# 启动 Kafka 容器（使用 KRaft 模式）
echo "启动 Kafka 容器..."
echo "[$(date)] 启动 Kafka 容器..."
docker run -d --name $KAFKA_CONTAINER_NAME \
  -p $KAFKA_PORT:9092 \
  -p $KAFKA_CONTROLLER_PORT:9093 \
  -v $KAFKA_DATA_DIR:/var/lib/kafka/data \
  -v $KAFKA_CONF_DIR:/opt/kafka/config \
  -e KAFKA_NODE_ID=1 \
  -e KAFKA_PROCESS_ROLES=broker,controller \
  -e KAFKA_LISTENERS=PLAINTEXT://:9092,CONTROLLER://:9093 \
  -e KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://localhost:9092 \
  -e KAFKA_CONTROLLER_LISTENER_NAMES=CONTROLLER \
  -e KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT \
  -e KAFKA_CONTROLLER_QUORUM_VOTERS=1@localhost:9093 \
  -e KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1 \
  -e KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR=1 \
  -e KAFKA_TRANSACTION_STATE_LOG_MIN_ISR=1 \
  -e KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS=0 \
  -e KAFKA_NUM_PARTITIONS=3 \
  -e KAFKA_MESSAGE_MAX_BYTES=200000000 \
  -e KAFKA_REPLICA_FETCH_MAX_BYTES=200000000 \
  apache/kafka:$KAFKA_VERSION

# 检查 Kafka 是否启动成功
if [ $(docker ps -q -f name=$KAFKA_CONTAINER_NAME) ]; then
  echo "Kafka 已成功启动"
  echo "[$(date)] Kafka 已成功启动"
  echo "Kafka 地址: localhost:$KAFKA_PORT"
else
  echo "Kafka 启动失败，请检查日志。"
  echo "[$(date)] Kafka 启动失败，请检查日志。"
  exit 1
fi



