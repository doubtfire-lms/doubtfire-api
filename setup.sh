#!/bin/bash

#
# Detects if system is macOS
#
is_mac() {
    if [[ `uname` == "Darwin" ]]; then
        return 0
    else
        return 1
    fi
}

#
# Detects if system is Linux
#
is_linux() {
    if [[ `uname` == "Linux" ]]; then
        return 0
    else
        return 1
    fi
}

#
# Detects if environment is ZSH
#
is_zsh() {
    if [ -n "$ZSH_VERSION" ]; then
        return 0
    elif [ -n "$BASH_VERSION" ]; then
        return 1
    fi
}

#
# Resets the color
#
msg_reset () {
  RESET='\033[0m'
  printf "${RESET}\n"
}

#
# Log an error
#
error () {
  RED_FORE='\033[0;31m'
  printf "${RED_FORE}ERROR: $1"
  msg_reset
}

#
# Log verbose message
#
verbose () {
  CYAN_FORE='\033[0;36m'
  printf "${CYAN_FORE}INFO: $1"
  msg_reset
}

#
# Log message
#
msg () {
  printf "$1\n"
}

#
# Install Homebrew
#
install_homebrew () {
    command -v brew >/dev/null 2>&1 || {
        msg "Installing Homebrew..."

        /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
        brew tap caskroom/cask

        if [ $? -ne 0 ]; then
            error "Was not able to install Homebrew."
            exit 1
        fi
    }
}

#
# Install Ruby envioronment for linux
#
install_rbenv_linux() {
    msg "Installing Ruby..."
    sudo apt update
    git clone https://github.com/rbenv/rbenv ~/.rbenv/
    git clone https://github.com/rbenv/ruby-build ~/.rbenv/plugins/ruby-build

    verbose "Git repos cloned"

    if [ -n "$ZSH_VERSION" ]; then
        echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.zshrc
        echo 'export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"' >> ~/.zshrc
        source ~/.zshrc
    elif [ -n "$BASH_VERSION" ]; then
        echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
        echo 'export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"' >> ~/.bashrc
        
        # source ~/.bashrc # On Ubuntu, this does not update the shell environment variable in a non-interactive session
        
        export PATH="$HOME/.rbenv/bin:$PATH"
        export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"
    fi
}

#
# Install rbenv and ruby-build
#
install_rbenv () {
    msg "Installing Ruby-build and rbenv..."

    command -v rbenv >/dev/null 2>&1 || {
        if is_mac;
        then
            brew install ruby ruby-build rbenv
        else
            install_rbenv_linux
        fi
        if [ -n "$ZSH_VERSION" ]; then
            echo 'eval "$(rbenv init -)"' >> ~/.zshrc
        elif [ -n "$BASH_VERSION" ]; then
            echo 'eval "$(rbenv init -)"' >> ~/.bashrc
        fi
        verbose "Installed rbenv"
    }

    RUBY_VERSION=$(cat .ruby-version)
    msg "Installing Ruby $RUBY_VERSION, this will take a few minutes..."
    CONFIGURE_OPTS="--disable-install-doc --enable-shared" rbenv install $RUBY_VERSION

    if [ $? -ne 0 ]; then
        error "Was not able to install rbenv, or rbenv was already Installed, will continue with installation."
    fi

    verbose "Installed Ruby-build and rbenv"
    eval "$(rbenv init -)"
    rbenv rehash
}

#
# Install postgres
#
install_postgres () {
    msg "Installing Postgres..."

    if is_mac;
    then
        brew cask install postgres --appdir=/Applications

        export PATH=/Applications/Postgres.app/Contents/Versions/*/bin:$PATH

        verbose "Installed Postgres, should now be on path"

        if [ $? -ne 0 ]; then
            error "Could not install postgres."
        fi
        verbose "Installed postgres"
    else
        sudo apt-get install -y postgresql \
                        postgresql-contrib \
                        libpq-dev

        sudo service postgresql restart

        msg "Ensure pg_config is on the PATH, and then login to Postgres. You will need to locate where `apt-get` has Installed your Postgres binary and add this to your PATH. You can use: whereis psql for that, but ensure you add the directory and not the executable to the path"
        read -p "Press enter to continue"

        export PATH=/usr/bin:$PATH
        sudo -u postgres createuser --superuser $USER
        sudo -u postgres createdb $USER
    fi


    psql -c "DO \$body\$ BEGIN IF NOT EXISTS (SELECT * FROM pg_catalog.pg_user WHERE  usename = 'itig') THEN CREATE ROLE itig WITH CREATEDB PASSWORD 'd872\$dh' LOGIN; END IF; END \$body\$;"

    if [ $? -ne 0 ]; then
        error "Could not install postgres. Please ensure psql is on the path, and then rerun this script."
        exit 1
    fi

    verbose "Installed Postgres"
}

#
# Install native tools
#
install_native_tools () {
    msg "Installing native tools..."
    if is_mac; then
        brew install imagemagick@6 libmagic ghostscript ffmpeg
        brew link --force imagemagick@6
        msg "Trying to install pygments with easy_install, please enter your password"
        sudo easy_install Pygments
    else
        sudo apt-get install -y ghostscript \
                       imagemagick \
                       libmagickwand-dev \
                       libmagic-dev \
                       python-pygments \
                       ffmpeg \
                       curl \
		       libreadline-dev \
		       gcc \
		       make \
		       libssl1.0-dev \
		       zlib1g-dev
    fi
    if [ $? -ne 0 ]; then
        error "Could not install native tools, please review the terminal window for details."
        error "Packages may have already been Installed, attempting to continue with setup."
    else
        verbose "Installed native tools"
    fi
}

#
# Install Doubtfire gem dependencies
#
install_dfire_dependencies () {
    msg "Installing Doubtfire dependencies..."
    gem install bundler -v 1.17.3
    bundler install --without production replica staging
    rbenv rehash
    source ~/.bashrc

    msg "Populating database"
    bundle exec rake db:create
    bundle exec rake db:populate

    if [ $? -ne 0 ]; then
        error "Could not populate database."
        exit 1
    fi

    verbose "populated database"
}

#
# Install Overcommit and DSTIL hooks.
#
install_dstil_overcommit () {

    gem install overcommit -v 0.47.0
    rbenv rehash
    overcommit --install

    verbose "Installed overcommit hooks."
}

#
# Install LaTeX.
#
install_latex () {
    msg "LaTeX is required for PDF generation, it could take up to several hours to install"
    if is_mac; then
        read -r -p "Would you like to install LaTeX now? [y/N] " response
        case $response in
            [yY][eE][sS]|[yY])
                brew cask install mactex
                ;;
            *)
                msg "You will not be able to generate PDF's without LaTeX"
                ;;
        esac
    else
        sudo apt-get install texlive-full
    fi
    if [ $? -ne 0 ]; then
        error "Could not install LaTeX."
        exit 1
    fi
    verbose "Installed LaTeX"
}

if is_mac; then
    install_homebrew
fi

install_native_tools
install_rbenv
install_postgres
install_dstil_overcommit
install_dfire_dependencies
install_latex

msg "You should now be able to launch the server with bundle exec rails s"
verbose "Doubtfire should be successfuly Installed!"

exec $SHELL
