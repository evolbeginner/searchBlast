#! /usr/bin/env ruby


#################################################################
require 'getoptlong'
require 'bio'

require 'Dir'
require 'processbar'


#################################################################
blast_indir = nil
seq_indir = nil
outfile = nil


#################################################################
class String
  def getCorename
    rv = File.basename(self)
    if rv =~ /([^.]+)/
      rv = $1
    end
    return(rv)
  end
end


class InfileInfo
  attr_accessor :seq, :blast
end


#################################################################
def getInfileForEachCorname(infileInfos, infiles, type)
  infiles.each do |infile|
    corename = infile.getCorename
    infileInfos[corename].instance_variable_set(type, infile)
  end
  return(infileInfos)
end


def read_blast_file(infile)
  queries = Hash.new
  in_fh = File.open(infile, 'r')
  in_fh.each_line do |line|
    line.chomp!
    line_arr = line.split("\t")
    query = line_arr[0].split(' ')[0]
    queries[query] = ''
  end
  in_fh.close
  return(queries)
end


def read_seq_file(infile)
  in_fh = File.open(infile, 'r')
  seq_objs = Array.new

  seq_title = nil
  in_fh.each_line do |line|
    line.chomp!
    if $. % 2 == 1
      line =~ /^>([^ ]+)/
      seq_title = $1
    else
      seq_objs << seq_title
    end
  end
  in_fh.close
  return(seq_objs)
end


#################################################################
if __FILE__ == $0
  opts = GetoptLong.new(
    ['--blast_dir', '--blast_indir', GetoptLong::REQUIRED_ARGUMENT],
    ['--seq_dir', '--seq_indir', GetoptLong::REQUIRED_ARGUMENT],
    ['-o', GetoptLong::REQUIRED_ARGUMENT],
  )


  opts.each do |opt, value|
    case opt
      when /^--(blast_dir|blast_indir)$/
        blast_indir = value
      when /^--(seq_dir|seq_indir)$/
        seq_indir = value
      when /^-o$/
        outfile = value
    end
  end


  #################################################################
  out_fh = File.open(outfile, 'w')
  blast_infiles = read_infiles(blast_indir)
  seq_infiles = read_infiles(seq_indir)


  infileInfos = Hash.new{|h,k|h[k] = InfileInfo.new}
  infileInfos = getInfileForEachCorname(infileInfos, blast_infiles, :@blast)
  infileInfos = getInfileForEachCorname(infileInfos, seq_infiles, :@seq)

  count = 0
  infileInfos.delete_if{|k,v|v.blast.nil?}

  infileInfos.each_pair do |corename, infileInfo|
    out_fh.print corename + "\t"
    seq_objs = read_seq_file(infileInfo.seq)
    queries = read_blast_file(infileInfo.blast)
    intersect = Hash.new
    intersect[:full] = seq_objs & queries.keys
    intersect[:top_100] = (seq_objs[0,100] & queries.keys).sort #2 sorts
    intersect[:tail_100] = (seq_objs.reverse[0,100] & queries.keys).sort #2sorts
    intersect[:tail_20] = (seq_objs.reverse[0,20] & queries.keys).sort #2sorts
    out_fh.print [intersect[:full].size, seq_objs.size].join("\t") + "\t"
    [:full, :top_100, :tail_100, :tail_20].each do |type|
      v = intersect[type]
      total = (type == :full) ? seq_objs.size : 100 
      out_fh.print (v.size.to_f/total).round(2).to_s + "\t"
    end
    out_fh.puts

    count += 1
    processbar(count, infileInfos.size)
  end

  out_fh.close
end


