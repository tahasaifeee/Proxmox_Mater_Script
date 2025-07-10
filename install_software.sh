#!/bin/bash

# Function to detect the package manager
detect_pkg_manager() {
    if [ -x "$(command -v apt-get)" ]; then
        PKG_MANAGER="apt"
    elif [ -x "$(command -v dnf)" ]; then
        PKG_MANAGER="dnf"
    elif [ -x "$(command -v yum)" ]; then
        PKG_MANAGER="yum"
    else
        echo "Unsupported package manager. This script supports apt, dnf, and yum."
        exit 1
    fi
}

# Function to install Docker
install_docker() {
    echo "Installing Docker..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo apt-get update
        sudo apt-get install -y docker.io
    elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
        sudo yum install -y yum-utils
        sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        sudo yum install -y docker-ce docker-ce-cli containerd.io
    fi
    sudo systemctl start docker
    sudo systemctl enable docker
    echo "Docker installed successfully."
}

# Function to install Docker with Docker Compose
install_docker_compose() {
    install_docker
    echo "Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo "Docker Compose installed successfully."
}

# Function to install Apache
install_apache() {
    echo "Installing Apache..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo apt-get update
        sudo apt-get install -y apache2
    elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
        sudo yum install -y httpd
    fi
    sudo systemctl start apache2 || sudo systemctl start httpd
    sudo systemctl enable apache2 || sudo systemctl enable httpd
    echo "Apache installed successfully."
}

# Function to install Nginx
install_nginx() {
    echo "Installing Nginx..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo apt-get update
        sudo apt-get install -y nginx
    elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
        sudo yum install -y nginx
    fi
    sudo systemctl start nginx
    sudo systemctl enable nginx
    echo "Nginx installed successfully."
}

# Function to install .NET SDK
install_dotnet() {
    echo "Installing .NET SDK..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo apt-get update
        sudo apt-get install -y dotnet-sdk-6.0
    elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
        sudo yum install -y dotnet-sdk-6.0
    fi
    echo ".NET SDK installed successfully."
}

# Function to install MariaDB
install_mariadb() {
    echo "Installing MariaDB..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo apt-get update
        sudo apt-get install -y mariadb-server
    elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
        sudo yum install -y mariadb-server
    fi
    sudo systemctl start mariadb
    sudo systemctl enable mariadb
    echo "MariaDB installed successfully."

    echo "\n--- Configuring MariaDB ---"
    read -s -p "Enter MariaDB root password: " MARIADB_ROOT_PASS
    echo
    sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MARIADB_ROOT_PASS'; FLUSH PRIVILEGES;"
    echo "MariaDB root password set."

    read -p "Enter a new database name for MariaDB: " MARIADB_DB_NAME
    sudo mysql -e "CREATE DATABASE IF NOT EXISTS $MARIADB_DB_NAME;"
    echo "Database '$MARIADB_DB_NAME' created."
    echo "For full production hardening, please run 'sudo mysql_secure_installation' manually."
}

# Function to install PostgreSQL
install_postgresql() {
    echo "Installing PostgreSQL..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo apt-get update
        sudo apt-get install -y postgresql postgresql-contrib
    elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
        sudo yum install -y postgresql-server
        sudo postgresql-setup initdb
    fi
    sudo systemctl start postgresql
    sudo systemctl enable postgresql
    echo "PostgreSQL installed successfully."

    echo "\n--- Configuring PostgreSQL ---"
    read -p "Enter a new database name for PostgreSQL: " PG_DB_NAME
    sudo -u postgres psql -c "CREATE DATABASE $PG_DB_NAME;"
    echo "Database '$PG_DB_NAME' created."

    read -p "Enter a new username for PostgreSQL: " PG_USER
    read -s -p "Enter password for $PG_USER: " PG_PASS
    echo
    sudo -u postgres psql -c "CREATE USER $PG_USER WITH PASSWORD '$PG_PASS';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $PG_DB_NAME TO $PG_USER;"
    echo "User '$PG_USER' created and granted privileges on '$PG_DB_NAME'."
    echo "For remote access, you may need to edit /etc/postgresql/*/main/pg_hba.conf and postgresql.conf."
}

# Function to install InfluxDB
install_influxdb() {
    echo "Installing InfluxDB..."
    if [ "$PKG_MANAGER" = "apt" ];then
        curl -sL https://repos.influxdata.com/influxdb.key | sudo apt-key add -
        echo "deb https://repos.influxdata.com/ubuntu bionic stable" | sudo tee /etc/apt/sources.list.d/influxdb.list
        sudo apt-get update
        sudo apt-get install -y influxdb
    elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
        cat <<EOF | sudo tee /etc/yum.repos.d/influxdb.repo
[influxdb]
name = InfluxDB Repository
baseurl = https://repos.influxdata.com/rhel/\$releasever/\$basearch/stable
enabled = 1
gpgcheck = 1
gpgkey = https://repos.influxdata.com/influxdb.key
EOF
        sudo yum install -y influxdb
    fi
    sudo systemctl start influxdb
    sudo systemctl enable influxdb
    echo "InfluxDB installed successfully."

    echo "\n--- Configuring InfluxDB ---"
    echo "Please create an admin user, organization, and bucket using the 'influx' CLI after installation."
    echo "Example: influx setup"
    echo "For production hardening, review /etc/influxdb/influxdb.conf for authentication and HTTPS settings."
}

# Function to install Kubernetes (Minikube)
install_kubernetes() {
    echo "Installing Kubernetes (Minikube)..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo apt-get update
        sudo apt-get install -y curl
        curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
        sudo install minikube-linux-amd64 /usr/local/bin/minikube
    elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
        curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
        sudo install minikube-linux-amd64 /usr/local/bin/minikube
    fi
    echo "Minikube installed successfully. You can now start a Kubernetes cluster with 'minikube start'"
}

# Function to install MySQL
install_mysql() {
    echo "Installing MySQL..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo apt-get update
        sudo apt-get install -y mysql-server
    elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
        sudo yum install -y mysql-server
    fi
    sudo systemctl start mysql
    sudo systemctl enable mysql
    echo "MySQL installed successfully."

    echo "\n--- Configuring MySQL ---"
    read -s -p "Enter MySQL root password: " MYSQL_ROOT_PASS
    echo
    sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS'; FLUSH PRIVILEGES;"
    echo "MySQL root password set."

    read -p "Enter a new database name for MySQL: " MYSQL_DB_NAME
    sudo mysql -e "CREATE DATABASE IF NOT EXISTS $MYSQL_DB_NAME;"
    echo "Database '$MYSQL_DB_NAME' created."
    echo "For full production hardening, please run 'sudo mysql_secure_installation' manually."
}

# Function to install MongoDB
install_mongodb() {
    echo "Installing MongoDB..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo apt-get update
        sudo apt-get install -y gnupg curl
        curl -fsSL https://www.mongodb.org/static/pgp/server-6.0.asc | sudo gpg --dearmor -o /usr/share/keyrings/mongodb-archive-keyring.gpg
        echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-archive-keyring.gpg ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
        sudo apt-get update
        sudo apt-get install -y mongodb-org
    elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
        cat <<EOF | sudo tee /etc/yum.repos.d/mongodb-org-6.0.repo
[mongodb-org-6.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/6.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-6.0.asc
EOF
        sudo yum install -y mongodb-org
    fi
    sudo systemctl start mongod
    sudo systemctl enable mongod
    echo "MongoDB installed successfully."

    echo "\n--- Configuring MongoDB ---"
    echo "For production hardening, please configure authentication and user roles."
    echo "Refer to MongoDB documentation for details on creating admin users and enabling authentication."
}

# Function to install MSSQL Express (on Linux)
install_mssql_express() {
    echo "Installing MSSQL Express on Linux..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo apt-get update
        sudo apt-get install -y curl apt-transport-https
        curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
        sudo add-apt-repository "$(wget -qO- https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/mssql-server-2019.list)"
        sudo apt-get update
        sudo apt-get install -y mssql-server
    elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
        sudo curl -o /etc/yum.repos.d/mssql-server.repo https://packages.microsoft.com/config/rhel/8/mssql-server-2019.repo
        sudo yum install -y mssql-server
    fi
    echo "MSSQL Server installed. Now, run the setup to configure it."
    echo "You will be prompted to accept the license terms and set the SA password."
    sudo /opt/mssql/bin/mssql-conf setup
    sudo systemctl start mssql-server
    sudo systemctl enable mssql-server
    echo "MSSQL Express installed and configured. Remember to open firewall ports if needed."
}

# PHP Installation Functions
install_php_version() {
    local version=$1
    echo "Installing PHP $version..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo apt-get update
        sudo apt-get install -y software-properties-common
        sudo add-apt-repository -y ppa:ondrej/php
        sudo apt-get update
        sudo apt-get install -y php$version php$version-cli php$version-common php$version-mysql php$version-xml php$version-mbstring php$version-fpm php$version-zip
    elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
        sudo yum install -y yum-utils
        sudo yum install -y https://rpms.remirepo.net/enterprise/remi-release-$(rpm -E %rhel).rpm
        sudo yum-config-manager --enable remi-php$version
        sudo yum install -y php php-cli php-common php-mysqlnd php-xml php-mbstring php-fpm php-zip
    fi
    echo "PHP $version installed successfully."
}

# MySQL Version Installation Functions
install_mysql_version() {
    local version=$1
    echo "Installing MySQL $version..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        wget https://dev.mysql.com/get/mysql-apt-config_0.8.22-1_all.deb
        sudo dpkg -i mysql-apt-config_0.8.22-1_all.deb
        rm mysql-apt-config_0.8.22-1_all.deb
        # During dpkg -i, it will ask for version. User needs to select it manually.
        echo "Please select MySQL Server version $version during the interactive setup."
        sudo apt-get update
        sudo apt-get install -y mysql-server
    elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
        sudo dnf install -y https://dev.mysql.com/get/mysql80-community-release-el8-1.noarch.rpm # Adjust for specific RHEL/CentOS version
        sudo yum install -y mysql-community-server
    fi
    sudo systemctl start mysqld
    sudo systemctl enable mysqld
    echo "MySQL $version installed successfully."
    echo "\n--- Configuring MySQL $version ---"
    read -s -p "Enter MySQL root password: " MYSQL_ROOT_PASS
    echo
    sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS'; FLUSH PRIVILEGES;"
    echo "MySQL root password set."
    read -p "Enter a new database name for MySQL: " MYSQL_DB_NAME
    sudo mysql -e "CREATE DATABASE IF NOT EXISTS $MYSQL_DB_NAME;"
    echo "Database '$MYSQL_DB_NAME' created."
    echo "For full production hardening, please run 'sudo mysql_secure_installation' manually."
}

# MariaDB Version Installation Functions
install_mariadb_version() {
    local version=$1
    echo "Installing MariaDB $version..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo apt-get update
        sudo apt-get install -y software-properties-common
        sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD10C
        sudo add-apt-repository "deb [arch=amd64,arm64,ppc64el] http://mirror.mariadb.org/repo/\$version/ubuntu $(lsb_release -cs) main"
        sudo apt-get update
        sudo apt-get install -y mariadb-server
    elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
        cat <<EOF | sudo tee /etc/yum.repos.d/MariaDB.repo
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/\$version/centos$(rpm -E %rhel)/x86_64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
enabled=1
EOF
        sudo yum install -y MariaDB-server MariaDB-client
    fi
    sudo systemctl start mariadb
    sudo systemctl enable mariadb
    echo "MariaDB $version installed successfully."
    echo "\n--- Configuring MariaDB $version ---"
    read -s -p "Enter MariaDB root password: " MARIADB_ROOT_PASS
    echo
    sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MARIADB_ROOT_PASS'; FLUSH PRIVILEGES;"
    echo "MariaDB root password set."
    read -p "Enter a new database name for MariaDB: " MARIADB_DB_NAME
    sudo mysql -e "CREATE DATABASE IF NOT EXISTS $MARIADB_DB_NAME;"
    echo "Database '$MARIADB_DB_NAME' created."
    echo "For full production hardening, please run 'sudo mysql_secure_installation' manually."
}

# PostgreSQL Version Installation Functions
install_postgresql_version() {
    local version=$1
    echo "Installing PostgreSQL $version..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
        wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
        sudo apt-get update
        sudo apt-get install -y postgresql-$version postgresql-contrib-$version
    elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
        sudo yum install -y postgresql$version-server
        sudo /usr/pgsql-$version/bin/postgresql-$version-setup initdb
    fi
    sudo systemctl start postgresql-$version
    sudo systemctl enable postgresql-$version
    echo "PostgreSQL $version installed successfully."
    echo "\n--- Configuring PostgreSQL $version ---"
    read -p "Enter a new database name for PostgreSQL: " PG_DB_NAME
    sudo -u postgres psql -c "CREATE DATABASE $PG_DB_NAME;"
    echo "Database '$PG_DB_NAME' created."
    read -p "Enter a new username for PostgreSQL: " PG_USER
    read -s -p "Enter password for $PG_USER: " PG_PASS
    echo
    sudo -u postgres psql -c "CREATE USER $PG_USER WITH PASSWORD '$PG_PASS';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $PG_DB_NAME TO $PG_USER;"
    echo "User '$PG_USER' created and granted privileges on '$PG_DB_NAME'."
    echo "For remote access, you may need to edit /etc/postgresql/$version/main/pg_hba.conf and postgresql.conf."
}

# Node.js Installation Functions (using NVM)
install_nodejs_version() {
    local version=$1
    echo "Installing Node.js $version using NVM..."
    if [ ! -d "$HOME/.nvm" ]; then
        echo "Installing NVM..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
    else
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    fi

    nvm install $version
    nvm use $version
    nvm alias default $version
    echo "Node.js $version installed and set as default."
    echo "Please remember to run 'source ~/.bashrc' or 'source ~/.zshrc' (or your shell's equivalent) after this script finishes to load NVM into your current session."
}

# Function to install Grafana
install_grafana() {
    echo "Installing Grafana..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo apt-get install -y apt-transport-https software-properties-common wget
        sudo wget -q -O /usr/share/keyrings/grafana.key https://apt.grafana.com/gpg.key
        echo "deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
        sudo apt-get update
        sudo apt-get install -y grafana
    elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
        sudo wget -q -O /etc/yum.repos.d/grafana.repo https://rpm.grafana.com/rpm.repo
        sudo rpm --import https://rpm.grafana.com/gpg.key
        sudo yum install -y grafana
    fi
    sudo systemctl daemon-reload
    sudo systemctl start grafana-server
    sudo systemctl enable grafana-server
    echo "Grafana installed successfully. Access it at http://localhost:3000"
    echo "Default login: admin/admin. You will be prompted to change the password on first login."
}

# Function to install Packer
install_packer() {
    echo "Installing Packer..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
        wget -O- https://apt.releases.hashicorp.com/gpg | \
            gpg --dearmor | \
            sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
        gpg --no-default-keyring \
            --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg \
            --fingerprint
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
            https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
            sudo tee /etc/apt/sources.list.d/hashicorp.list
        sudo apt update
        sudo apt-get install -y packer
    elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
        sudo yum install -y yum-utils
        sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
        sudo yum -y install packer
    fi
    echo "Packer installed successfully."
}

# Function to install Terraform
install_terraform() {
    echo "Installing Terraform..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
        wget -O- https://apt.releases.hashicorp.com/gpg | \
            gpg --dearmor | \
            sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
        gpg --no-default-keyring \
            --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg \
            --fingerprint
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
            https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
            sudo tee /etc/apt/sources.list.d/hashicorp.list
        sudo apt update
        sudo apt-get install -y terraform
    elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
        sudo yum install -y yum-utils
        sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
        sudo yum -y install terraform
    fi
    echo "Terraform installed successfully."
}

# Function to install AWS CLI
install_aws_cli() {
    echo "Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    sudo apt-get install -y unzip # Ensure unzip is available
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf awscliv2.zip aws
    echo "AWS CLI installed successfully."
    echo "Run 'aws configure' to set up your credentials."
}

# Function to install Azure CLI
install_azure_cli() {
    echo "Installing Azure CLI..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl apt-transport-https lsb-release gnupg
        sudo mkdir -p /etc/apt/keyrings
        curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/microsoft.gpg > /dev/null
        AZ_REPO=$(lsb_release -cs)
        echo "deb [arch=`dpkg --print-architecture` signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
        sudo apt-get update
        sudo apt-get install -y azure-cli
    elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
        sudo sh -c 'echo -e "[azure-cli]\nname=Azure CLI\nbaseurl=https://packages.microsoft.com/yumrepos/azure-cli\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/azure-cli.repo'
        sudo yum install -y azure-cli
    fi
    echo "Azure CLI installed successfully."
    echo "Run 'az login' to authenticate."
}

# Function to install GCP CLI
install_gcp_cli() {
    echo "Installing Google Cloud CLI (gcloud)..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo apt-get update
        sudo apt-get install -y apt-transport-https ca-certificates gnupg curl
        echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
        curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
        sudo apt-get update
        sudo apt-get install -y google-cloud-cli
    elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
        sudo tee -a /etc/yum.repos.d/google-cloud-sdk.repo << EOM
[google-cloud-sdk]
name=Google Cloud SDK
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el8-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOM
        sudo yum install -y google-cloud-cli
    fi
    echo "Google Cloud CLI (gcloud) installed successfully."
    echo "Run 'gcloud init' to initialize."
}

# Main menu
main_menu() {
    detect_pkg_manager
    echo "Please choose an option to install:"
    echo "1. Docker"
    echo "2. Docker with Docker Compose"
    echo "3. Apache"
    echo "4. Nginx"
    echo "5. .NET"
    echo "6. MariaDB (Default Version)"
    echo "7. PostgreSQL (Default Version)"
    echo "8. InfluxDB"
    echo "9. Kubernetes (Minikube)"
    echo "10. MySQL (Default Version)"
    echo "11. MongoDB"
    echo "12. MSSQL Express (Linux)"
    echo "13. PHP 7.4"
    echo "14. PHP 8.1"
    echo "15. PHP 8.2"
    echo "16. PHP 8.3"
    echo "17. MySQL 5.7"
    echo "18. MySQL 8.0"
    echo "19. MariaDB 10.6"
    echo "20. MariaDB 10.11"
    echo "21. PostgreSQL 14"
    echo "22. PostgreSQL 15"
    echo "23. PostgreSQL 16"
    echo "24. Node.js 18.x (LTS)"
    echo "25. Node.js 20.x (LTS)"
    echo "26. Node.js 22.x (LTS)"
    echo "27. Grafana"
    echo "28. Packer"
    echo "29. Terraform"
    echo "30. AWS CLI"
    echo "31. Azure CLI"
    echo "32. GCP CLI"
    echo "33. Exit"
    read -p "Enter your choice [1-33]: " choice

    case $choice in
        1) install_docker ;;
        2) install_docker_compose ;;
        3) install_apache ;;
        4) install_nginx ;;
        5) install_dotnet ;;
        6) install_mariadb ;;
        7) install_postgresql ;;
        8) install_influxdb ;;
        9) install_kubernetes ;;
        10) install_mysql ;;
        11) install_mongodb ;;
        12) install_mssql_express ;;
        13) install_php_version 7.4 ;;
        14) install_php_version 8.1 ;;
        15) install_php_version 8.2 ;;
        16) install_php_version 8.3 ;;
        17) install_mysql_version 5.7 ;;
        18) install_mysql_version 8.0 ;;
        19) install_mariadb_version 10.6 ;;
        20) install_mariadb_version 10.11 ;;
        21) install_postgresql_version 14 ;;
        22) install_postgresql_version 15 ;;
        23) install_postgresql_version 16 ;;
        24) install_nodejs_version 18 ;;
        25) install_nodejs_version 20 ;;
        26) install_nodejs_version 22 ;;
        27) install_grafana ;;
        28) install_packer ;;
        29) install_terraform ;;
        30) install_aws_cli ;;
        31) install_azure_cli ;;
        32) install_gcp_cli ;;
        33) exit 0 ;;
        *) echo "Invalid option. Please try again." ;;
    esac
}

main_menu
