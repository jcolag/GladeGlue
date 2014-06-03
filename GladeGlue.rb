#!/usr/bin/ruby
# Encoding: utf-8
require 'rexml/document'
require 'find'

include REXML

# Recursively search the Glade file for objects
# Pull out the class and id
def scan_children(widgets, signals, obj, path)
  obj.elements.each(path) do |el|
    next if el.attributes['class'] == 'GtkAdjustment'
    widgets[el.attributes['id']] = el.attributes['class']
    scan_children(widgets, signals, el, 'child/object')
    el.elements.each('signal') do |sig|
      signals[sig.attributes['handler']] = el.attributes['class']
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
gladefile = File.new(basename + '.glade')
gladexml = Document.new gladefile
elements = {}
signals = {}
loadname = 'load_' + basename + '_from_file'
comment = <<END_COMMENT
/* DO NOT EDIT.  This is automatically generated glue code from
 * GladeGlue.
 */

END_COMMENT
scan_children(elements, signals, gladexml, 'interface/object')
missing_handlers = []
MatchLine = Struct.new(:path, :line)
signals.each do |hand, klass|
  vname = klass.downcase.sub(/gtk/, '')
  signature = "void #{hand} (#{klass} *#{vname}, gpointer user_data);"

  matches = Array.new
  Find.find('.') do |path|
    next if File.directory?(path) || !path.end_with?('.c')
    IO.readlines(path).grep(/#{Regexp.escape(hand)}/) do |line|
      matches << MatchLine.new(path, line.strip)
    end
  end
  missing_handlers << signature if matches.length == 0
end

if missing_handlers.length > 0
  puts 'Be sure the following event handlers exist:'
  missing_handlers.each do |mh|
    puts "  #{mh}"
  end
end

# Generate the header, with external definitions and the prototype
File.open("#{basename}_glade.h", 'w') do |header|
  header.puts comment
  elements.each do |k, v|
    header.puts "extern #{v} * #{basename}_#{k};"
  end
  header.puts "\nvoid #{loadname} (char *, int);"
end

# Generate the C glue file to define and load the external variables
File.open("#{basename}_glade.c", 'w') do |source|
  source.puts comment
  source.puts <<C_HEAD
#include <string.h>
#include <gtk/gtk.h>
#include \"#{basename}_glade.h\"

C_HEAD
  elements.each do |k, v|
    source.puts "#{v} *#{basename}_#{k};"
  end
  source.puts <<C_BUILD

void #{loadname} (char *path, int unref) {
  char filename[256];
  GtkBuilder *builder;

  strcpy(filename, path);
  strcat(filename, \"#{basename}.glade\");
  builder = gtk_builder_new ();
  gtk_builder_add_from_file (builder, filename, NULL);
  gtk_builder_connect_signals (builder, NULL);
C_BUILD
  buildcmd = 'GTK_WIDGET(gtk_builder_get_object(builder'
  elements.each do |k, v|
    source.puts "  #{basename}_#{k} = (#{v} *)#{buildcmd}, \"#{k}\"));"
  end
  source.puts <<C_FOOT
  if (unref) {
  g_object_unref (G_OBJECT (builder));
  }
}

C_FOOT
end
