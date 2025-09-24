/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryMap       } from 'plugin/nf-validation'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_mutationalsignatures_pipeline'
include { MULTIQC                } from '../modules/nf-core/multiqc/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { MATRIXGENERATOR             } from '../modules/local/sigprofiler/matrixgenerator/main'
include { ASSESSMENT                  } from '../modules/local/assessment/main'
include { ASSIGNMENT                  } from '../modules/local/sigprofiler/assignment/main'
include { ASSIGNMENT_ALT              } from '../modules/local/sigprofiler/assignment_alt/main'
include { SIGNATURETOOLSLIB           } from '../modules/local/signaturetoolslib/assignment/main'
include { SIGNATURETOOLSLIB_ALT       } from '../modules/local/signaturetoolslib/assignment_alt/main'
include { ERRORTRESHOLDING            } from '../modules/local/errorthresholding/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow MUTATIONALSIGNATURES {

    take:
    cohort // channel: samplesheet read in from --input

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    //
    // MODULE : matrixgenerator
    //

    if ( params.filetype != 'matrix') {
        MATRIXGENERATOR (
            cohort,
            params.filetype
        )
        ch_versions = ch_versions.mix(MATRIXGENERATOR.out.versions)
    }

    //
    // MODULE : assessment
    //

    if ( params.filetype == 'matrix') {
        ASSESSMENT (
            cohort
        )
        ch_versions = ch_versions.mix(ASSESSMENT.out.versions)
    } else {
        ASSESSMENT (
            MATRIXGENERATOR.out.output_SBS
        )
        ch_versions = ch_versions.mix(ASSESSMENT.out.versions)
    }

    //
    // Split workflow depending on provided alternate signature catalogue
    //
    // Module: sigprofiler
    //

    /// CATALOGUE PROVIDED

    if ( params.signature_catalogue ) {

        signature_catalogue_ch = file(params.signature_catalogue)
        //Channel.fromPath(params.signature_catalogue)

        if ( params.filetype == 'matrix') {
            matgen_finished = "process_complete"
            ASSIGNMENT_ALT (
                ASSESSMENT.out.reordered_cosmic,
                signature_catalogue_ch,
                params.filetype,
                matgen_finished
            )
            ch_versions = ch_versions.mix(ASSIGNMENT_ALT.out.versions)

        } else {

            ASSIGNMENT_ALT (
                cohort,
                signature_catalogue_ch,
                params.filetype,
                MATRIXGENERATOR.out.matgen_finished.collect()
            )
            ch_versions = ch_versions.mix(ASSIGNMENT_ALT.out.versions)
        }
    } else {

        /// NO CATALOGUE PROVIDED

        if ( params.filetype == 'matrix') {
            matgen_finished = "process_complete"
            ASSIGNMENT (
                ASSESSMENT.out.reordered_cosmic,
                params.filetype,
                matgen_finished
            )
            ch_versions = ch_versions.mix(ASSIGNMENT.out.versions)
        } else {
            ASSIGNMENT (
                cohort,
                params.filetype,
                MATRIXGENERATOR.out.matgen_finished.collect()
            )
            ch_versions = ch_versions.mix(ASSIGNMENT.out.versions)
        }
    }

    if ( params.signature_catalogue ) {
        SIGNATURETOOLSLIB_ALT (
            ASSESSMENT.out.reordered_sigtool,
            signature_catalogue_ch
        )
        ch_versions = ch_versions.mix(SIGNATURETOOLSLIB_ALT.out.versions)
    } else {
        SIGNATURETOOLSLIB (
            ASSESSMENT.out.reordered_sigtool
        )
        ch_versions = ch_versions.mix(SIGNATURETOOLSLIB.out.versions)
    }

    //
    // MODULE: errorthresholding
    //

    /// CATALOGUE PROVIDED

    if ( params.signature_catalogue ) {
            ERRORTRESHOLDING (
                SIGNATURETOOLSLIB_ALT.out.json,
                ASSESSMENT.out.reordered_sigtool,
            )
            ch_versions = ch_versions.mix(ERRORTRESHOLDING.out.versions)
    } else {
            ERRORTRESHOLDING (
                SIGNATURETOOLSLIB.out.json,
                ASSESSMENT.out.reordered_sigtool,
    )
    ch_versions = ch_versions.mix(ERRORTRESHOLDING.out.versions)
    }

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_pipeline_software_mqc_versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }

    //
    // MODULE: MultiQC
    //
    ch_multiqc_config        = Channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        Channel.fromPath(params.multiqc_config, checkIfExists: true) :
        Channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ?
        Channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        Channel.empty()

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = Channel.value(paramsSummaryMultiqc(summary_params))

    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = Channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true
        )
    )

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList()
    )

    emit:
    multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
