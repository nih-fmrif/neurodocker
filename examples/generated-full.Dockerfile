# Generated by Neurodocker v0.2.0-dev.
#
# Thank you for using Neurodocker. If you discover any issues 
# or ways to improve this software, please submit an issue or 
# pull request on our GitHub repository:
#     https://github.com/kaczmarj/neurodocker
#
# Timestamp: 2017-07-31 19:03:56

FROM debian:stretch

ARG DEBIAN_FRONTEND=noninteractive

#----------------------------------------------------------
# Install common dependencies and create default entrypoint
#----------------------------------------------------------
ENV LANG="C.UTF-8" \
    LC_ALL="C" \
    ND_ENTRYPOINT="/neurodocker/startup.sh"
RUN apt-get update -qq && apt-get install -yq --no-install-recommends  \
    	bzip2 ca-certificates curl unzip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && chmod 777 /opt && chmod a+s /opt \
    && mkdir /neurodocker \
    && echo '#!/usr/bin/env bash' >> $ND_ENTRYPOINT \
    && echo 'set +x' >> $ND_ENTRYPOINT \
    && echo 'if [ -z "$*" ]; then /usr/bin/env bash; else $*; fi' >> $ND_ENTRYPOINT \
    && chmod -R 777 /neurodocker && chmod a+s /neurodocker
ENTRYPOINT ["/neurodocker/startup.sh"]

RUN apt-get update -qq && apt-get install -yq --no-install-recommends git vim \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

#--------------------
# Install AFNI latest
#--------------------
ENV PATH=/opt/afni:$PATH
RUN apt-get update -qq && apt-get install -yq --no-install-recommends ed gsl-bin libglu1-mesa-dev libglib2.0-0 libglw1-mesa \
    libgomp1 libjpeg62 libxm4 netpbm tcsh xfonts-base xvfb \
    && libs_path=/usr/lib/x86_64-linux-gnu \
    && if [ -f $libs_path/libgsl.so.19 ]; then \
           ln $libs_path/libgsl.so.19 $libs_path/libgsl.so.0; \
       fi \
    # Install libxp (not in all ubuntu/debian repositories) \
    && apt-get install -yq --no-install-recommends libxp6 \
    || /bin/bash -c " \
       curl --retry 5 -o /tmp/libxp6.deb -sSL http://mirrors.kernel.org/debian/pool/main/libx/libxp/libxp6_1.0.2-2_amd64.deb \
       && dpkg -i /tmp/libxp6.deb && rm -f /tmp/libxp6.deb" \
    # Install libpng12 (not in all ubuntu/debian repositories) \
    && apt-get install -yq --no-install-recommends libpng12-0 \
    || /bin/bash -c " \
       curl -o /tmp/libpng12.deb -sSL http://mirrors.kernel.org/debian/pool/main/libp/libpng/libpng12-0_1.2.49-1%2Bdeb7u2_amd64.deb \
       && dpkg -i /tmp/libpng12.deb && rm -f /tmp/libpng12.deb" \
    # Install R \
    && apt-get install -yq --no-install-recommends \
    	r-base-dev r-cran-rmpi \
     || /bin/bash -c " \
        curl -o /tmp/install_R.sh -sSL https://gist.githubusercontent.com/kaczmarj/8e3792ae1af70b03788163c44f453b43/raw/0577c62e4771236adf0191c826a25249eb69a130/R_installer_debian_ubuntu.sh \
        && /bin/bash /tmp/install_R.sh" \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && echo "Downloading AFNI ..." \
    && mkdir -p /opt/afni \
    && curl -sSL --retry 5 https://afni.nimh.nih.gov/pub/dist/tgz/linux_openmp_64.tgz \
    | tar zx -C /opt/afni --strip-components=1 \
    && /opt/afni/rPkgsInstall -pkgs ALL \
    && rm -rf /tmp/*

#-------------------
# Install ANTs 2.1.0
#-------------------
RUN echo "Downloading ANTs ..." \
    && curl -sSL --retry 5 https://dl.dropbox.com/s/h8k4v6d1xrv0wbe/ANTs-Linux-centos5_x86_64-v2.1.0-78931aa.tar.gz \
    | tar zx -C /opt
ENV ANTSPATH=/opt/ants \
    PATH=/opt/ants:$PATH

#--------------------------
# Install FreeSurfer v6.0.0
#--------------------------
# Install version minimized for recon-all
# See https://github.com/freesurfer/freesurfer/issues/70
RUN apt-get update -qq && apt-get install -yq --no-install-recommends bc libgomp1 libxmu6 libxt6 tcsh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && echo "Downloading minimized FreeSurfer ..." \
    && curl -sSL https://dl.dropbox.com/s/nnzcfttc41qvt31/recon-all-freesurfer6-3.min.tgz | tar xz -C /opt \
    && sed -i '$isource $FREESURFER_HOME/SetUpFreeSurfer.sh' $ND_ENTRYPOINT
ENV FREESURFER_HOME=/opt/freesurfer

#-----------------------------------------------------------
# Install FSL v5.0.10
# FSL is non-free. If you are considering commerical use
# of this Docker image, please consult the relevant license:
# https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/Licence
#-----------------------------------------------------------
RUN echo "Downloading FSL ..." \
    && curl -sSL https://fsl.fmrib.ox.ac.uk/fsldownloads/fsl-5.0.10-centos6_64.tar.gz \
    | tar zx -C /opt \
    && /bin/bash /opt/fsl/etc/fslconf/fslpython_install.sh -q -f /opt/fsl \
    && sed -i '$iecho Some packages in this Docker container are non-free' $ND_ENTRYPOINT \
    && sed -i '$iecho If you are considering commercial use of this container, please consult the relevant license:' $ND_ENTRYPOINT \
    && sed -i '$iecho https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/Licence' $ND_ENTRYPOINT \
    && sed -i '$isource $FSLDIR/etc/fslconf/fsl.sh' $ND_ENTRYPOINT
ENV FSLDIR=/opt/fsl \
    PATH=/opt/fsl/bin:$PATH

# Create new user: neuro
RUN useradd --no-user-group --create-home --shell /bin/bash neuro
USER neuro

#------------------
# Install Miniconda
#------------------
ENV CONDA_DIR=/opt/conda \
    PATH=/opt/conda/bin:$PATH
RUN echo "Downloading Miniconda installer ..." \
    && miniconda_installer=/tmp/miniconda.sh \
    && curl -sSL -o $miniconda_installer https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh \
    && /bin/bash $miniconda_installer -f -b -p $CONDA_DIR \
    && rm -f $miniconda_installer \
    && conda config --system --prepend channels conda-forge \
    && conda config --system --set auto_update_conda false \
    && conda config --system --set show_channel_urls true \
    && conda update -y --all \
    && conda clean -tipsy \
    && find /opt/conda -name ".wh*" -exec rm {} +

#-------------------------
# Create conda environment
#-------------------------
RUN conda create -y -q --name default python=3.5.1 \
    	traits pandas \
    && conda clean -tipsy \
    && /bin/bash -c "source activate default \
    	&& pip install -q --no-cache-dir \
    	nipype" \
    && find /opt/conda -name ".wh*" -exec rm {} +
ENV PATH=/opt/conda/envs/default/bin:$PATH

#-------------------------
# Create conda environment
#-------------------------
RUN conda create -y -q --name py27 python=2.7 \
    && conda clean -tipsy \
    && find /opt/conda -name ".wh*" -exec rm {} +

USER root

#----------------
# Install MRtrix3
#----------------
RUN echo "Downloading MRtrix3 ..." \
    && curl -sSL --retry 5 https://dl.dropbox.com/s/2g008aaaeht3m45/mrtrix3-Linux-centos6.tar.gz \
    | tar zx -C /opt
ENV PATH=/opt/mrtrix3/bin:$PATH

#--------------------------------------------------
# Add NeuroDebian repository
# Please note that some packages downloaded through
# NeuroDebian may have restrictive licenses.
#--------------------------------------------------
RUN apt-get update -qq && apt-get install -yq --no-install-recommends dirmngr gnupg \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && curl -sSL http://neuro.debian.net/lists/jessie.us-nh.full \
    > /etc/apt/sources.list.d/neurodebian.sources.list \
    && apt-key adv --fetch-keys https://dl.dropbox.com/s/zxs209o955q6vkg/neurodebian.gpg \
    && (apt-key adv --refresh-keys --keyserver hkp://pool.sks-keyservers.net:80 0xA5D32F012649A5A9 || true) \
    && apt-get update

# Install NeuroDebian packages
RUN apt-get update -qq && apt-get install -yq --no-install-recommends dcm2niix \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

#----------------------
# Install MCR and SPM12
#----------------------
# Install MATLAB Compiler Runtime
RUN apt-get update -qq && apt-get install -yq --no-install-recommends libxext6 libxt6 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    # Install MATLAB Compiler Runtime \
    && echo "Downloading MATLAB Compiler Runtime ..." \
    && curl -sSL -o /tmp/mcr.zip https://www.mathworks.com/supportfiles/downloads/R2017a/deployment_files/R2017a/installers/glnxa64/MCR_R2017a_glnxa64_installer.zip \
    && unzip -q /tmp/mcr.zip -d /tmp/mcrtmp \
    && /tmp/mcrtmp/install -destinationFolder /opt/mcr -mode silent -agreeToLicense yes \
    && rm -rf /tmp/*

# Install standalone SPM
RUN echo "Downloading standalone SPM ..." \
    && curl -sSL -o spm.zip http://www.fil.ion.ucl.ac.uk/spm/download/restricted/utopia/dev/spm12_latest_Linux_R2017a.zip \
    && unzip -q spm.zip -d /opt \
    && chmod -R 777 /opt/spm* \
    && rm -rf spm.zip
ENV MATLABCMD=/opt/mcr/v92/toolbox/matlab \
    SPMMCRCMD="/opt/spm12/run_spm12.sh /opt/mcr/v92/ script" \
    FORCE_SPMMCR=1 \
    LD_LIBRARY_PATH=/opt/mcr/v92/runtime/glnxa64:/opt/mcr/v92/bin/glnxa64:/opt/mcr/v92/sys/os/glnxa64:$LD_LIBRARY_PATH

USER neuro

ENV KEY_A="VAL_A" \
    KEY_B="VAL_B"

ENV KEY_C="based on $KEY_A"

# User-defined instruction
RUN echo hello world

WORKDIR /home/neuro
