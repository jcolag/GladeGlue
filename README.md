GladeGlue
=========

GladeGlue is a code generator to simplify use of GTK+ Glade layouts.

Usage
-----

You have a GTK+ window layout in Glade named `xyz.glade`?  Copy it into your program directory and run:

    ruby GladeGlue.rb xyz

Notice that there is no extension.  Also maybe note that the program doesn't really care about folder structure.

GladeGlue will create glue code to simplify using your window.  Call `load_xyz_from_file()` in your main program, and use variables named after your widgets immediately.  The widget variables will be named as *`xyz`*_*`control_name`*.

Background
----------

Working with GTK+ on a couple of small projects, it reminds me of Windows programming prior to the `.rc` file.  Creating window widgets/controls programmatically wasn't very entertaining in the '80s, and it's borderline-unacceptable today.

[Glade](https://glade.gnome.org/) improves the situation, by allowing a quick visual layout of the widgets/controls, but the programmer still (for whatever reason) needs to root around the layout structure and define and populate the variables manually.

Contrast this with even early versions of Visual Studio (or any reasonable IDE), which compiled the resources to something directly usable by the programmer.

GladeGlue is an attempt to rectify this, at least for me.  If it works for anybody else, that's great.

The program is nothing special, nothing magic.  I just wanted something to reduce clutter and save me the trouble of going back to catch every single widget.  GladeGlue reads through a Glade XML file to discover what widgets are available.  It then outputs a C file (plus header) that defines one variable of the appropriate type for each widget, plus a function to populate them from the Glade file.

The names are very straightforward, possibly dangerously so, so beware:

 - It assumes that the file will be named _`filename`_`.glade`.  It __does not__ take the extension.
 - It generates _`filename`_`_glade.c` and _`filename`_`_glade.h`.
 - For each widget, an `extern` variable is defined, named *`filename`*_*`id`, on the chance that you have multiple windows with similarly-named widgets.
 - The function is named `load_`_`filename`_`_from_file()`, taking no parameters and returning nothing.

Right now, the program also detects required signal handlers and flags them if they can't be found in any `.c` file in the current directory.  It's tempting to suggest that the program should continue on to create a file with stub event handlers in that case, but maybe a future revision.

Caveats
-------

I assume that this isn't a good idea for every project.  It might not even be a good idea for many projects.  So far, though, it simplifies my projects.

Instructions
------------

Run GladeGlue.  Include the header file.  Call the `load_`whatever`_from_file()` function.  Use the variables directly.

