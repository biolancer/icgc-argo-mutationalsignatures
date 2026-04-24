process MATRIXGENERATOR {
    label 'process_low'

    conda "bioconda::sigmut=1.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'quay.io/biocontainers/sigprofilermatrixgenerator:1.3.3--pyhdfd78af_1':
        'quay.io/biocontainers/sigprofilermatrixgenerator:1.3.3--pyhdfd78af_1' }"

    input:
    tuple val(meta), path(input)
    val  filetype
    val  installref_finished

    output:
    tuple val(meta), path("Trinucleotide_matrix_${meta.id}_SBS96.txt"),     emit: output_SBS
    tuple val(meta), path("Trinucleotide_matrix_${meta.id}_DBS78.txt"),     emit: output_DBS, optional: true
    tuple val(meta), path("Trinucleotide_matrix_${meta.id}_ID83.txt") ,     emit: output_ID,  optional: true
    val("process_complete")                                           ,     emit: matgen_finished
    path "versions.yml"                                               ,     emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def processdir = "\${PWD}"

    """
    matrixgenerator.py \\
        --filetype $filetype \\
        --input $input \\
        --output_pattern $meta.id \\
        $args \\
        2> $processdir/matrixgenerator.error.log \\
        1> $processdir/matrixgenerator.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        SigProfilerMatrixGenerator: \$(python -c "import SigProfilerMatrixGenerator; print(SigProfilerMatrixGenerator.__version__)")
    END_VERSIONS
    """
}
