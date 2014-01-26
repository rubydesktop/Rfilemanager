require 'gtk3'
require 'filemagic'
require './rfilemanager-file-actions'
require "./rfilemanager-tab"

class FileManager
  INDEX = 0
  COL_PATH, COL_DISPLAY_NAME, COL_IS_DIR, COL_PIXBUF = (0..3).to_a
   
  def initialize
    @parent = "#{ENV['HOME']}"
    @curr_dir = @parent
    @route = Array.new
    @file_path_entry = Gtk::Entry.new
    @file_path_entry.editable = false
    @icon_theme = Gtk::IconTheme.default
    @icon_list = @icon_theme.icons
    @mime = FileMagic.mime
    @file_actions_obj = FileActions.new
    @tab_obj = AddRemoveTab.new
    @tab_obj.create_variable()
    set_adress_line()
    @color=Gdk::RGBA::new(18,89,199,0.2)
    @win = Gtk::Window.new
    swin_vpaned = Gtk::Paned.new(:horizontal)
    main_vbox = Gtk::Box.new(:vertical, 2)
    toolbar_hbox = Gtk::Box.new(:horizontal, 0)
    menus = create_menubar    
    create_toolbar
    toolbar_hbox.pack_start(@toolbar, :expand => false, :fill => true, :padding =>0)
    toolbar_hbox.pack_start(@file_path_entry, :expand => true, :fill => true, :padding => 0)
    
    main_vbox.pack_start(menus, :expand => false, :fill => false, :padding => 2)
    main_vbox.pack_start(toolbar_hbox, :expand => false, :fill => true, :padding => 2)
    main_vbox.pack_start(swin_vpaned, :expand => true, :fill => true, :padding => 1)
    treeview_vbox = Gtk::Box.new(:vertical, 1)
    create_devices_treeview()
    treeview_vbox.pack_start(@devices_treeview, :expand => false, :fill => false, :padding => 2)
    create_places_treeview
    
    main_vbox.homogeneous=false
    toolbar_hbox.homogeneous=false
    treeview_vbox.pack_start(@places_treeview)
    @tab_obj.set_buttons(@back_toolbut, @next_toolbut)
    @tab = Gtk::Notebook.new
    @tab.scrollable = true
    @tab_obj.new_tab(@tab, @parent)
    swin_vpaned.pack1(treeview_vbox, :resize => true, :shrink => false)
    swin_vpaned.pack2(@tab, :resize => true, :shrink => false)

    # win settings
    @win.set_size_request(700, 400)
    @win.set_title("RFileManager")
    @win.signal_connect("destroy"){Gtk.main_quit}
    @win.set_window_position(Gtk::Window::Position::CENTER)
    @win.add(main_vbox)
    @win.show_all
  end

  def set_adress_line
    @file_path_entry.text = @parent
  end

# add devices (under /media/username/) to @device_hash
def media_dir
  @devices_hash = {"File System" => "/"} 
  list = Array.new
  # list of directories under /media/user
  list += Dir.entries("/media/#{ENV["USER"]}").select {|entry|
          File.directory? File.join("/media/#{ENV["USER"]}", entry) and
               !(entry =='.' || entry == '..') }
  list.each do |directory|
   fullpath = File.join("/media/#{ENV["USER"]}", directory)
   size = size_dir(fullpath)
   @devices_hash[size] = fullpath
 end
end

def size_dir(fullpath)
  pn = Pathname.new(fullpath)
  size = pn.size 
  # convert to gb
  if size >= 1000 ** 3
    size = size / (1000.0 ** 3)
    size_type = "GB"
  # convert to mb
  elsif size >= 1000.0 ** 2
    sizes = size / (1000.0 ** 2)
    size_type = "MB"
  # convert to kb
  elsif size >= 1000
    size = size / 1000.0
    size_type = "KB"
  end
  return "#{size} #{size_type} VOLUME"
end

def create_places_treeview 
  @places_treeview = Gtk::TreeView.new
  renderer = Gtk::CellRendererText.new
  column   = Gtk::TreeViewColumn.new("PLACES", renderer,  :text => INDEX)
  @places_treeview.append_column(column)
  store = Gtk::TreeStore.new(String)
  @places_hash = {"#{ENV["USER"]}" => "#{ENV["HOME"]}", "Desktop" => "#{ENV["HOME"]}/Desktop"}
    @places_treeview.model = store
  selection = @places_treeview.selection;
  @places_hash.each_key do |key|
    iter = store.append(nil)
    if key == "#{ENV["USER"]}"
      selection.select_iter(iter)
    end
    iter[INDEX] = key
  end
  @places_treeview.override_background_color(0, @color)
  @places_treeview.signal_connect("cursor-changed"){
                   click_treeview_row(@places_treeview, @places_hash,
                                      @devices_treeview)}
end

def create_devices_treeview
  @devices_treeview = Gtk::TreeView.new
  renderer = Gtk::CellRendererText.new
  column   = Gtk::TreeViewColumn.new("DEVICES", renderer, :text => INDEX)
  @devices_treeview.append_column(column)
  store = Gtk::TreeStore.new(String)
  media_dir()
  @devices_hash.each_key do |key|
    iter = store.append(nil)
    iter[INDEX] = key
  end
  @devices_treeview.model = store
  @devices_treeview.override_background_color(0, @color)
  @devices_treeview.signal_connect("cursor-changed"){
                    click_treeview_row(@devices_treeview, @devices_hash,
                                       @places_treeview)}
end

def click_treeview_row(clicked_treeview, hash, unselect_treeview)
  selection = clicked_treeview.selection;
  iter = selection.selected
  @tab.get_nth_page(@tab.page).child.parent = hash[iter[0]]
  @tab_obj.fill_store("new_path", nil, @tab, @tab.get_nth_page(@tab.page).child.file_store)
  s = unselect_treeview.selection
  s.unselect_all
end
 
def create_toolbar
  @toolbar = Gtk::Toolbar.new 
  @toolbar.set_size_request(30,30)
  # tool buttons
  @back_toolbut = Gtk::ToolButton.new(:stock_id => Gtk::Stock::GO_BACK)
  @next_toolbut = Gtk::ToolButton.new(:stock_id => Gtk::Stock::GO_FORWARD)
  home_toolbut = Gtk::ToolButton.new(:stock_id => Gtk::Stock::HOME)
  up_toolbut = Gtk::ToolButton.new(:stock_id => Gtk::Stock::GO_UP)
  @back_toolbut.sensitive = false
  @next_toolbut.sensitive = false
  @back_toolbut.signal_connect("clicked"){@tab_obj.fill_store("back", @tab.get_nth_page(@tab.page).child.parent,
                                         @tab, @tab.get_nth_page(@tab.page).child.file_store)}
  @next_toolbut.signal_connect("clicked"){@tab_obj.fill_store("next", @tab.get_nth_page(@tab.page).child.parent,
                                          @tab, @tab.get_nth_page(@tab.page).child.file_store)}
#  @home_toolbut.signal_connect('clicked'){fill_store()}
  @toolbar.insert(@back_toolbut, 0)
  @toolbar.insert(@next_toolbut, 1)
  @toolbar.insert(up_toolbut, 2)
  @toolbar.insert(home_toolbut, 3)
end

def create_menubar
  menubar = Gtk::MenuBar.new
  # menus
  filemenu = Gtk::Menu.new
  viewmenu = Gtk::Menu.new
  helpmenu = Gtk::Menu.new
    
  # file items
  filem = Gtk::MenuItem.new("File")
  newtab_item = Gtk::MenuItem.new("New Tab") 
  newwindow_item = Gtk::MenuItem.new("New Window")
  closetab_item = Gtk::MenuItem.new("Close Tab")
  closewindow_item = Gtk::MenuItem.new("Close Window")
  properties_item = Gtk::MenuItem.new("Properties")
  filem.set_submenu(filemenu)
  filemenu.append(newtab_item)
  filemenu.append(newwindow_item)
  filemenu.append(closetab_item)
  filemenu.append(closewindow_item)
  filemenu.append(properties_item)
  # view items
  viewm = Gtk::MenuItem.new("View")
  reload_item = Gtk::MenuItem.new("Reload")
  viewm.set_submenu(viewmenu)
  viewmenu.append(reload_item)
    
  # help items
  helpm = Gtk::MenuItem.new("Help")
  projectwebsite_item = Gtk::MenuItem.new("Project Web Site")
  about_item = Gtk::MenuItem.new("About")
  helpm.set_submenu(helpmenu)
  helpmenu.append(projectwebsite_item)
  helpmenu.append(about_item)
 
  menubar.append(filem)
  menubar.append(viewm)
  menubar.append(helpm)
  newtab_item.signal_connect("activate"){parent = @tab.get_nth_page(@tab.page).child.parent;@tab_obj.new_tab(@tab, parent); @win.show_all}
  # newwindow_item.signal_connect("activate"){}
  return menubar
end
 
app = FileManager.new
Gtk.main
 
end
