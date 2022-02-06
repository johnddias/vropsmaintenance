# vropsmaintenance

Sample Powershell script to place a cluster object and all descendants into maintenance in vRealize Operations from VMware (this is NOT the same as placing a host into maintenance mode in vCenter).

To use:

Run script and answer prompts:

    vropshost: FQDN or IP of vROps node (any node, or cluster VIP)
    username: user
    password: password
    authsource: user authentication source, if using admin this is "Local"
    clustername: name or partial name of cluster; only one cluster is supported so if multiple clusters are found containing the partial name the script will throw an exception
    file: full path and filename to store the resource IDs being maintained; used to end maintenance
    maintained: true starts resources in manual maintenance; false requires the file parameter to end maintenance on previously maintained resources
    ignoreSSL: OPTIONAL if you are using self-signed certs, etc.
    
Use at your own risk
