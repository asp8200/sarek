//
// BAM TO CRAM and optionnal QC
//
// For all modules here:
// A when clause condition is defined in the conf/modules.config to determine if the module should be run

include { SAMTOOLS_CONVERT as BAMTOCRAM          } from '../../modules/nf-core/modules/samtools/convert/main'
include { SAMTOOLS_STATS as SAMTOOLS_STATS_CRAM  } from '../../modules/nf-core/modules/samtools/stats/main'
include { MOSDEPTH                               } from '../../modules/nf-core/modules/mosdepth/main'

workflow BAM_TO_CRAM {
    take:
        bam_indexed                   // channel: [mandatory] meta, bam, bai
        cram_indexed
        fasta                         // channel: [mandatory] fasta
        fasta_fai                     // channel: [mandatory] fai
        intervals_bed_combined        // channel: [optional]  intervals_bed


    main:
    ch_versions = Channel.empty()
    qc_reports  = Channel.empty()

    // remap to have channel without bam index
    bam_no_index = bam_indexed.map{ meta, bam, bai -> [meta, bam] }

    // Convert bam input to cram
    BAMTOCRAM(bam_indexed, fasta, fasta_fai)

    cram_indexed = Channel.empty().mix(cram_indexed,BAMTOCRAM.out.alignment_index)
                    .map{meta, cram, crai ->
                        [
                            [data_type:     "cram",
                            id:             meta.sample,
                            num_intervals:  meta.num_intervals,
                            patient:        meta.patient,
                            sample:         meta.sample,
                            sex:            meta.sex,
                            status:         meta.status,],
                            cram, crai]
                    }

    // Reports on cram
    SAMTOOLS_STATS_CRAM(cram_indexed, fasta)
    MOSDEPTH(cram_indexed, intervals_bed_combined, fasta)

    // Gather all reports generated
    qc_reports = qc_reports.mix(SAMTOOLS_STATS_CRAM.out.stats)
    qc_reports = qc_reports.mix(MOSDEPTH.out.global_txt,
                                MOSDEPTH.out.regions_txt)

    // Gather versions of all tools used
    ch_versions = ch_versions.mix(MOSDEPTH.out.versions)
    ch_versions = ch_versions.mix(BAMTOCRAM.out.versions)
    ch_versions = ch_versions.mix(SAMTOOLS_STATS_CRAM.out.versions)

    emit:
        cram_converted  = BAMTOCRAM.out.alignment_index
        qc              = qc_reports

        versions = ch_versions // channel: [ versions.yml ]
}
