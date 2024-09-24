#!/bin/bash

# 设置 Kafka 版本
OLD_KAFKA_VERSION="3.8.0"  # 当前 Kafka 版本
NEW_KAFKA_VERSION="3.8.0"  # 新的 Kafka 版本（用于升级）

# 容器名称
KAFKA_CONTAINER_NAME="kafka-server"

# Kafka 端口
KAFKA_PORT="9092"
KAFKA_CONTROLLER_PORT="9093"

# 持久化数据的目录
KAFKA_NAME="/kafka"
KAFKA_DATA_DIR="/kafka/data"
KAFKA_CONF_DIR="/kafka/conf"

# 备份目录
BACKUP_DIR="/kafka/backup"
BACKUP_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DATA_DIR="$BACKUP_DIR/data_$BACKUP_TIMESTAMP"
BACKUP_CONF_DIR="$BACKUP_DIR/conf_$BACKUP_TIMESTAMP"

# 备份 Kafka 数据和配置
backup_kafka() {
  echo "创建 Kafka 备份目录..."
  sudo mkdir -p $BACKUP_DATA_DIR $BACKUP_CONF_DIR
  sudo chmod -R 777 $BACKUP_DIR

  # 检查 Kafka 容器是否运行中
  if [ $(docker ps -q -f name=$KAFKA_CONTAINER_NAME) ]; then
      echo "Kafka 容器正在运行，停止容器以进行备份..."
      docker stop $KAFKA_CONTAINER_NAME
  fi

  # 备份数据和配置
  echo "备份 Kafka 数据和配置..."
  sudo cp -r $KAFKA_DATA_DIR/* $BACKUP_DATA_DIR/
  sudo cp -r $KAFKA_CONF_DIR/* $BACKUP_CONF_DIR/

  # 显示备份完成信息
  echo "备份完成："
  echo "数据备份到 $BACKUP_DATA_DIR"
  echo "配置备份到 $BACKUP_CONF_DIR"

  # 重新启动Kafka容器
  echo "重启Kafka容器中"
  docker start $KAFKA_CONTAINER_NAME
}

# 升级 Kafka
upgrade_kafka() {
  # 删除旧的 Kafka 容器
  echo "删除旧的 Kafka 容器..."
  docker rm $KAFKA_CONTAINER_NAME

  # 启动一个临时容器以获取新版本的配置文件
  echo "启动临时 Kafka 容器以获取新版本的配置文件..."
  docker run -d --name temp-kafka apache/kafka:$NEW_KAFKA_VERSION sleep infinity

  # 复制新版本的配置文件到本地
  echo "复制新版本的 Kafka 配置文件到本地目录..."
  docker cp temp-kafka:/opt/kafka/config $KAFKA_CONF_DIR

  # 删除临时容器
  docker rm -f temp-kafka

  # 启动升级后的 Kafka 容器（使用新版本和 KRaft 模式）
  echo "启动升级后的 Kafka 容器..."
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
    apache/kafka:$NEW_KAFKA_VERSION

  # 检查升级是否成功
  if [ $(docker ps -q -f name=$KAFKA_CONTAINER_NAME) ]; then
    echo "Kafka 已成功升级到版本 $NEW_KAFKA_VERSION"
    echo "Kafka 地址: localhost:$KAFKA_PORT"
  else
    echo "Kafka 升级失败，请检查日志。"
    exit 1
  fi
}

# 用户操作选择
echo "请选择要执行的操作："
echo "1) 备份Kafka"
echo "2) 升级Kafka"
read -p "输入选项 (1 或 2): " user_choice

if [ "$user_choice" == "1" ]; then
  backup_kafka
elif [ "$user_choice" == "2" ]; then
  upgrade_kafka
else
  echo "无效的选项，脚本退出。"
  exit 1
fi
