require "gtk3"
require "gio2"
require "filemagic"
require "fileutils"
require "./rfilemanager-tab"

class FileActions

  ICONSIZE_32, ICONSIZE_48, ICONSIZE_64, ICONSIZE_80 = [32, 48, 64, 80]
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
      new_file_path = iter[0].chomp(iter[1]) + rename + "/"
    else
      new_file_path = iter[0].chomp(iter[1]) + rename
    end
    File.rename(iter[0], new_file_path)
    iter[0] = new_file_path
    iter[1] = rename
    rename_update(tab, path, new_file_path, rename)
  end
 
  def rename_update(tab, path, new_file_path, rename)
    i = 0
    while i < tab.n_pages
      if tab.get_nth_page(i).child.parent == tab.get_nth_page(tab.page).child.parent
        iter = tab.get_nth_page(i).child.file_store.get_iter(path)
        iter[0] = new_file_path
        iter[1] = rename
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
    icon_theme = Gtk::IconTheme.default
    icon = icon_theme.load_icon(iter[4], ICONSIZE_48, Gtk::IconTheme::LookupFlags::FORCE_SVG)
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
        dialog.destroy
      else
        dialog.destroy
      end
    end
  end
  
  def get_icon(is_dir, path)
    if is_dir
      icon_name = "gnome-fs-directory"
    else
        mime = FileMagic.mime
        mimetype = mime.file(path)
        part1 = mimetype.split(";")
        part2 = part1[0].split("/")
        # inappropriate file format
        if not mimetype.include?(";")
          icon_name = mimetype.split(" ")
          part2[1] = icon_name[0]
        end
        icon_name = @icon_list.grep(/#{part2[1]}/)
        if icon_name.class == Array
          icon_name = icon_name[0]
        end
        if icon_name == nil
          icon_name = "gnome-fs-regular"
        end
      end
    icon = @icon_theme.load_icon(icon_name, ICONSIZE_48, Gtk::IconTheme::LookupFlags::FORCE_SVG)
    return icon, icon_name
  end

  def get_icon_list
    @icon_theme = Gtk::IconTheme.default
    @icon_list = @icon_theme.icons
  end

  def increase_pixbuf?(tab, zoomin_item, zoomout_item)
    if tab.get_nth_page(tab.page).child.file_store.iter_first[3].width == ICONSIZE_80
      zoomin_item.sensitive = false
    end
    if tab.get_nth_page(tab.page).child.file_store.iter_first[3].width == ICONSIZE_32
      zoomout_item.sensitive = false
    end 
  end

  def decrease_pixbuf_size(tab)
    icon_theme = Gtk::IconTheme.default
    size = tab.get_nth_page(tab.page).child.file_store.iter_first[3].width - 16
    tab.get_nth_page(tab.page).child.file_store.each do |model, path, iter|
    iter[3] = icon_theme.load_icon(iter[4], size, Gtk::IconTheme::LookupFlags::FORCE_SVG)
    end
  end
  
  def increase_pixbuf_size(tab)
    icon_theme = Gtk::IconTheme.default
    size = tab.get_nth_page(tab.page).child.file_store.iter_first[3].width + 16
    tab.get_nth_page(tab.page).child.file_store.each do |model, path, iter|
      # iter[3] -> pixbuf_column
      # iter[4] -> icon name
      iter[3] = icon_theme.load_icon(iter[4], size, Gtk::IconTheme::LookupFlags::FORCE_SVG)
    end
  end

  def tab_rightclick_menu(event, tab, window)
    menu = Gtk::Menu.new
    menu.append(paste_item = Gtk::ImageMenuItem.new(:stock_id => Gtk::Stock::PASTE))
    menu.append(properties_item = Gtk::ImageMenuItem.new(:stock_id => Gtk::Stock::PROPERTIES))
    menu.append(zoomin_item = Gtk::ImageMenuItem.new(:stock_id => Gtk::Stock::ZOOM_IN))
    menu.append(zoomout_item = Gtk::ImageMenuItem.new(:stock_id => Gtk::Stock::ZOOM_OUT))
    # menu.append(delete_item = Gtk::ImageMenuItem.new(:stock_id => Gtk::Stock::DELETE))
    increase_pixbuf?(tab, zoomin_item, zoomout_item)
    menu.show_all
    menu.popup(nil, nil, event.button, event.time)
    zoomin_item.signal_connect("activate"){increase_pixbuf_size(tab); window.show_all}
    zoomout_item.signal_connect("activate"){decrease_pixbuf_size(tab); window.show_all}
    # delete_item.signal_connect("activate"){delete_file(tab); window.show_all;}
  end

  def rightclick_menu(event, path, tab, window)
    menu = Gtk::Menu.new 
    menu.append(rename_item = Gtk::ImageMenuItem.new(:label => "Rename"))
    menu.append(copy_item = Gtk::ImageMenuItem.new(:stock_id => Gtk::Stock::COPY))
    menu.append(paste_item = Gtk::ImageMenuItem.new(:stock_id => Gtk::Stock::PASTE))
    menu.append(cut_item = Gtk::ImageMenuItem.new(:stock_id => Gtk::Stock::CUT))
    menu.append(delete_item = Gtk::ImageMenuItem.new(:stock_id => Gtk::Stock::DELETE))
    if tab.get_nth_page(tab.page).child.selected_items.length > 1
      rename_item.sensitive = false
    end
    menu.show_all
    menu.popup(nil, nil, event.button, event.time)
    # signals
    rename_item.signal_connect("activate"){rename_window(path, tab)}
    copy_item.signal_connect("activate"){copy_file(tab)}
    paste_item.signal_connect("activate"){paste_file(tab)}
    cut_item.signal_connect("activate"){}
    delete_item.signal_connect("activate"){delete_file(tab); window.show_all}
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

  def remove_update(tab, path)
    i = 0
    while i < tab.n_pages
      if tab.get_nth_page(i).child.parent == tab.get_nth_page(tab.page).child.parent
        iter = tab.get_nth_page(i).child.file_store.get_iter(path)
        tab.get_nth_page(i).child.file_store.remove(iter)
      end
      i += 1
    end
  end

  def delete_file(tab)
    # get selected items
    items = tab.get_nth_page(tab.page).child.selected_items
    while items.length != 0
     iter = tab.get_nth_page(tab.page).child.file_store.get_iter(items[0]) 
     # delete file or dir
     if FileTest.directory?(iter[0])
       FileUtils.rm_rf(iter[0])
     else
       FileUtils.rm(iter[0]) 
     end
     remove_update(tab, items[0])
     # update selected item path list
     items = tab.get_nth_page(tab.page).child.selected_items
    end
  end
end
