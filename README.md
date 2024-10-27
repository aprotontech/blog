# blog

## 1. install themes
```bash
git submodule init
git submodule update
```

## 2. install hugo
```
sudo apt-get install hugo
```

## 3. test
```
IP=`ifconfig eth0 | grep inet | grep -v inet6 | awk '{print $2}'`
hugo server --theme=hugo-icarus-theme --baseUrl="http://$IP" --bind=$IP
```

## 4. render
```
hugo --theme=hugo-icarus-theme --baseURL="http://www.aproton.tech"
```

## 5. update website
github runner will update website(www.aproton.tech) when newly code has merged to main branch