# blog

# install hugo

# test
```
IP=`ifconfig eth0 | grep inet | grep -v inet6 | awk '{print $2}'`
hugo server --theme=hugo-icarus-theme --baseUrl="http://$IP" --bind=$IP
```

# render
```
hugo --theme=hugo-icarus-theme
```