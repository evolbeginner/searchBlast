#! /bin/env ruby


########################################################
require 'getoptlong'
require 'parallel'
require 'set'

require 'Dir'
require 'util'
require 'Hash'


########################################################
def  get_res_runGtaBlast(taxon:, infiles:, evalue_cutoff:, h1:, h2:)
  infiles.each do |infile|
    gene = getCorename(infile)
    in_fh = File.open(infile, 'r')
    in_fh.each_line do |line|
      line.chomp!
      line_arr = line.split("\t")
      subject = line_arr[1]
      if line_arr[10].to_f <= evalue_cutoff
        h1[gene][taxon][subject] = 1
        h2[taxon][gene][subject] = 1
      end
    end
    in_fh.close
  end
  return([h1, h2])
end


def get_res_searchInBatch(infiles:, evalue_cutoff:, cpu:, h1:, h2:)
  infiles.each do |infile|
    taxon = getCorename(infile)
    in_fh = File.open(infile, 'r')
    in_fh.each_line do |line|
      line.chomp!
      line_arr = line.split("\t")
      query, gene = line_arr.values_at(0,1)
      if line_arr[10].to_f <= evalue_cutoff
        h1[gene][taxon][query] = 1
        h2[taxon][gene][query] = 1
      end
    end
    in_fh.close    
  end

  return([h1, h2])
end


def getCoor(locus, num_separated_genes=1)
  locus =~ /\d+$/
  coor = ($&.to_i)/num_separated_genes
  return(coor)
end


########################################################
TYPES = %w[gta search]


########################################################
indir = nil
evalue_cutoff = 1e-10
res_outdir = nil
type = nil
is_force = false
cpu = 1
num_separated_genes = 10

gene2taxon2subject2 = multi_D_Hash(3)
taxon2gene2subject2 = multi_D_Hash(3)
taxa = Array.new


########################################################
opts = GetoptLong.new(
  ['--indir', GetoptLong::REQUIRED_ARGUMENT],
  ['-t', '--type', GetoptLong::REQUIRED_ARGUMENT],
  ['-e', '--evalue', GetoptLong::REQUIRED_ARGUMENT],
  ['--res_outdir', GetoptLong::REQUIRED_ARGUMENT],
  ['--force', GetoptLong::NO_ARGUMENT],
  ['--cpu', GetoptLong::REQUIRED_ARGUMENT],
)

opts.each do |opt, value|
  case opt
    when '--indir'
      indir = value
    when '-t', '--type'
      type = value
    when '--evalue', '-e'
      evalue_cutoff = value.to_f
    when '--res_outdir'
      res_outdir = value
    when '--force'
      is_force = true
    when '--cpu'
      cpu = value.to_i
  end
end


if type.nil? or TYPES.select{|i| i =~ /#{type}/i}.empty?
  raise "type #{type} not recognized! Exiting ......"
end


########################################################

def select_operon(taxon2gene2subject2, num_separated_genes)
  num_separated_genes = locus2subject.keys.all?{|locus|locus =~ /[05]$/} ? 5 : 1
  taxon2gene2subject2.each_pair do |taxon, v1|
    subject2gene = Hash.new
    v1.each_pair do |gene, v1|
      v1.keys.map{|k| subject2gene[k]=gene }
    end
    subjects = subject2gene.keys 
    set = subjects.to_set.divide{|i,j| (getCoor(i,num_separated_genes)-getCoor(j,num_separated_genes)).abs <= dist_cutoff}.to_a.map{|i|i.to_a}
  end
end


if type =~ /gta/
  sub_indirs = read_infiles(indir)
  sub_indirs.each do |sub_indir|
    infiles = read_infiles(sub_indir)
    taxon = getCorename(sub_indir)
    taxa << taxon
    gene2taxon2subject2, taxon2gene2subject2 = get_res_runGtaBlast(taxon:taxon, infiles:infiles, evalue_cutoff:evalue_cutoff, h1:gene2taxon2subject2, h2:taxon2gene2subject2)
    #[taxon, gene2taxon2subject2.keys.map{|gene| [gene, gene2taxon2subject2[gene].keys] }]
  end
  select_operon(taxon2gene2subject2, num_separated_genes)
elsif type =~ /search/
  infiles = read_infiles(indir)
  taxa = infiles.map{|i| getCorename(i)}
  gene2taxon2subject2, taxon2gene2subject2 = get_res_searchInBatch(infiles:infiles, evalue_cutoff:evalue_cutoff, cpu:cpu, h1:gene2taxon2subject2, h2:taxon2gene2subject2)
end


########################
if res_outdir.nil?
  puts ['', taxa].join("\t")
  gene2taxon2subject2.each_pair do |gene, v1|
    out = taxa.map{|taxon| v1.include?(taxon) ? v1[taxon].keys.size : 0 }
    puts [gene, out].flatten.join("\t")
  end
else
  mkdir_with_force(res_outdir, is_force)
  gene2taxon2subject2.each_pair do |gene, v1|
    outfile = File.join(res_outdir, gene)
    out_fh = File.open(outfile, 'w')
    taxa_included = taxa.select{|taxon| v1.include?(taxon) }
    #out = taxa_included.map{|taxon| [taxon, v1[taxon].keys].flatten.join("\t") }
    out = taxa.map{|taxon| [taxon, v1.include?(taxon) ? v1[taxon].keys.size : 0].join("\t") }
    out_fh.puts out.flatten.join("\n")
    out_fh.close
  end
end


