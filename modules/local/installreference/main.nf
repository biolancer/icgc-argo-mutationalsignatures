process INSTALLREFERENCE {
    label 'process_low'

    conda "bioconda::sigmut=1.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'quay.io/biocontainers/sigprofilermatrixgenerator:1.3.3--pyhdfd78af_1':
        'quay.io/biocontainers/sigprofilermatrixgenerator:1.3.3--pyhdfd78af_1' }"

    input:
    val     ref
    path    refdir

    output:
    val("installreference_complete")                                            ,     emit: installref_finished
    path "versions.yml"                                                         ,     emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def processdir = "\${PWD}"

    """
    SigProfilerMatrixGenerator install \\
        $ref \\
        -v $refdir \\
        2> $processdir/refgen.error.log \\
        1> $processdir/refgen.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        SigProfilerMatrixGenerator: \$(python -c "import SigProfilerMatrixGenerator; print(SigProfilerMatrixGenerator.__version__)")
    END_VERSIONS
    """
}
