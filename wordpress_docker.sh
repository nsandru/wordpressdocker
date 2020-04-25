#!/bin/bash
#
# Build a set of docker containers for a WordPress installation
#

if [ -z "$2" ] ; then
  echo Usage: $0 wordpress_dir database_dir '[IP address]'
  exit 1
fi

# Specify the mariadb and wordpress docker images to be used for the build
declare -a IMAGES=("mariadb:10.3" "wordpress:5.3.2")

WPDIR=$1
DBDIR=$2
IPADDR=$3
export PATH=/bin:/usr/bin
MARIADBIMAGE=${IMAGES[0]}
WPIMAGE=${IMAGES[1]}

# Read the password for the MariaDB database
password() {
  CNT=5
  while [ 1 ] ; do
    stty -echo
    printf "Enter a password for database access: " 1>&2
    read PASSWORD1
    printf "\nReenter the password: " 1>&2
    read PASSWORD2
    printf "\n" 1>&2
    stty echo
    if [ x"$PASSWORD1" = x"$PASSWORD2" ] ; then
      printf "$PASSWORD1"
      return 0
    elif [ -z "$PASSWORD1" ] ; then
      printf "The password cannot be nul\n" 1>&2
      sleep 1
    else
      printf "Passwords not identical\n" 1>&2
      sleep 1
    fi
    CNT=$(expr $CNT - 1)
    if [ $CNT -eq 0 ] ; then
      printf "More than 5 password failed entry attempts, exiting\n"
      exit 1
    fi
  done
}

# Pull the docker images for the MariaDB and WordPress containers
for IMAGE in ${IMAGES[@]} ; do
  declare -a NAMETAG=($(printf $IMAGE | tr ':' ' '))
  IMAGEPRESENT=$(docker images | grep "^${NAMETAG[0]} " | grep -F " ${NAMETAG[1]} " |wc -l)
  if [ $IMAGEPRESENT -gt 0 ] ; then
    continue
  fi
  docker pull $IMAGE
done

if [ ! -d $DBDIR ] ; then
  mkdir -p $DBDIR
fi

# Prepare to initialize the mariadb database if necessary
DBDIRFILES=$(ls $DBDIR | wc -l)
ENV=
if [ $DBDIRFILES -eq 0 ] ; then
  PASSWORD=$(password)
  if [ $? -ne 0 ] ; then
    exit 1
  fi
  ENV="-e MYSQL_ROOT_PASSWORD=${PASSWORD}"
fi

# Start the mariadb container. If there is an inactive mariadb container
# remove it before starting.
MARIADBCONT=$(docker ps | awk '{print $NF}' | grep '^mariadb$' | wc -l)
if [ $MARIADBCONT -eq 0 ] ; then
  if [ $(docker ps -a | awk '{print $NF}' | grep '^mariadb$' | wc -l) -ne 0 ] ; then
    docker rm mariadb
  fi
  docker run -d --name mariadb $ENV -v $DBDIR:/var/lib/mysql:Z -p 3306 $MARIADBIMAGE
  printf "Creating the mariadb container\n"
  sleep 15
  if [ $(docker ps | awk '{print $NF}' | grep '^mariadb$' | wc -l) -ne 0 ] ; then
    printf "mariadb container ready\n"
  else
    printf "mariadb container creation failed\n"
    exit 1
  fi
fi
MARIADBIPADDR=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' mariadb)

# Enter the password for the mariadb database if necessary
if [ -z "${PASSWORD}" ] ; then
    stty -echo
    printf "Enter the mariadb password: " 1>&2
    read PASSWORD
    stty echo
    printf "\n"
fi

printf "Checking the mariadb connection\n"
cat /dev/null | mysql -h $MARIADBIPADDR -u root -p${PASSWORD}
ST=$?
if [ $ST -ne 0 ] ; then
  exit 1
fi

# Create the wordpress database if necessary
printf "Checking whether the 'wordpress' database is present\n"
WORDPRESSDB=$(printf "SHOW DATABASES;\n" | mysql -h $MARIADBIPADDR -u root -p${PASSWORD} | grep wordpress | wc -l)
if [ $WORDPRESSDB -eq 0 ] ; then
  printf "Creating the 'wordpress' database\n"
  printf "CREATE DATABASE wordpress;\n" | mysql -h $MARIADBIPADDR -u root -p${PASSWORD}
fi
WORDPRESSDB=$(printf "SHOW DATABASES;\n" | mysql -h $MARIADBIPADDR -u root -p${PASSWORD} | grep wordpress | wc -l)
if [ $WORDPRESSDB -gt 0 ] ; then
  printf "Database 'wordpress' is available\n"
fi

# Check whether the wordpress container is running. If there is an inactive 
# wordpress container remove it first.
WPCOUNT=$(docker ps | awk '{print $NF}' | grep '^wordpress$' | wc -l)
if [ $WPCOUNT -eq 0 ] ; then
  if [ $(docker ps -a | awk '{print $NF}' | grep '^wordpress$' | wc -l) -ne 0 ] ; then
    docker rm wordpress
  fi
  if [ -n "$IPADDR" ] ; then
    INTF80="${IPADDR}:80:"
    INTF443="${IPADDR}:443:"
  else
    INTF80=
    INTF443=
  fi
  docker run -d --name wordpress $ENV -v $WPDIR:/var/www/html:Z -p ${INTF80}80 -p ${INTF443}443 $WPIMAGE
  printf "Creating the wordpress container\n"
  sleep 15
  if [ $(docker ps | awk '{print $NF}' | grep '^wordpress$' | wc -l) -ne 0 ] ; then
    printf "wordpress container ready\n"
  else
    printf "wordpress container creation failed\n"
    exit 1
  fi
fi
WORDPRESSIPADDR=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' wordpress)

# Check whether WordPress is up and running in the container.
curl $WORDPRESSIPADDR -o /dev/null
if [ $? -eq 0 ] ; then
  printf "WordPress ready at the IP address ${WORDPRESSIPADDR}\n"
else
  printf "WordPress start failed\n"
  exit 1
fi

exit 0
