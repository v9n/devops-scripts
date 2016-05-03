# Redis failover

Similar to sentinel.

Watch a list of Redis. When detect a master down, promote a random
slave. Then update a config file to change old master ip to new slave ip
