#!/bin/bash

#
# Detects if system is macOS
#
isMac() {
    if [[ `uname` == "Darwin" ]]; then
        return 0
    else 
        return 1
    fi
}

#
# Detects if system is Linux
#
isLinux() {
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
  if [ $VERBOSE_OUTPUT -eq 1 ]; then
    return
  fi
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
    msg "Installing Homebrew..."

    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    brew tap caskroom/cask

    if [ $? -ne 0 ]; then
        error "Was not able to install Homebrew."
        exit 1
    fi
}

#
# Install ruby envioronment for linux
#
install_rbenv_linux() {
    msg "Installing Ruby..."
    sudo apt update
    git clone git://github.com/sstephenson/rbenv.git ~/.rbenv
    git clone git://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build

    sudo apt-get install -y libreadline-dev

    verbose "Git repos cloned"

    if [ -n "$ZSH_VERSION" ]; then
        echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.zshrc
        echo 'export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"' >> ~/.zshrc
        source ~/.zshrc
    elif [ -n "$BASH_VERSION" ]; then
        echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
        echo 'export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"' >> ~/.bashrc
        source ~/.bashrc
    fi
}

# 
# Install rbenv and ruby-build
# 
install_rbenv () {
    echo '2.3.1' >> ~/.ruby_version
    msg "Installing Ruby-build and rbenv..."

    if isMac;
    then
        brew install ruby ruby-build rbenv
    else 
        install_rbenv_linux
    fi
    msg "installed Ruby"

    if [ -n "$ZSH_VERSION" ]; then
        echo 'eval "$(rbenv init -)"' >> ~/.zshrc
    elif [ -n "$BASH_VERSION" ]; then
        echo 'eval "$(rbenv init -)"' >> ~/.bashrc
    fi

    msg "installing Ruby 2.3.1, this will take a few minutes..."
    CONFIGURE_OPTS="--disable-install-doc --enable-shared" rbenv install 2.3.1

    if [ $? -ne 0 ]; then
        error "Was not able to install rbenv, or rbenv was already installed, will continue with installation."
    fi

    verbose "installed ruby-build and rbenv"
    rbenv global 2.3.1
    eval "$(rbenv init -)"
    rbenv rehash
    source ~/.bashrc
}

# 
# Install postgres
# 
install_postgres () {
    msg "Installing Postgres..."

    if isMac;
    then
        brew cask install postgres --appdir=/Applications

        export PATH=/Applications/Postgres.app/Contents/Versions/*/bin:$PATH

        msg "installed Postgres, should now be on path"
        # TODO replace this with cli open.
        open -a postgres
        sleep 5
        
        if [ $? -ne 0 ]; then
            error "Could not install postgres."
        fi
        verbose "installed postgres"
    else 
        sudo apt-get install -y postgresql \
                        postgresql-contrib \
                        libpq-dev

        msg "Ensure pg_config is on the PATH, and then login to Postgres. You will need to locate where `apt-get` has installed your Postgres binary and add this to your PATH. You can use: whereis psql for that, but ensure you add the directory and not the executable to the path"
        read -p "Press enter to continue"

        export PATH=/usr/bin:$PATH
        sudo -u postgres createuser --superuser $USER
        sudo -u postgres createdb $USER
    fi

    psql -c "CREATE ROLE itig WITH CREATEDB PASSWORD 'd872\$dh' LOGIN;"
    if [ $? -ne 0 ]; then
        error "Could not install postgres. Please ensure psql is on the path, and then rerun this script."
        exit 1
    fi

    verbose "installed Postgres"
}

# 
# Install native tools
# 
install_native_tools () {
    msg "Installing native tools..."
    if isMac; then
        brew install imagemagick libmagic ghostscript
        msg "Trying to install pygments with easy_install, please enter your password"
        sudo easy_install Pygments
    else
        sudo apt-get install -y ghostscript \
                       imagemagick \
                       libmagickwand-dev \
                       libmagic-dev \
                       python-pygments
    fi
    if [ $? -ne 0 ]; then
        error "Could not install native tools, please review the terminal window for details."
        error "Packages may have already been installed, attempting to continue with setup."
    else
        verbose "installed native tools"
    fi
}

# 
# Install doubtfire gem dependencies
# 
install_dfire_dependencies () {
    msg "Installing doubtfire dependencies..."
    gem install bundler
    bundler install --without production replica
    rbenv rehash
    source ~/.bashrc

    msg "Populating database"
    rake db:create
    rake db:populate

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
    msg "Installing DSTIL hooks..."
    curl -s https://raw.githubusercontent.com/dstil/dotfiles/master/bootstrap | bash

    gem install overcommit
    rbenv rehash
    overcommit --install
    dstil --sign

    verbose "installed DSTIL hooks."
}

# 
# Install LaTeX.
# 
install_latex () {
    msg "LaTeX is required for PDF generation, it could take up to several hours to install"
    if isMac; then
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
    verbose "Installed LaTeX"
}

if isMac; then
    install_homebrew
fi

install_rbenv
install_postgres
install_native_tools
install_dfire_dependencies
install_dstil_overcommit
install_latex

msg "You should now be able to launch the server with rails s"
verbose "Doubtfire should be successfuly installed!"

exec $SHELL