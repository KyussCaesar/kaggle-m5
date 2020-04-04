FROM rocker/verse:3.6.2

RUN \
  echo "rstudio ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/rstudio \
  && chmod 0440 /etc/sudoers.d/rstudio

ENV TZ=Pacific/Auckland
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Configure session timeout: disabled
RUN echo "session-timeout-minutes=0" >>/etc/rstudio/rsession.conf

USER rstudio

WORKDIR /home/rstudio
RUN mkdir build

COPY build/install-redo build/install-redo
RUN build/install-redo

COPY build/install-system build/install-system
RUN build/install-system

ENV R_INSTALL_STAGED=false R_ENABLE_JIT=3

COPY rpkgs.R rpkgs.R
COPY build/install-rpkgs build/install-rpkgs
RUN INSTALLING_PACKAGES=true build/install-rpkgs
RUN R -e 'keras::install_keras(tensorflow = "gpu")'

