require "gtk3"
require "gio2"
require "filemagic"
require "fileutils"
require "./rfilemanager-tab"

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
      hash.store(v.name, volume) 
    end
    return hash
  end

  # file name changes & display name changes
  def change_file_name(path, tab, rename)
    iter = tab.get_nth_page(tab.page).child.file_store.get_iter(path)
    if FileTest.directory?(iter[0])
      iter[1] += "/"
    end
    new_file_path = iter[0].chomp(iter[1]) + rename
    File.rename(iter[0], new_file_path)
    iter[0] = new_file_path + "/"
    iter[1] = rename
  end

  # if occurs any change in any tab, updates other tabs
  def update_tabs(tab)
    i = 0
    tab_obj = AddRemoveTab.new
    while i < tab.n_pages
      if tab.get_nth_page(i).child.parent == tab.get_nth_page(tab.page).child.parent
        if i != tab.page
          tab_obj.filestore_update(tab.get_nth_page(i).child.parent, tab.get_nth_page(i).child.file_store, "recursive")
        end
      end
    i += 1
    end
  end

  def create_error_msg_win(msg)
     error_msg_win = Gtk::MessageDialog.new(:parent => nil, :flags => :modal,
               :type => :error, :buttons_type => :close, :message => msg)
     return error_msg_win
  end

  def create_dialog_win(title)
    dialog = Gtk::Dialog.new(:title => title, :parent => nil,
                             :flags => :modal, :buttons => [[Gtk::Stock::OK, :ok],
                             [Gtk::Stock::CANCEL, :cancel]])
    dialog.default_response = Gtk::ResponseType::OK
    return dialog
  end

  def rename_window(path, tab)
    is_dir = FileTest.directory?(path)
    iter = tab.get_nth_page(tab.page).child.file_store.get_iter(path)
    icon_list = get_icon_list
    icon = get_icon(is_dir, iter[0]) 
    dialog = create_dialog_win("Rename")
    table = Gtk::Table.new(4, 2, false)
    rename_entry = Gtk::Entry.new
    rename_entry.text = File.basename(iter[0])
    rename_entry.select_region(0, -1)
    table.attach_defaults(rename_entry, 1, 2, 0, 1)
    image = Gtk::Image.new
    image.pixbuf = icon
    table.attach_defaults(image, 0, 1, 0, 1)
    table.row_spacings = 5
    table.column_spacings = 5
    table.border_width = 10
    dialog.child.add(table)
    dialog.show_all
    rename_entry.signal_connect("key-press-event") do |_, e|
      # if pressed to enter button
      if e.keyval == 65293 
        dialog.response(Gtk::ResponseType::OK)
      end
    end
    dialog.run do |response|
      if response == Gtk::ResponseType::OK
        if rename_entry.text == ""
          error_msg_win = create_error_msg_win("Failed to rename #{iter[0]}")
          error_msg_win.run
          error_msg_win.destroy
          dialog.destroy
          return
        end
        change_file_name(path, tab, rename_entry.text)
        update_tabs(tab)
        dialog.destroy
      else
        dialog.destroy
      end
    end
  end
  
  def get_icon(is_dir, path)
    if is_dir
      icon = "gnome-fs-directory"
    else
        mime = FileMagic.mime
        mimetype = mime.file(path)
        part1 = mimetype.split(";")
        part2 = part1[0].split("/")
        # inappropriate file format
        if not mimetype.include?(";")
          icon = mimetype.split(" ")
          part2[1] = icon[0]
        end
        icon = @icon_list.grep(/#{part2[1]}/)
        if icon.class == Array
          icon = icon[0]
        end
        if icon == nil
          icon = "gnome-fs-regular"
        end
      end
    icon = @icon_theme.load_icon(icon, 48, Gtk::IconTheme::LookupFlags::FORCE_SVG)
    return icon
  end

  def get_icon_list
    @icon_theme = Gtk::IconTheme.default
    @icon_list = @icon_theme.icons
  end

  def tab_rightclick_menu(event, tab)
    menu = Gtk::Menu.new
    menu.append(paste_item = Gtk::MenuItem.new("Paste"))
    menu.append(properties_item = Gtk::MenuItem.new("Properties"))
    menu.append(zoomin_item = Gtk::MenuItem.new("Zoom In"))
    menu.append(zoomout_item = Gtk::MenuItem.new("Zoom Out"))
    menu.show_all
    menu.popup(nil, nil, event.button, event.time)
  end

  def rightclick_menu(event, path, tab)
    menu = Gtk::Menu.new
    rename_item = Gtk::ImageMenuItem.new(:label => "Rename")
    copy_item = Gtk::ImageMenuItem.new(:stock_id => Gtk::Stock::COPY)
    paste_item = Gtk::ImageMenuItem.new(:stock_id => Gtk::Stock::PASTE)
    cut_item = Gtk::ImageMenuItem.new(:stock_id => Gtk::Stock::CUT)
    delete_item = Gtk::ImageMenuItem.new(:stock_id => Gtk::Stock::DELETE)
    menu.append(rename_item)
    menu.append(copy_item)
    menu.append(paste_item)
    menu.append(cut_item)
    menu.append(delete_item)
    if tab.get_nth_page(tab.page).child.selected_items.length > 1
      rename_item.sensitive = false
    end
    menu.show_all
    menu.popup(nil, nil, event.button, event.time)
    # signals
    rename_item.signal_connect("activate"){rename_window(path, tab)}
    copy_item.signal_connect("activate"){}
  end

  def copy_file(tab)
    @copy_file_list = Array.new
    # get selected file path
    tab.get_nth_page(tab.page).child.selected_each do |iconview, path| 
      iter = tab.get_nth_page(tab.page).child.file_store.get_iter(path)
      @copy_file_list.push(iter[0])
    end
  end

  def paste_file(tab, main_window)
    tab_obj = AddRemoveTab.new
    dest = tab.get_nth_page(tab.page).child.parent
    @copy_file_list.each do |src| 
      FileUtils.cp_r(src, dest)
      tab_obj.filestore_update("#{dest}#{File.basename(src)}", tab.get_nth_page(tab.page).child.file_store, nil)
    main_window.show_all
    end
  end
end
