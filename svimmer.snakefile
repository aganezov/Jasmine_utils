import os

configfile: "svimmer.yaml"

exp_name = config["exp_name"]
output_dir = os.path.join(config.get("output_dir", "jasmine_eval"), exp_name)

input_files_by_core_basenames = {}
for entry in config["input"]:
    basename = os.path.basename(entry)
    input_files_by_core_basenames[".".join(basename.split(".")[:-1])] = entry

basename_regex = "(" + "|".join(input_files_by_core_basenames.keys()) + ")"

rule svimmer_all:
    input: os.path.join(output_dir, exp_name + ".svimmer.postp.specific.vcf")

rule svimmer_retain_specific:
    output: os.path.join(output_dir, "{exp_name," + exp_name + "}.svimmer.postp.specific.vcf")
    input: os.path.join(output_dir, "{exp_name}.svimmer.postp.vcf")
    log: os.path.join(output_dir, "log", "{exp_name}.svimmer.postp.specific.vcf.log")
    shell:
        "awk '($0 ~/^#/ || $0 ~/IS_SPECIFIC=1/)' {input} > {output} 2> {log}"

rule svimmer_posp:
    output: os.path.join(output_dir, "{exp_name," + exp_name + "}.svimmer.postp.vcf")
    input: merged_vcf=os.path.join(output_dir, "{exp_name}.svimmer.vcf"),
           vcf_list_file=os.path.join(output_dir, "{exp_name}.svimmer.file_list.txt"),
    log: os.path.join(output_dir, "log", "{exp_name}.svimmer.postp.vcf.log")
    params:
        python=config.get("python", "python"),
        svimmer_postp_script=config.get("svimmer_postp_script", "annotateMerged.py"),
    shell:
        "{params.python} {params.svimmer_postp_script} -f {input.vcf_list_file} "
        "-m {input.merged_vcf} --merged-ids-field MERGED_IDS --no-id-split "
        "-o {output} &> {log}"


rule svimmer_merge:
    output: os.path.join(output_dir, "{exp_name," + exp_name + "}.svimmer.vcf")
    input: os.path.join(output_dir, "{exp_name}.svimmer.file_list.txt")
    log: os.path.join(output_dir, "log", "{exp_name}.svimmer.vcf.log")
    threads: 24
    benchmark: repeat(os.path.join(output_dir, "benchmark", "{exp_name}.svimmer.txt"), 5)
    params:
        python=config.get("python", "python"),
        svimmer=config.get("svimmer", "svimmer"),
        chromosomes=lambda wc: " ".join(map(str, config.get("chromosomes", [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, "X", "Y", "MT"]))),
        max_distance=config.get("max_distance", 1000),
        max_size_difference=config.get("max_size_difference", 1000),
        consider_types=lambda wc: "" if config.get("consider_types", True) else "--ignore-types",
    shell:
        "{params.python} {params.svimmer} {input} {params.chromosomes} --threads {threads} --loglevel INFO "
        "--max_distance {params.max_distance} --max_size_difference {params.max_size_difference} {params.consider_types} "
        "--ids --output {output} &> {log}"

rule svimmer_file_list:
    output: os.path.join(output_dir, "{exp_name," + exp_name + "}.svimmer.file_list.txt")
    input: compressed_vcfs=lambda wc: [os.path.join(output_dir, basename + ".svimmer.vcf.gz") for basename in input_files_by_core_basenames.keys()],
           indexes=lambda wc: [os.path.join(output_dir, basename + ".svimmer.vcf.gz.tbi") for basename in input_files_by_core_basenames.keys()],
    run:
        with open(output[0], "wt") as dest:
            for l in input.compressed_vcfs:
                print(l, file=dest)

rule svimmer_tabix:
    output: os.path.join(output_dir,  "{basename," + basename_regex + "}.svimmer.vcf.gz.tbi")
    input: os.path.join(output_dir,  "{basename}.svimmer.vcf.gz")
    log: os.path.join(output_dir, "log", "{basename}.svimmer.vcf.gz.log")
    params:
        tabix=config.get("tabix", "tabix")
    shell:
         "{params.tabix} {input} &> {log}"

rule svimmer_suite:
    output: os.path.join(output_dir,  "{basename, " + basename_regex + "}.svimmer.vcf.gz")
    input: lambda wc: input_files_by_core_basenames[wc.basename]
    log: os.path.join(output_dir, "log", "{basename}.svimmer.vcf.gz.log")
    params:
        python=config.get("python", "python"),
        sniffles2svimmer=config.get("sniffles2svimmer", "sniffles2svimmer.py")
    shell:
         "{params.python} {params.sniffles2svimmer} {input} -o {output} &> {log}"


