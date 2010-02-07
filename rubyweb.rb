#!/usr/local/bin/ruby -w

=begin rubyweb
=begin_chunk introduction

rubyweb.  A simple WEB for the Ruby Language.


The pupose of this tool is to allow flexible documentation of
code for ruby programs, so that text need not be separate from the
code.  It is loosly based on the Literate Programming idea, 
and its principle differences from RDtool are 
   * it will allow documents to occur in a different order in the file
     from the order they appear in the output.
   * It does no formatting of the text itself.
It is therefore intended as a supplement to RDtool.

=end_chunk introduction
=begin_chunk authorship
Author: Hugh Sasse
Institution: De Montfort University, Leicester, England

RCS information:
$Id: rubyweb.rb,v 1.11 2000-09-29 18:17:47+01 hgs Exp hgs $
=end_chunk authorship

=begin_chunk rationale
Basic Concept.

There is a need to keep documentation with the code, as is
done with =begin and =end, for example with RDtool.  

The different forms of documentation have different requirements
so that for a user manual, documentaion would be diferent from
that for a library reference manual.  Also the grouping of
ideas in a program will be different from that needed in any manual.

=end_chunk rationale
=begin_chunk terminology
It is useful to be able to searate out the intentional
aspects of writing into "streams" and separate the logical
collections of information into "chunks".  In this way a stream
will consist of many chunks, and a given chunk may need to 
have parts of it dedicated to one stream.
=end_chunk terminology
=begin_chunk design_notes
A large project will span several files, so it is necessary to
be able  to group these together in an orderd manner. Because
there may have multiple authors (e.g for libraries) who may not
communicate the following constraints can be arrived at.

* Streams may be spread out in parts over a file.

* Text within a stream may be useable by several streams.

* It may be helpful to begin or end several streams at the
  same place.

* There may be a need to have streams overlap.

* There may be a need to have chunks overlap.

* A chunk may contains several streams, and a stream may 
  contain several chunks.

* However, chunks cannot overlap streams, or vice versa.
  This last constraint may not be absolutely necessary, but
  it simplifies things.

The commands to begin and end streams should not control
all the streams at once, because then included files would
need to know about the streams in all files that include them.

The above is true for chunks as well. 
=end_chunk design_notes
=begin_chunk not_implemented
A naming conventiong must be used so that names local to the file
can be distinguished from those accessible across all files.

=end_chunk not_implemented

=begin_chunk terminology
As well as needing to include other files with an =include
statement, sometimes code fragments (outside
the =begin rubyweb...=end_rubyweb
block) must make it into the documentation. An =include_code
directive could be used for this, collecting all the code up
to the next =begin rubyweb.
=end_chunk terminology

=begin_chunk not_implemented
In the future it may be useful to include documentation from the
WWW, so the include facility should be expandable to cover URLs.

=end_chunk not_implemented

=begin_chunk features
There may be a need to produce output that can be fed into
other Ruby documentation processors, such as RDtool.  For 
this =print should allow the copying to output of a line
that would oterwise begin with =<command>. Few assumptions
should be made about what takes the output of this tool.

Because some data may only make sense when directed into
particular programs support is provided to pipint the output
to a command with the =pipe_chunk and =pipe_stream directives.
Similarly information may be put into a file with the =output_chunk
and =output_stream directives.  To pruduce the output on 
STDOUT use =display_chunk and display_stream instead.
=end_chunk features

=begin_chunk structure
Having described the data types (streams, code and chunks)
some grouping and structuring commands are needed, so that
streams can be collected into large streams, and the order
of output can be specidied independently of the order in 
the file.

commands =use and =display should fulfil this purpose; use
will tell a stream what chunks to use.  Display will determine
what is actually output.  The syntax of display must allow
output to a file.
=end_chunk structure

=end rubyweb

=begin rubyweb
=begin_chunk internal_state
The state object holds the state information for the parser of
the web documents.  Because it is necessary to allocate text to
different streams and chunks, or possibly none, the state keeps
a record of which streams and chunks are currently in use.
=end_chunk internal_state
=end rubyweb

class State
    attr_accessor :in_streams	# the streams we are in
    attr_accessor :in_chunks	# the chunks we are in
    attr_accessor :in_rubyweb	# if we are in any rubyweb regions
    attr_accessor :include_code	# If we are inluding this code in the docs

    def initialize()
        @in_streams = []
        @in_chunks = []
        @in_rubyweb = false
        @include_code = false
    end
end


=begin rubyweb
=begin_chunk internal_rubyweb
The rubyweb object holds all the information about the structure
of the WEB document, and has all the methods for handling it.
=end_chunk internal_rubyweb
=end rubyweb

class Rubyweb
    attr_accessor :display_streams
    attr_accessor :display_chunks
    attr_accessor :output_streams
    attr_accessor :output_chunks
    attr_accessor :pipe_streams
    attr_accessor :pipe_chunks
    attr_accessor :allow_display
    attr_accessor :allow_output
    attr_accessor :allow_pipe
    attr_accessor :included_files
    attr_accessor :list_streams
    attr_accessor :list_chunks

    def initialize()
	@state = State.new
        @chunks = Hash.new()
        @streams = Hash.new()
        @lines = []
        @line_index = 0
        @expanding = []
        @expand_indent = 0
        @oldline = nil
        @display_streams = []
        @display_chunks = []
        @output_streams = []
        @output_chunks = []
        @pipe_streams = []
        @pipe_chunks = []
        @list_streams = false
        @list_chunks = false
        @allow_display = true
        @allow_output = false
        @allow_pipe = false
        @included_files = []
    end

=begin rubyweb
=begin_chunk internal_process_line
process_line is the parser for the rubyweb language.
It works on a line by line basis, but folding of lines bu the use
of a trailing \ is supported
=end_chunk internal_process_line
=end rubyweb

    def process_line(line)
        # print self.inspect  if $debugging
        # print "line is #{p line}"  if $debugging
        if @oldline
           line.sub!(/^\s+/, " ")
           line = @oldline + line
           @oldline = nil
        end
        if line =~ /\\$/
           print $'  if $debugging
           @oldline = $`
           return
        end 

	case @state.in_rubyweb
	    when true
		if line =~ /^=begin[ _]rubyweb/i
		    raise "already in rubyweb"
                    return
                end
		if line =~ /^=end[ _]rubyweb/i
                    @state.in_rubyweb = false
                    return
                end
                if line =~ /^=include\s+(\S+)/i
                    file_to_include = $1
                    if @included_files.index(file_to_include)
                        raise "already included #{file_to_include} in #{@included_files.inspect}\n"
                    else
                        @included_files.push(file_to_include)
			@state.in_rubyweb = false
			file = open(file_to_include,"r")
			file.readlines.each do
			    |fline|
			    process_line(fline)
			end
			file.close
			@state.in_rubyweb = true
                        @included_files.pop
                    end
                    return
                end
                if line =~ /^=begin_stream\s+((\w+\s*)+)/i
                    $1.split(/\s+/).each do
                        |word|
			@state.in_streams.push(word).uniq!
                        print "@state.in_streams is #{@state.in_streams.inspect}\n"  if $debugging
                        print "@streams is #{@streams.inspect}\n"  if $debugging
                    end
                    return
                end
                if line =~ /^=end_stream\s+((\w+\s*)+)/i
                    $1.split(/\s+/).each do
                        |word|
			@state.in_streams.delete(word)
                        print "@state.in_streams is #{@state.in_streams.inspect}\n"  if $debugging
                        print "@streams is #{@streams.inspect}\n"  if $debugging
                    end
                    return
                end
                if line =~ /^=begin_chunk\s+((\w+\s*)+)/i
                    $1.split(/\s+/).each do
                        |word|
			@state.in_chunks.push(word).uniq!
                        print "@state.in_chunks is #{@state.in_chunks.inspect}\n"  if $debugging
                        print "@chunks is #{@chunks.inspect}\n"  if $debugging
                    end
                    return
                end
                if line =~ /^=end_chunk\s+((\w+\s*)+)/i
                    $1.split(/\s+/).each do
                        |word|
			@state.in_chunks.delete(word)
                        print "@state.in_chunks is #{@state.in_chunks.inspect}\n"  if $debugging
                    end
                    return
                end
                if line =~ /^=use_stream\s+((\w+\s*)+)/i
                    # This may ba a reference we cannot resolve yet.
                    # so insert the line literally
		    @state.in_streams.each do
			|str|
			@streams[str] ||= []
			@streams[str].push(line)
		    end
		    @state.in_chunks.each do
			|chnk|
			@chunks[chnk] ||= []
			@chunks[chnk].push(line)
                        print "@chunks is #{@chunks.inspect}\n"  if $debugging
		    end
                    return
                end
                if line =~ /^=use_chunk\s+(\w+\s*)/i
                    # This may ba a reference we cannot resolve yet.
                    # so insert the line literally
		    @state.in_chunks.each do
			|chnk|
			@chunks[chnk] ||= []
			@chunks[chnk].push(line)
                        print "@chunks is #{@chunks.inspect}\n"  if $debugging
		    end
		    @state.in_streams.each do
			|str|
			@streams[str] ||= []
			@streams[str].push(line)
		    end
                    return
                end
                if line =~ /^=display_stream\s+(\w+)/
                    if @allow_display
			@display_streams.push($1).uniq!
                    end
                    return
                end
                if line =~ /^=display_chunk\s+(\w+)/
                    if @allow_display
			@display_chunks.push($1).uniq!
                    end
                    return
                end
                if line =~ /^=output_stream\s+(\w+)\s+([\w\:\.\\\/]+)/
                    if @allow_output
			@output_streams.push($1)
			@output_streams.push($2)
                    end
                    return
                end
                if line =~ /^=output_chunk\s+(\w+)\s+([\w\:\.\\\/]+)/
                    if @allow_output
			@output_chunks.push($1)
			@output_chunks.push($2)
                    end
                    return
                end
                if line =~ /^=pipe_stream\s+(\w+)\s+(.*)/
                    if @allow_pipe
			@pipe_streams.push($1)
			@pipe_streams.push($2)
                    end
                    return
                end
                if line =~ /^=pipe_chunk\s+(\w+)\s+(.*)/
                    if @allow_pipe
			@pipe_chunks.push($1)
			@pipe_chunks.push($2)
                    end
                    return
                end
                if line =~ /^=include_code/i
                    @state.include_code = true 
                    return
                end
                if line =~ /^=print\s/i
                    line = $'
                end
                @lines.push(line)
                @state.in_streams.each do
                    |str|
                    @streams[str] ||= []
                    @streams[str].push(@line_index)
                end
                print "going through @state.in_chunks\n"  if $debugging
                @state.in_chunks.each do
                    |chnk|
                    # print "chnk is #{chnk.inspect}\n"  if $debugging
		    # print "@chunks.type is #{@chunks.type}\n"  if $debugging
		    # print "@chunks is #{@chunks.inspect}\n"  if $debugging
                    # print "@chunks[chnk].type is #{@chunks[chnk].type}\n"  if $debugging
                    # print "@chunks[chnk] is #{@chunks[chnk].inspect}\n"  if $debugging
                    @chunks[chnk] ||= []
                    @chunks[chnk].push(@line_index)
		    # print "@chunks.type is #{@chunks.type}\n"  if $debugging
		    # print "@chunks is #{@chunks.inspect}\n"  if $debugging
                    # print "@chunks[chnk].type is #{@chunks[chnk].type}\n"  if $debugging
                    # print "@chunks[chnk] is #{@chunks[chnk].inspect}\n"  if $debugging
                end

                @line_index += 1

	    when false
		if line =~ /^=begin[ _]rubyweb/i
		    @state.in_rubyweb = true
                    @state.include_code = false # reset this
                    return
                end
                if @state.include_code 
		    @lines.push(line)
		    @state.in_streams.each do
			|str|
			@streams[str] ||= []
			@streams[str].push(@line_index)
		    end
		    print "going through @state.in_chunks\n"  if $debugging
		    @state.in_chunks.each do
			|chnk|
			@chunks[chnk] ||= []
			@chunks[chnk].push(@line_index)
		    end

		    @line_index += 1
                end
		if line =~ /^=end[ _]rubyweb/i
                    raise "already outside rubyweb"
                    return
                end
	    else
		raise "@state.in_rubyweb should be true or false, not #{@state.in_rubyweb}"
        end # case
    end


=begin rubyweb
=begin_chunk expanding_nested_refs
Because streams may enclose chunks or streams, and so may chunks, and
because they may rference each other, some means is needed to resolve
all the references.  A stream cannot use itself because this would 
result in infinite recursion, so since this must be avoided recursion
my be used in expanding the streams or chunks
=end_chunk expanding_nested_refs
=end rubyweb

    def expand_stream(astream)
        if @expanding.index("stream #{astream}")
            raise "already expanding stream #{astream}\n expanding #{@expanding.inspect}"
        end

        results = []

	@expanding.push("stream #{astream}")
        @expand_indent += 1
        exp = " " * @expand_indent
	print "#{exp}expanding stream #{astream}\n expanding is #{@expanding.inspect}\n"  if $debugging
	@streams[astream].each do
	    |aline|
            print "#{exp}expand_stream: aline.type is #{aline.type}\n"  if $debugging
            unless aline.type == "String".type
                 print "#{exp}#{aline}\n"  if $debugging
                 results.push(aline)
            else
                if aline =~ /^=use_chunk ((\w+\s*)+)/i
                    $1.split(/\s+/).each do
                        |chnk|
                        print "#{exp}chnk is #{chnk}\n"  if $debugging
			results += expand_chunk(chnk)
                    end
                end
                if aline =~ /^=use_stream ((\w+\s*)+)/i
                    $1.split(/\s+/).each do
                        |strm|
                        print "#{exp}strm is #{strm}\n"  if $debugging
			results += expand_stream(strm)
                    end
                end
            end
	end
	@expanding.pop
        @expand_indent -= 1
        exp = " " * @expand_indent
	@streams[astream] = results
	print "#{exp}#{astream} expanded\n"  if $debugging
	print "#{exp}@streams is #{@streams.inspect}\n"  if $debugging
        return results
    end

    def expand_chunk(achunk)
        if @expanding.index("chunk #{achunk}")
            raise "already expanding chunk #{achunk}\n expanding #{@expanding.inspect}"
        end

        results = []

	@expanding.push("chunk #{achunk}")
        @expand_indent += 1
        exp = " " * @expand_indent
	print "#{exp}expanding chunk #{achunk}\n expanding is #{@expanding.inspect}\n"  if $debugging
	@chunks[achunk].each do
	    |aline|
            print "#{exp}expand_chunk: aline.type is #{aline.type}\n"  if $debugging
            unless aline.type == "String".type
                 print "#{exp}#{aline}\n"  if $debugging
                 results.push(aline)
            else
                changed = true
                if aline =~ /^=use_chunk ((\w+\s*)+)/i
                    $1.split(/\s+/).each do
                        |chnk|
                        print "#{exp}chnk is #{chnk}\n"  if $debugging
			results += expand_chunk(chnk)
                    end
                end
                if aline =~ /^=use_stream ((\w+\s*)+)/i
                    $1.split(/\s+/).each do
                        |strm|
                        print "#{exp}strm is #{strm}\n"  if $debugging
			results += expand_stream(strm)
                    end
                end
            end
	end
	@expanding.pop
        @expand_indent -= 1
        exp = " " * @expand_indent
	@chunks[achunk] = results
	print "#{exp}#{achunk} expanded\n"  if $debugging
	print "#{exp}@chunks is #{@chunks.inspect}\n"  if $debugging
        return results
    end

=begin rubyweb
=begin_chunk expanding_nested_refs

all the references are to be expanded once the files have been
read in.
=end_chunk expanding_nested_refs
=end rubyweb

    def expand_references()
        print "in expand references\n"  if $debugging
        @streams.each_key do
            |astream|
            print "To expand stream #{astream}\n"  if $debugging
            expand_stream(astream)
        end
        @chunks.each_key do
            |achunk|
            print "To expand chunk #{achunk}\n"  if $debugging
            expand_chunk(achunk)
        end
    end

=begin rubyweb
=begin_chunk internal_stream_text
The funtion stream_text produces the text from a stream. If there
is no such stream then it raises an exception.  This is a common
factor to all the stream outputting functions.
=end_chunk internal_stream_text
=end rubyweb
    def stream_text(astream)
        if @streams[astream]
            text = ""
	    @streams[astream].each do
		|line|
		text += @lines[line]
	    end 
        else
            raise "There is no stream \'#{astream}\'\n"
        end
        return text
    end

=begin rubyweb
=begin_chunk internal_chunk_text
The funtion stream_text produces the text from a stream. If there
is no such stream then it raises an exception.  This is a common
factor to all the stream outputting functions.
=end_chunk internal_chunk_text
=end rubyweb
    def chunk_text(achunk)
        if @chunks[achunk]
            text = ""
	    @chunks[achunk].each do
		|line|
		text += @lines[line]
	    end 
        else
            raise "There is no chunk \'#{achunk}\'\n"
        end
        return text
    end

=begin rubyweb
Method for listing all the streams.
=end rubyweb
    def list_the_streams
        print "streams:\n"
        @streams.each_key do
            |akey|
            print "   #{akey}\n"
            @streams[akey].each do
                |avalue|
                next unless avalue.type == String
                if avalue =~ /^\=use_stream\s+((\w+\s*)+)\s+/i
                    print "      uses stream #{$1}\n"
                end
                if avalue =~ /^\=use_chunk\s+((\w+\s*)+)\s+/i
                    print "      uses chunk #{$1}\n"
                end
	    end
        end
    end

=begin rubyweb
Method for listing all the chunks.
=end rubyweb
    def list_the_chunks
        print "chunks:\n"
        @chunks.each_key do
            |akey|
            print "   #{akey}\n"
            @chunks[akey].each do
                |avalue|
                next unless avalue.type == String
                if avalue =~ /^\=use_stream\s+((\w+\s*)+)\s+/i
                    print "      uses stream #{$1}\n"
                end
                if avalue =~ /^\=use_chunk\s+((\w+\s*)+)\s+/i
                    print "      uses chunk #{$1}\n"
                end
	    end
        end
    end

=begin rubyweb
A means is needed to display a stream or chunk on the standard output
=end rubyweb
    def display_stream(astream)
	print stream_text(astream)
    end

    def display_chunk(achunk)
	print chunk_text(achunk)
    end

=begin rubyweb
=begin_chunk output_explained
Some steams may be of no use unless saved separately.  This way
data files that connot contain comments may be held with comments
and the data extracted to the bare file when needed.
=end_chunk output_explained
=end rubyweb

    def output_stream(astream, file)
        print "output_stream called with \'#{astream}\', \'#{file}\'\n"  if $debugging
        # do this before opening the file so things are clean
        text = stream_text(astream)
        open(file, "w") do
            |f|
	    f.print text
            f.flush
        end
    end

    def output_chunk(achunk, file)
        print "output_chunk called with \'#{achunk}\', \'#{file}\'\n"  if $debugging
        # do this before opening the file so things are clean
        text = chunk_text(achunk)
        open(file, "w") do
            |f|
	    f.print text
            f.flush
        end
    end

=begin rubyweb
=begin_chunk pipe_explained
Some steams may make no snse at all unless fed into certain tools
The pipe functins provide this facility.
=end_chunk pipe_explained
=end rubyweb

    def pipe_stream(astream, command)
        print "pipe_stream called with \'#{astream}\', \'#{command}\'\n"  if $debugging
        pcommand = "|" + command
        print "pcommand is #{pcommand}\n"  if $debugging

        # do this before opening the pipe so things are clean
        text = stream_text(astream)

        open(pcommand, "w") do
            |p|
	    p.print text
            p.flush
        end
    end

    def pipe_chunk(achunk, command)
        print "pipe_chunk called with \'#{achunk}\', \'#{command}\'\n"  if $debugging
        pcommand = "|" + command
        print "pcommand is #{pcommand}\n"  if $debugging

        # do this before opening the pipe so things are clean
        text = chunk_text(achunk)

        open(pcommand, "w") do
            |p|
	    p.print text
            p.flush
        end
    end

=begin rubyweb
=begin_chunk internal_perform_output
All the output must be delayed until all the files have been read, and
all the chunks have neen expanded.  At that stage it is known what
the pieces are and which ones are to be displayed, etc.  Each of
these operations can be tackled in turn.
=end_chunk internal_perform_output
=end rubyweb

    def perform_output
        while @display_streams.length > 0
            this_stream = @display_streams.shift
            print "this_stream is #{this_stream}\n"  if $debugging
            display_stream(this_stream)
        end
        while @display_chunks.length > 0
            this_chunk = @display_chunks.shift
            print "this_chunk is #{this_chunk}\n"  if $debugging
            display_chunk(this_chunk)
        end
        while @output_streams.length > 0
            this_stream = @output_streams.shift
            this_file = @output_streams.shift
            output_stream(this_stream, this_file)
        end
        while @output_chunks.length > 0
            this_chunk = @output_chunks.shift
            this_file = @output_chunks.shift
            output_chunk(this_chunk, this_file)
        end
        while @pipe_streams.length > 0
            this_stream = @pipe_streams.shift
            this_command = @pipe_streams.shift
            pipe_stream(this_stream, this_command)
        end
        while @pipe_chunks.length > 0
            this_chunk = @pipe_chunks.shift
            this_command = @pipe_chunks.shift
            pipe_chunk(this_chunk, this_command)
        end
    end

end

=begin rubyweb
The main program begins here.
=end rubyweb
if __FILE__ == $0
    # $debugging = true
    $debugging = false

    # record in a global where we are in DATA at the start.
    $data_start = DATA.pos
    # Thanks to Guy Decoux for this.

    def usage
        DATA.pos = $data_start
        printing = false
        DATA.readlines.each do
            |line|
            if line =~ /^=begin_chunk usage/
                printing = true  
                next
            end
            if line =~ /^=end_chunk usage/
                printing = false  
                next
            end
            print line if printing
        end
    end
    
    web = Rubyweb.new()

=begin rubyweb
=begin_chunk internal_argument_processing
I found Getopt rather confusing.  I decided that since I was
to use ARGF for processing I would be explicit about editing
the ARGV to remove the arguments.  Instead of incrementing
a counter to go through ARGV I process each argument at the
zeroth element, and if it is an option then chop it and any
following values associated with out of ARGV, using the range
operators. The use of the range operators eases the shrinkage
of the array, because an empty array can be assigned.

If ARGV[0] is in fact a filename, then it cannot be sliced
out, because it must remain for ARGF. Thus I don't use 0, I
keep track of where I am with pos1.  pos2 holds the position
of the last thing I am deleting, including any values the
option takes.
=end_chunk internal_argument_processing
=end rubyweb
    # Go through ARGV, chopping out options as they are found.
    pos1 = 0
    pos2 = 0
    
    while not (pos1 == ARGV.length)
        print  if $debugging
        print "pos1 is #{pos1}\n"  if $debugging
        print "pos2 is #{pos2}\n"  if $debugging
        print "ARGV[pos1] is #{ARGV[pos1].inspect}\n"  if $debugging
        print  if $debugging
        if (ARGV[pos1] =~ /^-h(elp)|^--help/i)
            usage
            exit(0)
        end
        if (ARGV[pos1] =~ /^-v$|--version/i)
            print "Rubyweb $Revision: 1.11 $\n"
            exit(0)
        end
        if (ARGV[pos1] =~ /^-a$|--allow[_-]all/i)
            web.allow_display = true
            web.allow_output = true
            web.allow_pipe = true
            pos2 = pos1 + 1
	    ARGV[pos1...pos2]=[]
            next
        end
        if (ARGV[pos1] =~ /^-ad$|^--allow[_-]display/i)
            web.allow_display = true
            pos2 = pos1 + 1
	    ARGV[pos1...pos2]=[]
            next
        end
        if (ARGV[pos1] =~ /^-ao$|^--allow[_-]output/i)
            web.allow_output = true
            pos2 = pos1 + 1
	    ARGV[pos1...pos2]=[]
            next
        end
        if (ARGV[pos1] =~ /^-ap$|^--allow[_-]pipe/i)
            web.allow_pipe = true
            pos2 = pos1 + 1
	    ARGV[pos1...pos2]=[]
            next
        end
        if (ARGV[pos1] =~ /^-s$|--suppress[_-]all/i)
            web.allow_display = false
            web.allow_output = false
            web.allow_pipe = false
            pos2 = pos1 + 1
	    ARGV[pos1...pos2]=[]
            next
        end
        if (ARGV[pos1] =~ /^-sd$|^--suppress[_-]display/i)
            web.allow_display = false
            pos2 = pos1 + 1
	    ARGV[pos1...pos2]=[]
            next
        end
        if (ARGV[pos1] =~ /^-so$|^--suppress[_-]output/i)
            web.allow_output = false
            pos2 = pos1 + 1
	    ARGV[pos1...pos2]=[]
            next
        end
        if (ARGV[pos1] =~ /^-sp$|^--suppress[_-]pipe/i)
            web.allow_pipe = false
            pos2 = pos1 + 1
	    ARGV[pos1...pos2]=[]
            next
        end
        if (ARGV[pos1] =~ /^-ds|^--display[_-]stream/i)
            begin
		pos2 = pos1 + 1
		web.display_streams.push(ARGV[pos2])
		ARGV[pos1..pos2]=[]
            rescue
                print "-ds or --display_stream must be followed by a stream"
                raise
            end
            next
        end
        if (ARGV[pos1] =~ /^-dc|^--display[_-]chunk/i)
            begin
		pos2 = pos1 + 1
		web.display_chunks.push(ARGV[pos2])
		ARGV[pos1..pos2]=[]
            rescue
                print "-ds or --display_stream must be followed by a stream"
                raise
            end
            next
        end
        if (ARGV[pos1] =~ /^-os|^--output[_-]stream/i)
            begin
		pos2 = pos1 + 1
		web.output_streams.push(ARGV[pos2])
                pos2 += 1
		web.output_streams.push(ARGV[pos2])
		ARGV[pos1..pos2]=[]
            rescue
                print "-os or --output_stream must be followed by a stream name and a filename"
                raise
            end
            next
        end
        if (ARGV[pos1] =~ /^-oc|^--output[_-]chunk/i)
            begin
		pos2 = pos1 + 1
		web.output_chunks.push(ARGV[pos2])
                pos2 += 1
		web.output_chunks.push(ARGV[pos2])
		ARGV[pos1..pos2]=[]
            rescue
                print "-oc or --output_chunk must be followed by a chunk name and a filename"
                raise
            end
            next
        end
        if (ARGV[pos1] =~ /^-ps|^--pipe[_-]stream/i)
            begin
		pos2 = pos1 + 1
		web.pipe_streams.push(ARGV[pos2])
                pos2 += 1
		web.pipe_streams.push(ARGV[pos2])
		ARGV[pos1..pos2]=[]
            rescue
                print "-ps or --pipe_stream must be followed by a stream name and a command"
                raise
            end
            next
        end
        if (ARGV[pos1] =~ /^-pc|^--pipe[_-]chunk/i)
            begin
		pos2 = pos1 + 1
		web.pipe_chunks.push(ARGV[pos2])
                pos2 += 1
		web.pipe_chunks.push(ARGV[pos2])
		ARGV[pos1..pos2]=[]
            rescue
                print "-pc or --pipe_chunk must be followed by a chunk name and a command"
                raise
            end
            next
        end
        if (ARGV[pos1] =~ /^-l$|^--list[_-]all/i)
            web.list_streams = true
            web.list_chunks = true
            pos2 = pos1 + 1
	    ARGV[pos1...pos2]=[]
            next
        end
        if (ARGV[pos1] =~ /^-ls$|^--list[_-]streams/i)
            web.list_streams = true
            pos2 = pos1 + 1
	    ARGV[pos1...pos2]=[]
            next
        end
        if (ARGV[pos1] =~ /^-lc$|^--list[_-]chunks/i)
            web.list_chunks = true
            pos2 = pos1 + 1
	    ARGV[pos1...pos2]=[]
            next
        end
        pos1 += 1
    end


    ARGF.each() do
        |line|
        if ARGF.filename != web.included_files[0]
            web.included_files = [ARGF.filename]
        end
        web.process_line(line)
    end # end ARGF.each

    #p web  if $debugging

    print "\nread files\n"  if $debugging
    if web.list_streams 
	web.list_the_streams 
    end
    if web.list_chunks 
	web.list_the_chunks 
    end

    # bail out now if only listing.
    exit(0) if (web.list_streams || web.list_chunks)

    web.expand_references

    p web  if $debugging

    web.perform_output
    
end # end if __FILE__

=begin rubyweb
=begin_stream manual
=use_chunk introduction
=use_chunk rationale
=use_chunk terminology
=use_chunk features
=use_chunk structure
=use_chunk usage
=use_chunk authorship
=end_stream manual
=begin_stream internal_docs
=use_chunk introduction

=use_chunk authorship

=use_chunk terminology

=use_chunk design_notes

=use_chunk internal_argument_processing

=use_chunk internal_state

=use_chunk internal_rubyweb

=use_chunk internal_process_line

=use_chunk expanding_nested_refs

=use_chunk internal_stream_text

=use_chunk internal_chunk_text

=use_chunk internal_perform_output

Some things remain to be implemented:

=use_chunk not_implemented
=end_stream internal_docs
=end rubyweb

__END__

# Idea of reading duplicated information from DATA due to Dave Thomas.
# Thank you.

=begin rubyweb
=begin_chunk usage
Rubyweb $Revision: 1.11 $
usage: rubyweb.rb options filenames
options:
    -a
    --allow_all
                allow all output and piping
                from =output_*, =pipe_* and =display_*
                commands in the files.
    -ad
    --allow_display
                allow output from all =display_* commands
                in files.  Default is to allow this.
    -ao
    --allow_output
                allow output from all =output_* commands
                in files.  Default is to suppress this.
    -ap
    --allow_pipe
                allow output from all =pipe_* commands
                in files.  Default is to suppress this.
    -dc chunk
    --display_chunk chunk
		print chunk on standard output
    -ds stream
    --display_stream stream
		print stream on standard output
    
    -h
    --help
		display this message
    -l
    -list_all
		list all chunks and streams
    -lc
    -list_chunks
		list all chunks
    -ls
    -list_streams
		list all streams
    -oc chunk filename
    --output_chunk chunk filename
		output chunk to filename

    -os stream filename
    --output_stream stream filename
		output stream to filename
    
    -pc chunk command
    --pipe_chunk chunk command
		pipe chunk to command

    -ps stream command
    --pipe_stream stream command
		pipe stream to command

    -s
    --suppress_all
                suppress all output and piping
                from =output_*, =pipe_* and =display_*
                commands in the files.
    -sd
    --suppress_display
                suppress output from all =display_* commands
                in files.  Default is to allow this.
    -so
    --suppress_output
                suppress output from all =output_* commands
                in files.  Default is to suppress this.
    -sp
    --suppress_pipe
                suppress output from all =pipe_* commands
                in files.  Default is to suppress this.
    -v
    --version
		Show version number and exit.
=end_chunk usage
=end rubyweb
