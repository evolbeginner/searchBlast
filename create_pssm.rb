#! /bin/env ruby


###########################################################
DIR = File.dirname(__FILE__)
$: << File.join(DIR, 'lib')
$: << DIR


###########################################################
require 'getoptlong'

require 'retrieve_kegg_seq'
require 'util'


###########################################################
$KEGG_DIR = File.expand_path("~/resource/db/kegg/v2017")
$KEGG_GENE_2_ORTHOs = Array.new
$KEGG_GENE_2_ORTHOs << File.join($KEGG_DIR, 'kegg_bacteria.gene2ko')
$KEGG_BLAST_DB = File.join($KEGG_DIR, "blastdb/kegg_prot_bacteria_201704")

indir = nil
cpu = 1
is_pssm = false
psi_db_name = 'psi'
outdir = nil
is_force = false

infiles = Array.new
fams_included = Hash.new


###########################################################
###########################################################
if __FILE__ == $0; then

  opts = GetoptLong.new(
    ['--indir', GetoptLong::REQUIRED_ARGUMENT],
    ['--cpu', GetoptLong::REQUIRED_ARGUMENT],
    ['--pssm', GetoptLong::NO_ARGUMENT],
    ['--psi_db_name', GetoptLong::REQUIRED_ARGUMENT],
    ['--outdir', GetoptLong::REQUIRED_ARGUMENT],
    ['--force', GetoptLong::NO_ARGUMENT]
  )

  opts.each do |opt, value|
    case opt
      when '--indir'
        indir = value
      when '--cpu'
        cpu = value.to_i
      when '--pssm'
        is_pssm = true
      when '--psi_db_name'
        psi_db_name = value
      when '--outdir'
        outdir = value
      when '--force'
        is_force = true
    end
  end

###########################################################
  db_outdir = File.join(outdir, "db")
  pssm_outdir = File.join(outdir, 'pssm')
  psi_outdir = File.join(outdir, 'psi')

  mkdir_with_force(outdir, is_force)
  mkdir_with_force(db_outdir, is_force)
  mkdir_with_force(pssm_outdir, is_force)
  mkdir_with_force(psi_outdir, is_force)

  infiles = read_infiles(indir)


###########################################################
  Parallel.map(infiles, in_threads: cpu) do |infile|
    b = File.basename(infile)
    b.sub!(/\.(fas|fasta)$/, '')
    fams_included[b] = b
    create_pssm(pssm_outdir, db_outdir, infile, b, fams_included)
  end

  makeprofiledb(pssm_outdir, psi_outdir, psi_db_name)

def output_fam_list(infiles, outdir)
  out_fh = File.open(File.join(outdir, 'fam.list'), 'w')
  infiles.each do |infile|
    c = getCorename(infile)
    out_fh.puts [c, c].join("\t")
  end
  out_fh.close
end
  output_fam_list(infiles, psi_outdir)

end


