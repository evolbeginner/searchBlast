#! /usr/bin/env ruby


def getSpeciesNameRela(infiles)
  out2in = Hash.new
  in2out = Hash.new
  infiles.each do |infile|
    in_fh = File.open(infile, 'r')
    in_fh.each_line do |line|
      line.chomp!
      names = line.split("\t")
      outName, inName = names
      out2in[outName] = inName
      in2out[inName] = outName
    end
    in_fh.close
  end
  return([out2in, in2out])
end


def getGenomeBasicInfo(infile)
  h = Hash.new{|h,k|h[k]={}}
  in_fh = File.open(infile, 'r')
  in_fh.each_line do |line|
    line.chomp!
    line_arr = line.split("\t")
    taxon = line_arr[0]
    h[taxon][:len] = line_arr[1].to_f
    h[taxon][:gc] = line_arr[2].to_f
  end
  in_fh.close
  return(h)
end


def getCorename(infile, is_strict=false)
  b = File.basename(infile)
  if not is_strict
    b =~ /(.+)\..+$/
  else
    b =~ /^([^.]+)/
  end
  c = $1
  return(c)
end


