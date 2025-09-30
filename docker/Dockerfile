FROM nextstrain/base:latest

# Run the final setup as our target user for permissions reasons.
USER nextstrain:nextstrain

# Install Miniforge (includes conda)
RUN curl -L "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-$(uname -m).sh" -o miniforge.sh && \
    bash miniforge.sh -b -p /nextstrain/miniforge && \
    rm miniforge.sh

# Make conda available in PATH
ENV PATH="/nextstrain/miniforge/condabin:$PATH"

# Initialize conda for interactive shell use
RUN conda init bash \
 && conda config --set auto_activate_base false


# Create conda environments
# Add global write bits, similar to what's done for /nextstrain¹, but
# recursively on the conda environment directory. This allows `tb-profiler
# update_tbdb` to write to the directory at run time under a different UID.
# ¹ <https://github.com/nextstrain/docker-base/blob/9270fb321251b298b332b648f2744308bb2d89ff/Dockerfile#L430-L431>

RUN conda create -y --name snippy \
      -c conda-forge -c bioconda \
      sra-tools=3.2.1 \
      snippy=4.6.0 \
 && conda clean -afy \
 && rm -rf ~/.cache \
 && chmod -R a+rwXt /nextstrain/miniforge/envs/snippy

RUN conda create -y --name tb-profiler \
      -c conda-forge -c bioconda \
      sra-tools=3.2.1 \
      tb-profiler=6.6.5 \
 && conda clean -afy \
 && rm -rf ~/.cache \
 && chmod -R a+rwXt /nextstrain/miniforge/envs/tb-profiler

RUN conda create -y --name duckdb \
      -c conda-forge \
      duckdb-cli \
 && conda clean -afy \
 && rm -rf ~/.cache \
 && chmod -R a+rwXt /nextstrain/miniforge/envs/duckdb

# Switch back to root.  The entrypoint will drop to nextstrain:nextstrain as
# necessary when a container starts.
USER root
