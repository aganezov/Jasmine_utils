import os

configfile: "survivor.yaml"

exp_name = config["exp_name"]
output_dir = os.path.join(config.get("output_dir", "jasmine_eval"), exp_name)
benchmark_iter_cnt = config.get("bench_rep", 5)

rule survivor_all:
    input: os.path.join(output_dir, exp_name + ".survivor.postp.specific.vcf")

rule survivor_retain_specific:
    output: os.path.join(output_dir, "{exp_name," + exp_name + "}.survivor.postp.specific.vcf")
    input: os.path.join(output_dir, "{exp_name}.survivor.postp.vcf")
    log: os.path.join(output_dir, "log", "{exp_name}.survivor.postp.specific.vcf.log")
    shell:
        "awk '($0 ~/^#/ || $0 ~/IS_SPECIFIC=1/)' {input} > {output} 2> {log}"

rule survivor_postp:
    output: os.path.join(output_dir, "{exp_name," + exp_name + "}.survivor.postp.vcf")
    input: merged_vcf=os.path.join(output_dir, "{exp_name}.survivor.vcf"),
           vcf_list_file=os.path.join(output_dir, "{exp_name}.survivor.input_vcf.txt")
    log: os.path.join(output_dir, "log", "{exp_name}.survivor.postp.vcf.log")
    params:
        python=config.get("python", "python"),
        survivor_postp_script=config.get("annotateSurvivorMerged", "annotateSurvivorMerged.py"),
    shell:
        "{params.python} {params.survivor_postp_script} -f {input.vcf_list_file} -m {input.merged_vcf} -o {output} 2> {log}"

rule survivor:
    output: os.path.join(output_dir, "{exp_name," + exp_name + "}.survivor.vcf")
    input: os.path.join(output_dir, "{exp_name}.survivor.input_vcf.txt")
    log: os.path.join(output_dir, "log", "{exp_name}.survivor.vcf.log")
    benchmark: repeat(os.path.join(output_dir, "benchmark", "{exp_name}.survivor.txt"), benchmark_iter_cnt)
    params:
        survivor = config.get("survivor", "SURVIVOR"),
        max_dist = config.get("max_dist", 1000),
        min_callers = config.get("min_callers", 0),
        consider_types = 1 if config.get("consider_types", True) else 0,
        consider_strands = 1 if config.get("consider_strands", True) else 0,
        min_sv_size = config.get("min_sv_size", 1),
    shell:
        "{params.survivor} merge {input} {params.max_dist} {params.min_callers} {params.consider_types} {params.consider_strands} 0 {params.min_sv_size} {output} &> {log}"

rule survivor_input_file_list:
    output: os.path.join(output_dir, "{exp_name," + exp_name + "}.survivor.input_vcf.txt")
    input: config["input"]
    log: os.path.join(output_dir, "log", "{exp_name}.survivor.input_vcf.txt.log")
    run:
        with open(output[0], "wt") as dest:
            for l in input:
                print(l, file=dest)
