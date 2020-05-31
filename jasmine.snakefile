import os

configfile: "jasmine.yaml"

exp_name = config["exp_name"]
output_dir = os.path.join(config.get("output_dir", "jasmine_eval"), exp_name)
benchmark_iter_cnt = config.get("bench_rep", 5)

rule jasmine_all:
    input: os.path.join(output_dir, exp_name + ".jasmine.specific.vcf")

rule jasmine_retain_specific:
    output: os.path.join(output_dir, "{exp_name," + exp_name + "}.jasmine.specific.vcf")
    input: os.path.join(output_dir, "{exp_name}.jasmine.vcf")
    log: os.path.join(output_dir, "log", "{exp_name}.jasmine.specific.vcf.log")
    shell:
        "awk '($0 ~/^#/ || $0 ~/IS_SPECIFIC=1/)' {input} > {output} 2> {log}"

rule jasmine_merge:
    output: os.path.join(output_dir, "{exp_name," + exp_name + "}.jasmine.vcf")
    input: os.path.join(output_dir, "{exp_name}.jasmine.file_list.txt")
    log: os.path.join(output_dir, "log", "{exp_name}.jasmine.vcf.log")
    threads: 24
    benchmark: repeat(os.path.join(output_dir, "benchmark", "{exp_name}.jasmine.vcf"), benchmark_iter_cnt)
    params:
        java=config.get("java", "java"),
        java_cp=config.get("java_cp", ""),
    shell:
         "{params.java} -cp {params.java_cp} Main threads={threads} file_list={input} out_file={output} &> {log}"

rule jasmine_input_file_list:
    output: os.path.join(output_dir, "{exp_name," + exp_name + "}.jasmine.file_list.txt")
    input: files=config["input"]
    run:
        with open(output[0], "wt") as dest:
            for l in input.files:
                print(l, file=dest)
