#!/usr/bin/ruby
# Encoding: utf-8
require 'rexml/document'
require 'find'

include REXML

# Utility class to extract useful data from the Glade description.
class Scanner
  @widgets = nil
  @signals = nil
  @object = nil

  attr_reader :widgets, :signals

  def initialize(obj)
    @object = obj
    @widgets = {}
    @signals = {}
  end

  # Recursively search the Glade file for objects
  # Pull out the class and id
  def children(path)
    @object.elements.each(path) do |el|
      elattr = el.attributes
      elclass = elattr['class']
      next if elclass == 'GtkAdjustment'
      process(el, elattr, elclass)
    end
  end

  # Dig deeper into the structure
  def process(element, elattr, elclass)
    @widgets[elattr['id']] = elclass
    children('child/object')
    element.elements.each('signal') do |sig|
      signals[sig.attributes['handler']] = elclass
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
loadname = 'load_' + basename + '_from_file'
comment = <<END_COMMENT
/* DO NOT EDIT.  This is automatically generated glue code from
 * GladeGlue.
 */

END_COMMENT
scan = Scanner.new(gladexml)
scan.children('interface/object')
missing_handlers = []

# Structure to hold matched portions/locations
MatchLine = Struct.new(:path, :line)
scan.signals.each do |hand, klass|
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
  scan.widgets.each do |k, v|
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
  scan.widgets.each do |k, v|
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
  scan.widgets.each do |k, v|
    source.puts "  #{basename}_#{k} = (#{v} *)#{buildcmd}, \"#{k}\"));"
  end
  source.puts <<C_FOOT
  if (unref) {
  g_object_unref (G_OBJECT (builder));
  }
}

C_FOOT
end
