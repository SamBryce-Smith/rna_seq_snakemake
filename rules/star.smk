import os
configfile: "config/config.yaml"
cluster_config: "config/cluster.yaml" 
include: "helpers.py"
#RULE ORDER DIRECTIVE 
#if paired end, use the paired end rule to run, if single end use the single end rule to run
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

FASTQ_NAME = [re.sub(".fastq.gz","",strpd.rpartition('/')[2]) for strpd in SAMPLES['fast1'].tolist()]
FASTQ_NAME2 = [re.sub(".fastq.gz","",strpd.rpartition('/')[2]) for strpd in SAMPLES['fast2'].tolist()]

#this function uses the text file located in the config folder "star_genomes_species.csv" and 
#the config file species parameter to 
#give the correct genome for the species
GENOME_DIR = get_genome_directory(config['species'])
		
all_trimmed_one = expand(config["fastp_trimmed_output_folder"] + "{unit}/{fastq_name}_trimmed.fastq.gz",zip, unit = UNITS, fastq_name=FASTQ_NAME)
all_trimmed_two = expand(config["fastp_trimmed_output_folder"] + "{unit}/{fastq_name}_trimmed.fastq.gz",zip, unit = UNITS, fastq_name=FASTQ_NAME2),


rule all_star:
	input:
		expand(config['star_output_folder'] + "{name}/{name}.SJ.out.tab", name = SAMPLE_NAMES),
		expand(config['star_output_folder'] + "{name}/{name}.Log.final.out",name = SAMPLE_NAMES),
		expand(config['star_output_folder'] + "{name}/{name}.Aligned.out.bam",name = SAMPLE_NAMES)


rule run_star_pe:
	input:
		one = lambda wildcards: get_trimmed(wildcards.name)[0],
		two = lambda wildcards: get_trimmed(wildcards.name)[1],
		all_trimmed_one,
		all_trimmed_two
	output:
		config['star_output_folder'] + "{name}/{name}.SJ.out.tab",
		config['star_output_folder'] + "{name}/{name}.Log.final.out",
		config['star_output_folder'] + "{name}/{name}.Aligned.out.bam",name = SAMPLE_NAMES

	params:
		extra_star_parameters_first_pass = return_parsed_extra_params(config['extra_star_parameters_first_pass']),
		genomeDir = GENOME_DIR,
		outTmpDir = os.path.join(config['star_output_folder'] + "{name}/_tmpdir"),
		outputPrefix = os.path.join(config['star_output_folder'] + "{name}/{name}."),
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
		{params.extra_star_parameters_first_pass} \
		--outTmpDir {params.outTmpDir}
	"""

rule run_star_se:
	input:
		one = lambda wildcards: get_trimmed(wildcards.name)[0],
		all_trimmed_one
	output:
		config['star_output_folder'] + "{name}/{name}.SJ.out.tab",
		config['star_output_folder'] + "{name}/{name}.Log.final.out"
	params:
		extra_star_parameters_first_pass = return_parsed_extra_params(config['extra_star_parameters_first_pass']),
		genomeDir = GENOME_DIR,
		outTmpDir = os.path.join(config['star_output_folder'] + "{name}/_tmpdir"),
		outputPrefix = os.path.join(config['star_output_folder'] + "{name}/{name}."),
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
		{params.extra_star_parameters_first_pass} \
		--outTmpDir {params.outTmpDir}
		"""

