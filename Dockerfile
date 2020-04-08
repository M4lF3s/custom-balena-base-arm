FROM balenalib/armv7hf-debian-python:3.7.4-buster-build-20191003

RUN [ "cross-build-start" ]

RUN curl -fsSL https://archive.raspbian.org/raspbian.public.key | apt-key add - && \
    curl -fsSL http://archive.raspberrypi.org/debian/raspberrypi.gpg.key | apt-key add - && \
    echo "deb http://mirrordirector.raspbian.org/raspbian/ stretch main contrib non-free rpi firmware" >> /etc/apt/sources.list && \
    echo "deb http://archive.raspberrypi.org/debian/ stretch main ui" >> /etc/apt/sources.list


RUN apt-get update && apt-get install -yq \
    wget xz-utils lsof \
    libraspberrypi-dev libraspberrypi-bin \
# Kivy dependencies
    libfreetype6-dev libgl1-mesa-dev libgles2-mesa-dev libdrm-dev libgbm-dev libudev-dev libasound2-dev liblzma-dev libjpeg-dev libtiff-dev libwebp-dev git build-essential \
    gir1.2-ibus-1.0 libdbus-1-dev libegl1-mesa-dev libibus-1.0-5 libibus-1.0-dev libice-dev libsm-dev libsndio-dev libwayland-bin libwayland-dev libxi-dev libxinerama-dev libxkbcommon-dev libxrandr-dev libxss-dev libxt-dev libxv-dev x11proto-randr-dev x11proto-scrnsaver-dev x11proto-video-dev x11proto-xinerama-dev \
    pkg-config libgl1-mesa-dev libgles2-mesa-dev mtdev-tools\
    libgstreamer1.0-dev git-core \
    gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly \
    gstreamer1.0-alsa  xclip xsel \
    libjpeg-dev zlib1g-dev \
# Card reader dependencies
    hfsutils hfsprogs exfat-fuse ntfs-3g swig debhelper flex \
    libusb-dev libpcsclite-dev autoconf libtool libpcsclite1 libccid pcscd pcsc-tools \
    libusb-1.0-0-dev libtool libssl-dev cmake checkinstall \
# Supervisor & Redis
    supervisor redis-server ghostscript \
# Clean up apt
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src

### Install SDL2
RUN curl -SL https://libsdl.org/release/SDL2-2.0.10.tar.gz \
    | tar -xzC /usr/src \
    && (cd SDL2-2.0.10 && ./configure --enable-video-kmsdrm --disable-video-opengl --disable-video-x11 --disable-video-rpi) \
    && make -C SDL2-2.0.10 -j$(nproc) \
    && make -C SDL2-2.0.10 install \
    && rm -rf /usr/src/SDL2-2.0.10


### Install SDL2_image
RUN curl -SL https://libsdl.org/projects/SDL_image/release/SDL2_image-2.0.5.tar.gz \
    | tar -xzC /usr/src \
    && (cd SDL2_image-2.0.5 && ./configure) \
    && make -C SDL2_image-2.0.5 -j$(nproc) \
    && make -C SDL2_image-2.0.5 install \
    && rm -rf /usr/src/SDL2_image-2.0.5


### Install SDL2_mixer
RUN curl -SL https://libsdl.org/projects/SDL_mixer/release/SDL2_mixer-2.0.4.tar.gz \
    | tar -xzC /usr/src \
    && (cd SDL2_mixer-2.0.4 && ./configure) \
    && make -C SDL2_mixer-2.0.4 -j$(nproc) \
    && make -C SDL2_mixer-2.0.4 install \
    && rm -rf /usr/src/SDL2_mixer-2.0.4


### Install SDL2_ttf
RUN curl -SL https://libsdl.org/projects/SDL_ttf/release/SDL2_ttf-2.0.15.tar.gz \
    | tar -xzC /usr/src \
    && (cd SDL2_ttf-2.0.15 && ./configure) \
    && make -C SDL2_ttf-2.0.15 -j$(nproc) \
    && make -C SDL2_ttf-2.0.15 install \
    && rm -rf /usr/src/SDL2_ttf-2.0.15


### Update dynamic libraries cache
RUN ldconfig -v


### Install ARM libraries interfacing with Raspberry Pi GPU (kivy depends on EGL)
#WORKDIR /opt/vc
#RUN wget https://github.com/resin-io-playground/userland/releases/download/v0.1/userland-rpi.tar.xz && \
#    tar xf userland-rpi.tar.xz && \
#    rm userland-rpi.tar.xz


### build and install ACR122u card reader dependencies
RUN curl -SL https://github.com/nfc-tools/libnfc/releases/download/libnfc-1.7.0-rc7/libnfc-1.7.0-rc7.tar.gz \
    | tar -xzC /usr/src \
    && (cd /usr/src/libnfc-1.7.0-rc7 && ./configure --with-drivers=acr122_usb) \
    && make -C /usr/src/libnfc-1.7.0-rc7 \
    && sudo make -C /usr/src/libnfc-1.7.0-rc7 install \
    && rm -rf /usr/src/libnfc-1.7.0-rc7
RUN git clone --branch release-1.9.9 --single-branch https://github.com/LudovicRousseau/pyscard.git /usr/src/pyscard \
    && (cd /usr/src/pyscard && python3 setup.py build_ext install) \
    && rm -rf /usr/src/pyscard


### Download and build the redisJSON module
RUN git clone --branch v1.0.4 --single-branch https://github.com/RedisJSON/RedisJSON.git /usr/src/RedisJSON \
    && make -C /usr/src/RedisJSON \
    && cp /usr/src/RedisJSON/src/rejson.so /etc/redis/ \
    && chown redis:redis /etc/redis/rejson.so \
    && rm -rf /usr/src/RedisJSON


### Install python libraries
COPY requirements.txt ./
RUN pip3 install --upgrade pip && \
    pip3 install -r ./requirements.txt


### Build Kivy from current Master
RUN pip3 install git+https://github.com/kivy/kivy.git@master


RUN [ "cross-build-end" ]
