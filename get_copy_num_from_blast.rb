#! /bin/env ruby


###########################################
require 'getoptlong'
require 'parallel'

require 'Dir'
require 'util'
require 'Hash'


###########################################
indir = nil
cpu = 1
map_file = nil
species_list_file = nil

gene2taxon2copy = multi_D_Hash(2)
species_mapped = Array.new


###########################################
def read_list_ordered(file)
  array = Array.new
  in_fh = File.open(file, 'r')
  in_fh.each_line do |line|
    line.chomp!
    array << line
  end
  in_fh.close
  return(array)
end


###########################################
opts = GetoptLong.new(
  ['--indir', GetoptLong::REQUIRED_ARGUMENT],
  ['--cpu', GetoptLong::REQUIRED_ARGUMENT],
  ['--map', GetoptLong::REQUIRED_ARGUMENT],
  ['--species_list', GetoptLong::REQUIRED_ARGUMENT],
)


opts.each do |opt, value|
  case opt
    when '--indir'
      indir = value
    when '--cpu'
      cpu = value.to_i
    when '--map'
      map_file = value
    when '--species_list'
      species_list_file = value
  end
end


###########################################
sub_indirs = read_infiles(indir)

species_ori = read_list_ordered(species_list_file)


if ! map_file.nil?
  species2newName = readTbl(map_file)[1]
  species_ori.each do |i|
    species_mapped << species2newName[i]
  end
else
  species_mapped = species_ori
end



###########################################
h = Parallel.map(sub_indirs, in_proecesses: cpu) do |sub_indir|
  taxon = File.basename(sub_indir)
  gene2copy = Hash.new
  Dir.foreach(sub_indir) do |b|
    next if b =~ /^\./
    infile = File.join(sub_indir, b)
    c = getCorename(b) #gene
    copy_num = `grep ">" #{infile} | wc -l`.to_i
    gene2copy[c] = copy_num
  end
  [taxon, gene2copy]
end


h.each do |taxon, gene2copy|
  gene2copy.each_pair do |gene, copy|
    gene2taxon2copy[gene][taxon] = copy
  end
end

puts species_ori.join("\t")
gene2taxon2copy.each_pair do |gene, v|
  if not species_ori.empty?
    puts [gene, species_mapped.map{|i| v.include?(i) ? v[i] : 0}].join("\t")
  else
    puts "species list empty!"
  end
end


