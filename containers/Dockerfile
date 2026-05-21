FROM rocker/r-base:4.5.3

ENV CRAN_MIRROR=https://packagemanager.posit.co/cran/__linux__/bookworm/latest

# Set HTTPUserAgent so PPM can identify the platform and serve pre-compiled packages
RUN Rscript -e 'cat("options(HTTPUserAgent = sprintf(\"R/%s R (%s)\", getRversion(), paste(getRversion(), R.version[\"platform\"], R.version[\"arch\"], R.version[\"os\"])))\n", file = file.path(R.home("etc"), "Rprofile.site"), append = TRUE)'

# System libraries needed for compilation (fallback) and runtime linking
RUN apt-get update && apt-get install -y --no-install-recommends \
        libcurl4-openssl-dev \
        libssl-dev \
        libxml2-dev \
        libicu-dev \
    && rm -rf /var/lib/apt/lists/* && \
    \
    Rscript -e "install.packages('remotes', repos = Sys.getenv('CRAN_MIRROR'))"

COPY httkqsprs/ /pkg/httkqsprs/
COPY containers/entrypoint.R /entrypoint.R

# Reads DESCRIPTION and installs all Imports/Depends automatically
# the binary stringi fails so we compile from source,
# then finally install httkqsprs again
RUN Rscript -e "install.packages('stringi', repos = 'https://cloud.r-project.org', type = 'source')" && \
    Rscript -e "remotes::install_local('/pkg/httkqsprs', dependencies = TRUE, repos = Sys.getenv('CRAN_MIRROR'))"

ENTRYPOINT ["Rscript", "/entrypoint.R"]
