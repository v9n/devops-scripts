rs.initiate();

use admin;
db.createUser(
  {
    user: "$USER",
    pwd: "$PASSWORD",
    roles:
      [{
          role: "userAdminAnyDatabase",
          db: "admin"
      }, {
          role: "userAdminAnyDatabase",
          db: "admin"
      }, {
          "role": "root",
          "db": "admin"
      }, {
          "role": "dbOwner",
          "db": "admin"
      }]
  }
);

db.auth("$USER", "$PASSWORD");

rs.conf();

# Add node
rs.add("node1.hostname");
rs.add("node2.hostname");
