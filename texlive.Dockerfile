FROM texlive/texlive:latest

RUN apt-get update \
    && apt-get install -y \
    imagemagick \
    inkscape \
    librsvg2-bin \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy in Latex build script, along with asset images
COPY ./lib/shell/latex_build.sh /texlive/shell/latex_build.sh
COPY ./public/assets/images /doubtfire/public/assets/images

RUN chmod +x /texlive/shell/latex_build.sh

CMD ["sh", "-c", "sleep infinity"]
