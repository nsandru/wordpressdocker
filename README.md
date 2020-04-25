

# WordPress docker build script

**Usage guide**

The WordPress Docker build script produces two Docker containers, one containing a WordPress server (*wordpress*) and another one containing a MariaDB database (*mariadb*).

**Requirements**

- A system with the Docker software installed
- A directory for the WordPress installation to be mounted on the *wordpress* container
- A directory for the MariaDB database to be mounted on the *mariadb* container
- For migrating or restoring a site: a ZIP file with the site conent generated with the *WP Clone* WordPress plugin

**Running the script**

Before running the script check the '`declare -a IMAGES=...`' line. Currently it is set to select the *wordpress:5.3.2* and *mariadb:10.3* docker images and it can be edited to select other versions of the images.

The script is started with the following command line:
    
        $ wordpress_docker.sh WORDPRESS_DIR DATABASE_DIR [IP_Address]

where:

- WORDPRESS_DIR is the volume where the wordpress site resides.
- DATABASE_DIR is the volume where the database reesides
- IP_Address is the IP Address of the *wordpress* container for access the WordPress site from outside the container (optional)

If the IP address is not specified then the *wordpress* container is assigned a default address by Docker.

Requirements for the build:

- The directories mentioned above
- The site content, including the database, in a ZIP file (if the site is to be migrated/restored)

The script prompts for a database password to be set if the database has to be created. This password is needed for subsequent runs of the script and during the WordPress database configuration.

The script pulls the *wordpress* and *mariadb* images specified in the IMAGES array if necessary and starts the containers from these images.

The script checks whether the containers *mariadb* and *wordpress* are already running so that it doesn't relaunch them. If these containers are inactive (exited) they are removed and new containers are launched.

The MariaDB database is initialized (if not already present) with a database named *wordpress*, user *root* and the password set previously. The database resides in the DATABASE_DIR which is mounted as volume on the *mariadb* container.

The *wordpress* container is started with a fresh WordPress installation if it doesn't exist already.

Both the *mariadb* and *wordpress* containers are checked after startup whether they are ready.

If the wordpress container start is succesfull the message:
    


       WordPress ready at the IP address IP_Address

where IP_Address is the address assigned to the container.

**Next step**

Log on with a browser to the *wordpress* container at the IP address provided by the script.

If it is a new installation: set the WordPress database access parameters:

        database:     wordpress
        user:         root
        password:     database access password
        table prefix: the table prefix for the particular site, more than one prefix can be listed

The WordPress is ready to build a new site.

**Restoring a site**

Install the *WP Clone* WordPress plugin if it's not already installed.

Make the backup available for *WP Clone*. It consists of two files, a .zip file that conatins the backup proper and a .log file. Copy the two files to the `wp-content/uploads/wp-clone` directory on the volume mounted to the *wordpress* container.

Follow the instructions in the *WP Clone* plugin to select and unpack the ZIP file.

