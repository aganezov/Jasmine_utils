import os

configfile: "svtools.yaml"

output_dir = os.path.join(config.get("output_dir", "svtools_output"), config["exp_name"])

input_files_by_core_basenames = {}
for entry in config["input"]:
    basename = os.path.basename(entry)
    input_files_by_core_basenames[".".join(basename.split(".")[:-1])] = entry

def svtools_suite_basename(basename):
    return basename + ".svtools.vcf"

rule svtools_all:
    input: os.path.join(output_dir, config["exp_name"] + ".svtools.lmerge.postp.cleaned.specific.vcf")

rule svtoosl_retain_specific:
    input: os.path.join(output_dir, "{exp_name}.svtools.lmerge.postp.cleaned.vcf")
    output: os.path.join(output_dir, "{exp_name}.svtools.lmerge.postp.cleaned.specific.vcf")
    log: os.path.join(output_dir, "log", "{exp_name}.svtools.lmerge.postp.specific.vcf.log")
    shell:
        "awk '($0 ~/^#/ || $0 ~/IS_SPECIFIC=1/)' {input} > {output} 2> {log}"

rule remove_bnd_duplicates:
    input: os.path.join(output_dir, "{exp_name}.svtools.lmerge.postp.vcf")
    output: os.path.join(output_dir, "{exp_name}.svtools.lmerge.postp.cleaned.vcf")
    log: os.path.join(output_dir, "log", "{exp_name}.svtools.lmerge.postp.cleaned.vcf.log")
    shell:
        "awk '($0 !~ /MATEID=[^;]+_1;/)' {input} > {output} 2> {log}"

rule svtools_posp:
    output: os.path.join(output_dir, "{exp_name}.svtools.lmerge.postp.vcf")
    input: merged_vcf=os.path.join(output_dir, "{exp_name}.svtools.lmerge.vcf"),
           vcf_list_file=os.path.join(output_dir, "{exp_name}.svtools.input_vcfs.txt"),
    log: os.path.join(output_dir, "log", "{exp_name}.svtools.lmerge.postp.vcf.log")
    params:
        python=config.get("python", "python"),
        svtools_postp_script=config.get("annotateSVTools", "annotateMerged.py"),
    shell:
         "{params.python} {params.svtools_postp_script} -f {input.vcf_list_file} "
         "-m {input.merged_vcf} --merged-ids-field SNAME -o {output} &> {log}"


rule svtools_lmerge:
    output: os.path.join(output_dir, "{exp_name}.svtools.lmerge.vcf")
    input: os.path.join(output_dir, "{exp_name}.svtools.lsort.vcf")
    log: os.path.join(output_dir, "log", "{exp_name}.svtools.lmerge.vcf.log")
    benchmark: repeat(os.path.join(output_dir, "benchmark", "{exp_name}.svtools.lmerge.txt"), 5)
    params:
        svtools=config.get("svtools", "svtools"),
        percent_slop=lambda wc: "-p " + config.get("percent_slop", "0.0") if config.get("use_percent_slop", False) else "",
        fixed_slop=lambda wc: "-f " + config.get("fixed_slop", "1000") if config.get("use_fixed_slop", True) else "",
    shell:
        "{params.svtools} lmerge -i {input} {params.percent_slop} {params.fixed_slop} > {output} 2> {log}"

rule svtools_lsort:
    output: os.path.join(output_dir, "{exp_name}.svtools.lsort.vcf")
    input: os.path.join(output_dir, "{exp_name}.svtools.input_vcfs.txt")
    log: os.path.join(output_dir, "log", "{exp_name}.svtools.lsort.vcf.log")
    benchmark: repeat(os.path.join(output_dir, "benchmark", "{exp_name}.svtools.lsort.txt"), 5)
    params:
        svtools=config.get("svtools", "svtools"),
    shell:
        "{params.svtools} lsort -f {input} -r > {output} 2> {log}"

rule svtools_lsort_file_list:
    output: os.path.join(output_dir, "{exp_name}.svtools.input_vcfs.txt")
    input: lambda wc: [os.path.join(output_dir, basename + ".svtools.vcf") for basename in input_files_by_core_basenames.keys()]
    run:
        with open(output[0], "wt") as dest:
            for l in input:
                print(l, file=dest)


rule svtools_suite:
    output: os.path.join(output_dir, "{core_basename}.svtools.vcf")
    input: lambda wc: input_files_by_core_basenames[wc.core_basename]
    log: os.path.join(output_dir, "log", os.path.join(output_dir, "{core_basename}.svtools.vcf.log"))
    params:
        python=config.get("python", "python"),
        sniffles2svtools=config.get("sniffles2svtools", "sniffles2svtools.py"),
        flex_ci=lambda wc: "--flex-ci" if config.get("flex_ci", True) else "",
    shell:
         "{params.python} {params.sniffles2svtools} {params.flex_ci} {input} -o {output} &> {log}"
