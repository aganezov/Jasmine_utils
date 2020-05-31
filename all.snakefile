import os

exp_name = config["exp_name"]
output_dir = os.path.join(config.get("output_dir", "jasmine_eval"), exp_name)

expected_files_by_tools = {
    "svtools" : os.path.join(output_dir, exp_name + ".svtools.lmerge.postp.cleaned.specific.vcf"),
    "survivor": os.path.join(output_dir, exp_name + ".survivor.postp.specific.vcf"),
    "svimmer" : os.path.join(output_dir, exp_name + ".svimmer.postp.specific.vcf"),
    "jasmine" : os.path.join(output_dir, exp_name + ".jasmine.specific.vcf"),
}

def method_specific_input_files():
    result = []
    for tool in config.get("tools_enabled", ["svtools", "survivor", "svimmer", "jasmine"]):
        result.append(expected_files_by_tools[tool])
    return result

rule all:
    input: method_specific_input_files()

include: "svtools.snakefile"
include: "svimmer.snakefile"
include: "survivor.snakefile"
include: "jasmine.snakefile"
