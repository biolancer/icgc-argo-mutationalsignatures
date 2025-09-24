process ASSIGNMENT_ALT {
    label 'process_medium'

    conda "bioconda::sigmut=1.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker.io/katiad/sigprofiler:version1.0':
        'docker.io/katiad/sigprofiler:version1.0' }"
    containerOptions { workflow.containerEngine == 'singularity' ? '--writable-tmpfs' : ''}

    input:
    tuple val(meta), path(input)
    path signature_catalogue
    val  filetype
    val  matgen_finished

    output:
    tuple val(meta), path("output")                   , emit: sigprofiler_output
    path "versions.yml"                               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def processdir = "\${PWD}"

    """
    sigprofiler_alt.py \\
        --filetype $filetype \\
        --input $input \\
        --output_pattern $meta.id \\
        --signature_database $signature_catalogue \\
        $args \\
        2> $processdir/sigprofiler.error.log \\
        1> $processdir/sigprofiler.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        SigProfilerAssignment: \$(python -c "import SigProfilerAssignment; print(SigProfilerAssignment.__version__)")
    END_VERSIONS
    """
}
