from __future__ import print_function
import argparse
import re
import sys

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("vcf", type=argparse.FileType("rt"))
    parser.add_argument("--flex-ci", action="store_false", dest="ci0")
    parser.add_argument("-o", "--output", type=argparse.FileType("wt"), default=sys.stdout)
    args = parser.parse_args()
    start_sigma_pattern = re.compile("STD_quant_start=(?P<value>-?\d+(\.\d+)*)")
    stop_sigma_pattern = re.compile("STD_quant_stop=(?P<value>-?\d+(\.\d+)*)")
    TRA2BNDreplacer = re.compile(";SVTYPE=TRA")
    support_reads_pattern = re.compile(";RE=(?P<value>\d+)")
    strands_pattern = re.compile(";STRANDS=(?P<value>..)")
    svtype_pattern = re.compile(";SVTYPE=(?P<value>[^;]+)")
    for line in args.vcf:
        line = line.strip()
        if line.startswith("##"):
            print(line, file=args.output)
            continue
        if line.startswith("#"):
            print('##INFO=<ID=MATEID,Number=1,Type=String,Description="Mate SV id for BND/TRA SV"', file=args.output)
            print('##INFO=<ID=SECONDARY,Number=0,Type=Flag,Description="Whether or not an SV record if secondary or primary"', file=args.output)
            print('##INFO=<ID=EVENT,Number=1,Type=String,Description="Event id"', file=args.output)
            print('##INFO=<ID=SU,Number=1,Type=Integer,Description="Number of reads supporting the SV. Equals to SR + PE">', file=args.output)
            print('##INFO=<ID=PE,Number=1,Type=Integer,Description="Number of paired-end reads supporting the SV. Set to 0 for Sniffles calls">', file=args.output)
            print('##INFO=<ID=SR,Number=1,Type=Integer,Description="Number of split reads supporting the SV. Set to RE for Sniffles calls">', file=args.output)
            print('##INFO=<ID=CIPOS,Number=2,Type=Integer,Description="min(Sniffles STD start quant * +-4, +-500)">', file=args.output)
            print('##INFO=<ID=CIEND,Number=2,Type=Integer,Description="min(Sniffles STD stop quant * +-4, +-500)">', file=args.output)
            print('##INFO=<ID=CIPOS95,Number=2,Type=Integer,Description="min(Sniffles STD start quant * +-2, +-50)">', file=args.output)
            print('##INFO=<ID=CIEND95,Number=2,Type=Integer,Description="min(Sniffles STD stop quant * +-2, +-50)">', file=args.output)
            print('##INFO=<ID=PRPOS,Number=A,Type=Float,Description="Dummy breakpoint probability floats to satisfy svtools requirement">', file=args.output)
            print('##INFO=<ID=PREND,Number=A,Type=Float,Description="Dummy breakpoint probability floats to satisfy svtools requirement">', file=args.output)
            print(line, file=args.output)
            continue
        data = line.split("\t")
        try:
            start_sigma = abs(float(start_sigma_pattern.search(data[7]).group('value')))
        except AttributeError:
            start_sigma = 0
        try:
            stop_sigma = abs(float(stop_sigma_pattern.search(data[7]).group('value')))
        except AttributeError:
            stop_sigma = 0
        if args.ci0:
            start_sigma = 0
            stop_sigma = 0
        supporting_reads_cnt = abs(int(support_reads_pattern.search(data[7]).group('value')))
        strands_str = strands_pattern.search(data[7]).group('value')
        pos_interval = int(start_sigma * 4) - int(start_sigma * -4)
        end_interval = int(stop_sigma * 4) - int(stop_sigma * -4)
        svtype = svtype_pattern.search(data[7]).group('value')
        data[7] += ";CIPOS={M},{m}".format(M=max(-500, int(start_sigma * -4)), m=min(500, int(start_sigma * 4))) + \
                   ";CIEND={M},{m}".format(M=max(-500, int(stop_sigma * -4)), m=min(500, int(stop_sigma * 4))) + \
                   ";CIPOS95={M},{m}".format(M=max(-250, int(start_sigma * -2)), m=min(250, int(start_sigma * 2))) + \
                   ";CIEND95={M},{m}".format(M=max(-250, int(stop_sigma * -2)), m=min(250, int(stop_sigma * 2))) + \
                   ";PRPOS=0.1;PREND=0.1;SU={supporting_reads_cnt};PE=0;SR={supporting_reads_cnt}".format(supporting_reads_cnt=supporting_reads_cnt)
        data[7] = data[7].replace(";SVTYPE=TRA", ";SVTYPE=BND")
        data[7] = data[7].replace(";STRANDS={strands_str}".format(strands_str=strands_str), ";STRANDS={strands_str}:{supporting_reads_cnt}".format(strands_str=strands_str, supporting_reads_cnt=supporting_reads_cnt))
        if svtype not in ["BND", "TRA"]:
            data[4] = "<{svtype}>".format(svtype=svtype)
        print("\t".join(data), file=args.output)
