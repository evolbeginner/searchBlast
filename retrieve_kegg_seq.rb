#! /bin/env ruby


###########################################################
DIR = File.dirname(__FILE__)
$: << File.join(DIR, 'lib')


###########################################################
require 'getoptlong'
require 'parallel'
require 'tempfile'

require 'util'
require 'Dir'
require 'kegg'

require_relative '../ortho2cdd/createCddSqliteDb.rb'


###########################################################
def create_pssm(pssm_outdir, db_outdir, gene_outfile, b, fams_included)
  `makeblastdb -in #{gene_outfile} -out #{db_outdir}/#{b} -dbtype prot -parse_seqids`
  tempfile = Tempfile.new(b)
  `bioawk -c fastx '{print ">"$name; print $seq; exit}' #{gene_outfile} > #{tempfile.path}` # output a seq as query
  # create pssm
  `psiblast -query #{tempfile.path} -db #{db_outdir}/#{b} -num_iterations 3 -out_pssm #{pssm_outdir}/#{b}.smp >/dev/null 2>&1`
  # replace Query_1 with the fam name
  fam_name = fams_included[b]
  `export b=#{b}; sed "s/Query_1/${b}/" -i #{pssm_outdir}/#{b}.smp`
end


def makeprofiledb(pssm_outdir, psi_outdir, psi_db_name='psi')
  smp_list = File.join(File.dirname(psi_outdir), 'smp_list')
  `ls -1 #{pssm_outdir}/* > #{smp_list}`
  `makeprofiledb -in #{smp_list} -title psi -out #{psi_outdir}/#{psi_db_name} -dbtype rps`
end


###########################################################
###########################################################
if __FILE__ == $0; then
  $KEGG_DIR = File.expand_path("~/resource/db/kegg/v2017")
  $KEGG_GENE_2_ORTHOs = Array.new
  $KEGG_GENE_2_ORTHOs << File.join($KEGG_DIR, 'kegg_bacteria.gene2ko')
  $KEGG_BLAST_DB = File.join($KEGG_DIR, "blastdb/kegg_prot_bacteria_201704")

  GET_SUBSEQ = File.expand_path("~/tools/self_bao_cun/basic_process_mini/get_subseq.rb")

  infile = nil
  cpu = 1
  fam_list_file = nil
  is_pssm = false
  psi_db_name = 'psi'
  is_diamond = false
  diamond_db_name = 'diamond'
  outdir = nil
  is_force = false
  species_list_file = nil

  gene2ortho = Hash.new
  kos = Hash.new
  fams_included = Hash.new

  cdd_info = Hash.new{|h,k|h[k]={}} # for reading koid.tbl
  cdd_info = read_kegg_tbl(cdd_info)


###########################################################
  opts = GetoptLong.new(
    ['-i', GetoptLong::REQUIRED_ARGUMENT],
    ['--cpu', GetoptLong::REQUIRED_ARGUMENT],
    ['--fam_list', GetoptLong::REQUIRED_ARGUMENT],
    ['--pssm', '--db', GetoptLong::OPTIONAL_ARGUMENT],
    ['--psi_db_name', GetoptLong::REQUIRED_ARGUMENT],
    ['--diamond', GetoptLong::REQUIRED_ARGUMENT],
    ['--outdir', GetoptLong::REQUIRED_ARGUMENT],
    ['--force', GetoptLong::NO_ARGUMENT],
    ['--include_list', GetoptLong::REQUIRED_ARGUMENT],
  )

  opts.each do |opt, value|
    case opt
      when '-i'
        infile = value
      when '--cpu'
        cpu = value.to_i
      when '--fam_list'
        fam_list_file = value
      when '--pssm', '--db'
        is_pssm = true
        psi_db_name = value if not value.nil?
      when '--psi_db_name'
        psi_db_name = value
      when '--diamond'
        is_diamond = true
        diamond_db_name = value if not value.nil?
      when '--outdir'
        outdir = value
      when '--force'
        is_force = true
      when '--include_list'
        species_list_file = value
    end
  end

###########################################################
  gene_list_outdir = File.join(outdir, "gene_list")
  gene_outdir = File.join(outdir, "gene")
  db_outdir = File.join(outdir, "db")
  mkdir_with_force(outdir, is_force)
  mkdir_with_force(gene_list_outdir, is_force)
  mkdir_with_force(gene_outdir, is_force)
  mkdir_with_force(db_outdir, is_force)

  if is_pssm
    pssm_outdir = File.join(outdir, 'pssm'); mkdir_with_force(pssm_outdir, is_force)
    psi_outdir = File.join(outdir, 'psi'); mkdir_with_force(psi_outdir, is_force)
  end

  including_kos = read_list(infile) if not infile.nil?

  fams_included = read_list(fam_list_file) if not fam_list_file.nil?

  # read_koid.tbl
  cdd_info = read_kegg_tbl(cdd_info)


###########################################################
  $KEGG_GENE_2_ORTHOs.each do |kegg_gene_2_ortho|
    # here kegg_gene_2_ortho is a file
    gene2ortho.merge!(getGene2Ortho(kegg_gene_2_ortho, including_kos))
  end

  Parallel.map(gene2ortho, in_processes: cpu) do |gene, ko|
    # create gene_lists
    outfile = File.join(gene_list_outdir, ko)
    `cat <<< #{gene} >> #{outfile}`
  end

  gene_list_files = read_infiles(gene_list_outdir)
  Parallel.map(gene_list_files, in_threads: cpu) do |gene_list_file|
    # retrieve genes
    ko = File.basename(gene_list_file)
    name = cdd_info.include?(ko) ? cdd_info[ko]['gene'].split(/,|\s+/)[0] : ko
    gene_list_file = File.join(gene_list_outdir, ko) # here is "ko"
    gene_outfile = File.join(gene_outdir, name+'.fas')
    `blastdbcmd -db #{$KEGG_BLAST_DB} -entry_batch #{gene_list_file} 1>#{gene_outfile} 2>/dev/null`
    `ruby #{GET_SUBSEQ} -i #{gene_outfile} | sponge #{gene_outfile}`

    # select taxa
    `ruby #{GET_SUBSEQ} -i #{gene_outfile} --seq_from_file #{species_list_file} | sponge #{gene_outfile}` unless species_list_file.nil?

    # create pssm
    if is_pssm
      create_pssm(pssm_outdir, db_outdir, gene_outfile, name, fams_included)
    end
  end

  if is_pssm
    makeprofiledb(pssm_outdir, psi_outdir, psi_db_name)
    #FileUtils.cp(fam_list_file, File.join(psi_outdir, 'fam.list'))
    fam_list_outfile = File.join(psi_outdir, 'fam.list')
    genes = Dir.glob(db_outdir + "/*.phr").map{|i|getCorename(i)}
    genes.each do |gene|
      `echo -e #{gene}"\t"#{gene} >> #{fam_list_outfile}`
    end
    `cp #{species_list_file} #{psi_outdir}` unless species_list_file.nil?
  end

  if is_diamond
    `diamond makedb --in #{} -d kegg -p 12`
  end

end


