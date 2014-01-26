require "gtk3"

class RFileManagerIconView < Gtk::IconView

  attr_accessor :parent
  attr_accessor :curr_dir
  attr_accessor :route
  attr_accessor :file_store
  def initialize
    super
    @parent = ""
    @curr_dir = ""
    @route = Array.new
    @file_store = Gtk::ListStore.new(String, String, TrueClass, Gdk::Pixbuf)
  end

end

