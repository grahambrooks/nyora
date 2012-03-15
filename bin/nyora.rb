require 'fileutils'
require File.join(File.dirname(File.expand_path(__FILE__)), 'lib_trollop.rb')

module Nyora
  TAG_PREFIX = "//NYORA"

  class LineTagger
    def initialize(start_line, end_line, set)
      @tags            = []
      @high_water_mark = 1
      add_block start_line, end_line, set
    end

    def add_block(start_line, end_line, set)
      @tags << [@high_water_mark, start_line, end_line, set]
      @high_water_mark += 1
    end

    def tag_line(line_number, output, current_filename)
      @tags.each do |tag|
        if line_number == tag[1]
          output.puts TAG_PREFIX + "//" * 50
          output.puts TAG_PREFIX + " TODO: START Duplication block #{tag[0]}"
          tag[3].print(output, current_filename)
        end
        output.puts TAG_PREFIX + " TODO: END Duplication Block #{tag[0]}" if line_number == tag[2]
      end
    end
  end

  class TaggedSet
    def initialize
      @set = []
    end

    def add(filename, start_line)
      @set << [filename, start_line]
    end

    def print(stream, current_filename)
      @set.each do |filename, start_line|
        stream.puts "#{TAG_PREFIX} #{File.basename(filename)} around line #{start_line}" unless filename == current_filename
      end
    end
  end

  class DuplicateTagger
    def initialize
    end

    def self.parse_emacs_format_log_file(input_file)
      files_with_duplicates = {}
      current_tagset        = TaggedSet.new

      File.open input_file do |f|
        f.each_line do |line|
          if line =~ / ([^:]+):(\d+):1:(\d+):1:/
            current_tagset.add $1, $2
            if files_with_duplicates[$1].nil?
              files_with_duplicates[$1] = LineTagger.new($2.to_i, $3.to_i, current_tagset)
            else
              files_with_duplicates[$1].add_block $2.to_i, $3.to_i, current_tagset
            end
          else
            current_tagset = TaggedSet.new
          end
        end
      end
      files_with_duplicates
    end


    def self.tag_file(filename, tags)
      puts "Tagging #{filename}"
      tagged_filename = filename + '.tagged'

      File.open(filename) do |input|
        File.open(tagged_filename, "w") do |output|
          line_number = 1

          input.each_line do |line|
            if line =~ /\/\/NYORA.*/
              # Ignore
            else
              tags.tag_line(line_number, output, filename)
              output.print line
              line_number += 1
            end
          end
        end
      end
      FileUtils.cp(tagged_filename, filename)
      FileUtils.rm(tagged_filename)
    end

    def self.clean_file(filename)
      puts "Cleaning #{filename}"
      cleaned_fileanme = filename + '.cleaned'

      File.open(filename) do |input|
        File.open(cleaned_fileanme, "w") do |output|
          input.each_line do |line|
            unless line =~ /\/\/NYORA.*/
              output.print line
            end
          end
        end
      end

      FileUtils.cp(cleaned_fileanme,filename)
      FileUtils.rm(cleaned_fileanme)
    end

    def self.tag(input_file)
      files_with_duplicates = parse_emacs_format_log_file(input_file)
      
      files_with_duplicates.each do |filename, tags|
        tag_file filename, tags
      end
    end

    def self.clean_tags(input_file)
      files_with_duplicates = parse_emacs_format_log_file(input_file)
      
      files_with_duplicates.each do |filename, tags|
        clean_file filename
      end
    end

    def self.execute(args)
      opts = Trollop::options do
        version "nyorat 0.0.1 (c) 2012 Graham Brooks"
        banner <<-EOS
Nyora tags C sytle languages by reading an emacs formatted duplication report

Usage:
       nyora [options] <filenames>+
where [options] are:
EOS

        opt :clean, "Remove NYORA comment tags from files"
      end

      args.each do |input_file|
        opts[:clean] ? clean_tags(input_file) : tag(input_file)
      end
    end
  end
end
