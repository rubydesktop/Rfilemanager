require "gtk3"
require "gio2"

class FileActions

  # opens file with default application
  def open_default_application(file)
    system "xdg-open #{file}"
  end
 
  def get_volumes
    hash = {"File System" => "/"}
    all_volumes = Gio::VolumeMonitor.get.volumes
    # mount volumes
    all_volumes.each do |volume|
      v = volume.mount
      hash.store(v.name, v.get_mount.default_location.path) 
    end
    return hash
  end

  # file name changes & display name changes
  def change_file_name(path, tab, entry)
    iter = tab.get_nth_page(tab.page).child.file_store.get_iter(path)
    new_file_path = iter[0].chomp(iter[1]) + entry.text
    File.rename(iter[0], new_file_path)
    iter[0] = new_file_path
    iter[1] = entry.text
  end

  # if occurs any change in any tab, updates other tabs
#  def update_tabs(tab)
#    i = 0
#    while i < tab.n_pages
#      if tab.get_nth_page(i).child.parent == tab.get_nth_page(tab.page)
#        if i != tab.page
#          fill_store2(tab.get_nth_page(i).child.parent, tab.get_nth_page(i).file_store)
#        end
#    end

  end

  def rename_window(path, tab)
    w = Gtk::Window.new
    w.set_title("Rename")
    w.set_default_size(300, 140)
    cancel = Gtk::Button.new(:label => "Cancel")
    cancel.set_size_request(80, 30)
 
    ok = Gtk::Button.new(:label => "OK")
    ok.set_size_request(80, 30)   

    entry = Gtk::Entry.new
    fixed = Gtk::Fixed.new
    fixed.put(entry, 70, 40)
    fixed.put(cancel, 100, 100)
    fixed.put(ok, 200, 100)
 
    ok.signal_connect("clicked"){change_file_name(path, tab, entry); w.destroy;}
    cancel.signal_connect("clicked"){w.destroy}

    w.add(fixed)
    w.show_all
  end

  def rightclik_menu(event, path, tab)
    menu = Gtk::Menu.new
    menu.append(rename_item = Gtk::MenuItem.new("Rename"))
    menu.show_all
    menu.popup(nil, nil, event.button, event.time)
    # signals
    rename_item.signal_connect("activate"){rename_window(path, tab)}
  end

end
