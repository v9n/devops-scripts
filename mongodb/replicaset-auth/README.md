# Note

When setting up replicaset with authentication, we have to enforce
internal authentication. The easiest way is to use `keyFile`

The replica needs to be `initialize` first. After that, we add first
user to master, and using `rs.add` from primary to join replica


# SSL/TLS

https://docs.mongodb.com/master/tutorial/configure-ssl/
https://docs.mongodb.com/manual/core/security-x.509/
