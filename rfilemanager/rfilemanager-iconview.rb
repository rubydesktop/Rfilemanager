require "gtk3"

class RFileManagerIconView < Gtk::IconView
 
#  type_register
  attr_accessor :parent
  attr_accessor :curr_dir
  attr_accessor :route
  attr_accessor :file_store
  attr_accessor :label

  def initialize
    super
    @parent = ""
    @curr_dir = ""
    @route = Array.new
    @label = ""
    @file_store = Gtk::ListStore.new(String, String, TrueClass, Gdk::Pixbuf)
  end

#  signal_new("curr-dir-updated")
end

