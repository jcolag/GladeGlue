require 'rexml/document'
require 'find'

include REXML

# Recursively search the Glade file for objects
# Pull out the class and id
def scanChildren(widgets, signals, obj, path)
    obj.elements.each(path) do |el|
        next if el.attributes["class"] == "GtkAdjustment"
puts el.attributes["class"]
        widgets[el.attributes["id"]] = el.attributes["class"]
        scanChildren(widgets, signals, el, "child/object")
        el.elements.each("signal") do |sig|
            signals[sig.attributes["handler"]] = el.attributes["class"]
        end
    end
end

# We need a file name
if ARGV.length < 1
    puts <<USAGE
Usage:
    ruby #{__FILE__} <file.glade>
USAGE
    exit
end
basename = ARGV[0]

# Open/parse the file and initialize
gladefile = File.new(basename + ".glade")
gladexml = Document.new gladefile
elements = Hash.new
signals = Hash.new
loadname = "load_" + basename + "_from_file"
comment = <<END_COMMENT
/* DO NOT EDIT.  This is automatically generated glue code from
 * GladeGlue.
 */

END_COMMENT
scanChildren(elements, signals, gladexml, "interface/object")
missing_handlers = Array.new
MatchLine = Struct.new(:path, :line)
signals.each do |hand,klass|
    vname = klass.downcase.sub(/gtk/, '')
    signature = "void #{hand} (#{klass} *#{vname}, gpointer user_data);"

    matches = Array.new
    Find.find(".") do |path|
        next if File::directory?(path) or !path.end_with?(".c")
        IO.readlines(path).grep(/#{Regexp.escape(hand)}/) do |line|
            matches << MatchLine.new(path, line.strip)
        end
    end
    if matches.length == 0
        missing_handlers << signature
    end
end

if missing_handlers.length > 0
    puts "Be sure the following event handlers exist:"
    missing_handlers.each do |mh|
        puts "    #{mh}"
    end
end

# Generate the header, with external definitions and the prototype
File.open("#{basename}_glade.h", 'w') do |header|
    header.puts comment
    elements.each do |k,v|
        header.puts "extern #{v} * #{basename}_#{k};"
    end
    header.puts "\nvoid #{loadname} (void);"
end

# Generate the C glue file to define and load the external variables
File.open("#{basename}_glade.c", 'w') do |source|
    source.puts comment
    source.puts <<C_HEAD
#include <gtk/gtk.h>
#include \"#{basename}_glade.h\"

C_HEAD
    elements.each do |k,v|
        source.puts "#{v} *#{basename}_#{k};"
    end
    source.puts <<C_BUILD

void #{loadname} (void) {
  GtkBuilder *builder = gtk_builder_new ();
  gtk_builder_add_from_file (builder, \"#{basename}.glade\", NULL);
  gtk_builder_connect_signals (builder, NULL);      
C_BUILD
    elements.each do |k,v|
        source.puts "  #{basename}_#{k} = (#{v} *)GTK_WIDGET(gtk_builder_get_object(builder, \"#{k}\"));"
    end
    source.puts <<C_FOOT
  g_object_unref (G_OBJECT (builder));
}

C_FOOT
end

