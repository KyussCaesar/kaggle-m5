FROM rocker/verse:3.6.2

RUN \
  echo "rstudio ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/rstudio \
  && chmod 0440 /etc/sudoers.d/rstudio

ENV TZ=Pacific/Auckland
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

USER rstudio

WORKDIR /home/rstudio

COPY . .

RUN build/install-system

RUN build/install-redo

ENV R_INSTALL_STAGED=false
RUN build/install-tidyverse
RUN build/install-rpkgs

