import os
configfile: "config/config.yaml"
cluster_config: "config/cluster.yaml" 
include: "helpers.py"
#RULE ORDER DIRECTIVE soo cool. This says that you should try to run the paired end rule beofre the single end rule to produce the output, but if 
#the proper input isn't there for the pairend end e.g. two trimmed fastqs, then run the single end.
if config['end_type'] == "pe":
	ruleorder: run_star_pe > run_star_se
else:
	ruleorder: run_star_se > run_star_pe
#make sure the output folder for STAR exists before running anything
os.system("mkdir -p {0}".format(config["star_output_folder"]))

SAMPLES = pd.read_table(config["sampleCSVpath"], sep = ",")
SAMPLES = SAMPLES.replace(np.nan, '', regex=True)

SAMPLE_NAMES = SAMPLES['sample_name'].tolist()
UNITS = SAMPLES['unit'].tolist()
#this function uses the text file located in the config folder "star_genomes_species.csv" and the config file species parameter to 
#give the correct genome for the species
GENOME_DIR = get_genome_directory(config['species'])

rule all_star:
	input:
		expand(config['star_output_folder'] + "{name}/Aligned.out.bam",name = SAMPLE_NAMES)

rule run_star_pe:
	input:
		one = lambda wildcards: get_trimmed(wildcards.name)[0],
		two = lambda wildcards: get_trimmed(wildcards.name)[1]
	output:
		config['star_output_folder'] + "{name}/Aligned.out.bam"
	params:
		extra_star_parameters = return_parsed_extra_params(config['extra_star_parameters']),
		genomeDir = GENOME_DIR,
		outTmpDir = os.path.join(config['star_output_folder'] + "{name}/_tmpdir"),
		outputPrefix = os.path.join(config['star_output_folder'] + "{name}/"),
		#taking the input files and putting them into a comma separated list
		one = lambda wildcards: ','.join(get_trimmed(wildcards.name)[0]),
		two = lambda wildcards: ','.join(get_trimmed(wildcards.name)[1])
	threads: 
		4
	shell:
		"""
		{config[star_path]} --genomeDir {params.genomeDir} \
		--readFilesIn {params.one} {params.two} \
		--outFileNamePrefix {params.outputPrefix} \
		--readFilesCommand zcat --runThreadN {threads} \
		{params.extra_star_parameters} \
		--outTmpDir {params.outTmpDir}
	"""

rule run_star_se:
	input:
		one = lambda wildcards: get_trimmed(wildcards.name)[0]
	output:
		config['star_output_folder'] + "{name}/Aligned.out.bam"
	params:
		extra_star_parameters = return_parsed_extra_params(config['extra_star_parameters']),
		genomeDir = GENOME_DIR,
		outTmpDir = os.path.join(config['star_output_folder'] + "{name}/_tmpdir"),
		outputPrefix = os.path.join(config['star_output_folder'] + "{name}/"),
		#taking the input files and putting them into a comma separated list
		one = lambda wildcards: ','.join(get_trimmed(wildcards.name)[0])
	threads: 
		4
	shell:
		"""
		{config[star_path]} --genomeDir {params.genomeDir} \
		--readFilesIn {params.one} \
		--outFileNamePrefix {params.outputPrefix} \
		--readFilesCommand zcat --runThreadN {threads} \
		{params.extra_star_parameters} \
		--outTmpDir {params.outTmpDir}
		"""
