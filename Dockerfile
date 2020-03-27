FROM rocker/verse:3.6.2

USER rstudio

WORKDIR /home/rstudio

COPY . .

RUN build/install-redo
