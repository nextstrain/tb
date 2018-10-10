# nextstrain.org/tb

This is the [Nextstrain](https://nextstrain.org/) build for tuberculosis, visible at [nextstrain.org/tb](https://nextstrain.org/tb).

The build encompasses preparing data for analysis, doing quality control, performing analyses, and saving the results in a format suitable for visualization (with [auspice][]). 
This involves running components of Nextstrain such as [augur][] and [auspice][].

All tuberculosis-specific steps and functionality for the Nextstrain pipeline should be housed in this repository.

## Tutorial

There is a [tutorial](https://nextstrain.org/docs/getting-started/tb-tutorial) on how to run this build.

## Usage

If you're unfamiliar with Nextstrain builds, you may want to follow our
[quickstart guide][] first and then come back here.

The easiest way to run this pathogen build is using the [Nextstrain
command-line tool][nextstrain-cli]:

    nextstrain build .

See the [nextstrain-cli README][] for how to install the `nextstrain` command.

Alternatively, you should be able to run the build using `snakemake` within an suitably-configured local environment.  
Details of setting that up are not yet well-documented, but will be in the future.

Build output goes into the directories `results/` and `auspice/`.

Once you've run the build, you can view the results in auspice:

    nextstrain view auspice/


## Configuration

Configuration takes place entirely with the `Snakefile`. This can be read top-to-bottom, each rule
specifies its file inputs and output and also its parameters. There is little redirection and each
rule should be able to be reasoned with on its own.

[augur]: https://github.com/nextstrain/augur
[auspice]: https://github.com/nextstrain/auspice
[snakemake cli]: https://snakemake.readthedocs.io/en/stable/executable.html#all-options
[nextstrain-cli]: https://github.com/nextstrain/cli
[nextstrain-cli README]: https://github.com/nextstrain/cli/blob/master/README.md
[quickstart guide]: https://nextstrain.org/docs/getting-started/quickstart
