#file: log_analysis.rb

require 'rubygems'

##
# scan the root dir and create a list of all files in it
class FileScanDir
  attr_accessor :result_list, :dir_list  

  def initialize
    @explore_dir = []
    @filter_dir = []
    @result_list = []
    @filter_file = []
    @dir_list = []
    @admitted_extension = []
  end
  
  def log(str)
    puts str
  end
  
  ##
  # Add an array of directories to be filtered
  def add_dir_filter(filter)
    @filter_dir = filter
  end
  
  ##
  # Add an array of file that don't belong to the list
  def add_file_filter(file_filter)
    @filter_file = file_filter
  end
  
  ##
  # Scan a root dir and list all files. Exclude filtered directory
  def scan_dir (dirname)
    log "*** Inspect: " + dirname
    Dir.foreach(dirname) do |filename|
      path_cand = File.join(dirname , filename)
      if File.directory?(path_cand)
        #exams directories
        if (filename != "." && filename != "..")
          unless @filter_dir.index(filename)
            #directory not filtered
            @explore_dir.push(path_cand)
            @dir_list << path_cand
          end
        end
      else
        # file to be listed
        unless file_is_filtered?(path_cand)
          # file is not filtered
          #p path_cand
          if file_has_admitted_extension?(path_cand)
            @result_list.push(path_cand)
          end
        end
      end #file.directory?
    end
    next_dir = @explore_dir.pop
    scan_dir(next_dir) if next_dir 
  end # end scan dir
  
  def add_admitted_extension(ext_array)
    @admitted_extension = ext_array
  end
  
  def file_has_admitted_extension?(path_cand)
    return true if @admitted_extension.size == 0
    extension = File.extname(path_cand)
    if @admitted_extension.index(extension)
      return true
    end
    return false
  end
  
  ##
  # Check if a file belongs to a filtered list
  def file_is_filtered?(path_cand)
    filename = File.basename(path_cand)
    ix = @filter_file.index(filename)
    if ix
      log "FILTER: #{path_cand}" 
      return true
    else
      return false
    end
  end
  
  ##
  # Write the list into a file
  def write_filelist(out_file_list)
    result_list.each{|f| log f}
    File.open(out_file_list, "w") do |file|
        result_list.each do |item| 
        file << item
        file << "\n"
      end
      log "File list created #{out_file_list}"
    end 
  end 
end#end class FileScanDir

class LogServerAnalysis
  def start(dir_root, res_file)
    @warn_list = []
    @err_list = []
    @all_logs = []
    fscd = FileScanDir.new
    fscd.add_admitted_extension(['.log'])
    fscd.scan_dir(dir_root)
    fscd.result_list.each do |fname|
      process_file( fname)
    end
    
    dump_logs_in_file(res_file)
  end
  
  def process_file(fname)
    log "Process file #{fname}"
    File.open(fname, "r").each_line do |line|
      if line =~ /ERR/
        @err_list << line
        log line
      elsif line =~ /WARN/
        @warn_list << line
        log line
      end
    end
  end
  
  def dump_logs_in_file(res_file)
    File.open(res_file, "w") do |file|
      @all_logs.each do |item| 
        file << item
        file << "\n"
      end
    end
    log "Result file created #{res_file}"
  end
  
  def log(str)
    puts str
    if @all_logs.size == 10000
      @all_logs << "Truncate to 1000 entries..."
    end
    @all_logs << str if @all_logs.size < 10000
  end
end


if $0 == __FILE__
  analizer = LogServerAnalysis.new
  #analizer.start('C:\Biblio\ruby\ConsoleApplication1\target_logs', 'res.txt')
  analizer.start('C:\Biblio\ruby\serverlogs', 'res.txt')
  #analizer.start('/home/igor/logs/080', 'res.txt')
end