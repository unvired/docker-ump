#!/bin/sh

# ------------ Redis Sentinel
if [ "x$SENTINEL_PORT" = "x" ]; then
  SENTINEL_PORT="26379"
fi
if [ "x$SENTINEL_QUORUM" = "x" ]; then
  SENTINEL_QUORUM="1"
fi
if [ "x$MONITOR_MASTER" = "x" ]; then
  MONITOR_MASTER="ump-redis"
fi
if [ "x$REDIS_MASTER" = "x" ]; then
  REDIS_MASTER="redismaster"
fi
if [ "x$REDIS_MASTER_PORT" = "x" ]; then
  REDIS_MASTER_PORT="6379"
fi

echo "bind 0.0.0.0" > /etc/redis/sentinel.conf
echo "port ${SENTINEL_PORT}" >> /etc/redis/sentinel.conf
echo "sentinel monitor ${MONITOR_MASTER} ${REDIS_MASTER} ${REDIS_MASTER_PORT} ${SENTINEL_QUORUM}" >> /etc/redis/sentinel.conf
if [ "x$REDIS_MASTER_PASSWORD" != "x" ]; then
  echo "sentinel auth-pass ${MONITOR_MASTER} ${REDIS_MASTER_PASSWORD}" >> /etc/redis/sentinel.conf
fi
echo "sentinel down-after-milliseconds ${MONITOR_MASTER} 5000" >> /etc/redis/sentinel.conf
echo "sentinel failover-timeout ${MONITOR_MASTER} 10000" >> /etc/redis/sentinel.conf
echo "sentinel config-epoch ${MONITOR_MASTER} 160"  >> /etc/redis/sentinel.conf
echo "dir \"/tmp\"" >> /etc/redis/sentinel.conf

/usr/bin/redis-sentinel /etc/redis/sentinel.conf