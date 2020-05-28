import os

configfile: "svimmer.yaml"

output_dir = os.path.join(config.get("output_dir", "svimmer_output"), config["exp_name"])

input_files_by_core_basenames = {}
for entry in config["input"]:
    basename = os.path.basename(entry)
    input_files_by_core_basenames[".".join(basename.split(".")[:-1])] = entry

rule svimmer_all:
    input: os.path.join(output_dir, config["exp_name"] + ".svimmer.postp.specific.vcf")

rule svimmer_retain_specific:
    output: os.path.join(output_dir, "{exp_name}.svimmer.postp.specific.vcf")
    input: os.path.join(output_dir, "{exp_name}.svimmer.postp.vcf")

rule svimmer_posp:
    output: os.path.join(output_dir, "{exp_name}.svimmer.postp.vcf")
    input: os.path.join(output_dir, "{exp_name}.svimmer.vcf")

rule svimmer_merge:
    output: os.path.join(output_dir, "{exp_name}.svimmer.vcf")
    input: os.path.join(output_dir, "{exp_name}.svimmer.file_list.txt")

rule svimmer_file_list:
    output: os.path.join(output_dir, "{exp_name}.svimmer.file_list.txt")
    input: compressed_vcfs=lambda wc: [os.path.join(output_dir, basename + ".vcf.gz") for basename in input_files_by_core_basenames.keys()],
           indexes=lambda wc: [os.path.join(output_dir, basename + ".vcf.gz.tbi") for basename in input_files_by_core_basenames.keys()],
    run:
        with open(output[0], "wt") as dest:
            for l in input.compressed_vcfs:
                print(l, file=dest)

rule svimmer_tabix:
    output: os.path.join(output_dir,  "{basename}.vcf.gz.tbi")
    input: os.path.join(output_dir,  "{basename}.vcf.gz")
    log: os.path.join(output_dir, "log", "{basename}.vcf.gz.log")
    params:
        tabix=config.get("tabix", "tabix")
    shell:
         "{params.tabix} {input} &> {log}"

rule svimmer_suite:
    output: os.path.join(output_dir,  "{basename}.vcf.gz")
    input: lambda wc: input_files_by_core_basenames[wc.basename]
    log: os.path.join(output_dir, "log", "{basename}.vcf.gz.log")
    params:
        python=config.get("python", "python"),
        sniffles2svimmer=config.get("sniffles2svimmer", "sniffles2svimmer.py")
    shell:
         "{params.python} {params.sniffles2svimmer} {input} -o {output} &> {log}"


