require "gtk3"
require "filemagic"
require "./rfilemanager-iconview"
require "./rfilemanager-file-actions"

class AddRemoveTab

  COL_PATH, COL_DISPLAY_NAME, COL_IS_DIR, COL_PIXBUF, COL_ICONAME = (0..4).to_a

  def create_tab_container(parent)
    swin =  Gtk::ScrolledWindow.new
    viewport  = Gtk::Viewport.new(swin.hadjustment, swin.vadjustment)
    hbox = Gtk::Box.new(:horizontal)
    close_but = Gtk::Button.new
    image = Gtk::Image.new
    image.set_from_stock(Gtk::Stock::CLOSE, :menu)
    close_but.set_image(image)
    close_but.set_relief(:none)
    tab_label = Gtk::Label.new(File.basename(parent))
    hbox.pack_start(tab_label, :expand => true, :fill => true, :padding =>2)
    hbox.pack_start(close_but, :expand => true, :fill => true, :padding => 2)
    return swin, hbox, close_but, tab_label
  end

  def new_tab(tab, parent)
    swin, hbox, close_but, tab_label = create_tab_container(parent)
    file_store = Gtk::ListStore.new(String, String, TrueClass, Gdk::Pixbuf, String)
    fill_store(false, parent, tab, file_store) 
    iconview = RFileManagerIconView.new
    iconview.model = file_store
    iconview.selection_mode = :multiple
    iconview.text_column = COL_DISPLAY_NAME
    iconview.pixbuf_column = COL_PIXBUF
    mime = FileMagic.mime
    @file_actions_obj = FileActions.new
    iconview.signal_connect("item_activated"){|_, path| clicked_icon(path, mime, tab)}
    swin.add(iconview)
    # iconview x,y coordinate detect
    iconview.signal_connect("motion-notify-event") do |widget, event|
      @iconview_path = iconview.get_path_at_pos(event.x, event.y)
    end
    # right click activate
    iconview.signal_connect("button-press-event"){|_, event| select_icon(event, tab)}
    if tab.page == -1
      tab.show_tabs = false
    else
      tab.show_tabs = true
    end
    tab.append_page(swin, hbox)
    hbox.show_all
    # new page properties
    new_page = tab.get_nth_page(tab.n_pages-1)
    set_newpage_prop(new_page, parent, file_store, tab_label)
    close_but.signal_connect("clicked"){close_tab(tab, new_page)}
    tab.signal_connect("switch-page"){|_, _, num| set_addressline(num, tab);}
    iconview.focus = true
    iconview.signal_connect("key-press-event"){|_, event| on_key_press(event, tab)}
  end
 
  def on_key_press(event, tab)
    keyname = Gdk::Keyval.to_name(event.keyval)
    ctrl = event.state & Gdk::Window::ModifierType::CONTROL_MASK
    if ctrl == Gdk::Window::ModifierType::CONTROL_MASK
      # casecmp for ignore case, ctrl+c || ctrl+C
      if keyname.casecmp("C") == 0
        @file_actions_obj.copy_file(tab)
      elsif keyname.casecmp("X") == 0
      elsif keyname.casecmp("V") == 0
        @file_actions_obj.paste_file(tab)
        @main_window.show_all
      elsif keyname.casecmp("A") == 0 
      end
    end
  end

  def set_addressline(current_page_num, tab)
    # set focus as current iconview for shortcuts
    tab.get_nth_page(current_page_num).child.focus = true
    # set adress line
    @file_path_entry.buffer.text = tab.get_nth_page(current_page_num).child.parent
    check_next_back_buttons(current_page_num, tab)
  end

  def close_tab(tab, new_page)
    tab.remove_page(tab.page_num(new_page))
    if tab.n_pages == 1
      tab.show_tabs = false
    end
  end
  
  def set_newpage_prop(new_page, parent, file_store, tab_label)
    new_page.child.parent = parent
    new_page.child.curr_dir = parent
    new_page.child.route.push(parent)
    new_page.child.file_store = file_store
    new_page.child.label = tab_label
  end

  # when user clicked a icon for display content of directory or file
  def clicked_icon(path, mime, tab)
    iter = tab.get_nth_page(tab.page).child.file_store.get_iter(path)
    if iter[COL_DISPLAY_NAME]
      if mime.file(iter[COL_PATH]).include?("directory")
        tab.get_nth_page(tab.page).child.parent = iter[COL_PATH]
        fill_store("new_path", iter[COL_PATH], tab,
                               tab.get_nth_page(tab.page).child.file_store)
        @back_but.sensitive = true
        @up_but.sensitive = true
      else
        @file_actions_obj.open_default_application(iter[COL_PATH])
      end
    end
  end

  def select_icon(event, tab)
    if event.event_type == Gdk::Event::Type::BUTTON_PRESS
      if event.button == 3
        if @iconview_path != nil
          # secilmeden sadece iconun uzerine mouse geldiyse, otomatik secer
          tab.get_nth_page(tab.page).child.select_path(@iconview_path)
          @file_actions_obj.icon_rightclick_menu(event, @iconview_path, tab, @main_window) 
          @main_window.show_all
        else
          tab.get_nth_page(tab.page).child.unselect_all
          @file_actions_obj.tab_rightclick_menu(event, tab, @main_window)
        end
      end
    end
  end

  def set_tab_name(tab)
    # sets file path
    @file_path_entry.text = tab.get_nth_page(tab.page).child.parent
    # gets basename
    file_path = File.basename(tab.get_nth_page(tab.page).child.parent)
    # sets tab name
    tab.get_nth_page(tab.page).child.label.text = file_path
  end
  
  def check_next_back_buttons(page_num, tab)
    if tab.get_nth_page(page_num).child.route.length == 1
      @back_but.sensitive = false
      @next_but.sensitive = false
      return
    elsif tab.get_nth_page(page_num).child.curr_dir == tab.get_nth_page(page_num).child.route.last
      @back_but.sensitive = true
      @up_but.sensitive = true
      @next_but.sensitive = false
      return
    elsif tab.get_nth_page(page_num).child.curr_dir == tab.get_nth_page(page_num).child.route.first
      @back_but.sensitive = false
      @next_but.sensitive = true
      return
    else
      @back_but.sensitive = true
      @up_but.sensitive = true
      @next_but.sensitive = true
      return
    end
  end

  def fill_store(status, parent, tab, file_store)
    if status 
      check_status(status, tab)
    end
    # set_adress_line()
    if tab.page == -1
      filestore_update(parent, file_store, "recursive")
    else
      parent = tab.get_nth_page(tab.page).child.parent    
      filestore_update(parent, file_store, "recursive")
      set_tab_name(tab)
    end
  end

  def remove_item(tab, iter)
    tab.get_nth_page(tab.page).child.file_store.remove(iter)
  end

  # adds icon to iconview
  def add_item(file_icons, path, file_store)
      is_dir = FileTest.directory?(path)
      icon, icon_name = file_icons.get_icon(is_dir, path)
      iter = file_store.append
      iter[COL_DISPLAY_NAME] = GLib.filename_to_utf8(File.basename(path))
      iter[COL_PATH] = path
      if is_dir
        iter[COL_PATH] += "/"
      end
      iter[COL_IS_DIR] = is_dir
      iter[COL_PIXBUF] = icon
      iter[COL_ICONAME] = icon_name
  end

  def filestore_update(parent, file_store, status)
    file_icons = FileActions.new
    file_icons.get_icon_list
    if status == "recursive"
      file_store.clear
      Dir.glob(File.join(parent, "*")).each do |path|
        add_item(file_icons, path, file_store)
      end 
    else
      # displays parent directory, not recursive
      add_item(file_icons, parent, file_store)
    end
  end

  # implements according to file path new or old
  def check_status(status, tab) 
    i = tab.get_nth_page(tab.page).child.route.index(tab.get_nth_page(tab.page).child.curr_dir)
    if status == "new_path"
      # if path added already
      if i != nil and tab.get_nth_page(tab.page).child.route[i-1] == tab.get_nth_page(tab.page).child.parent
        go_back(i, tab)
      elsif i != nil and tab.get_nth_page(tab.page).child.route[i+1] == tab.get_nth_page(tab.page).child.parent
        go_next(i, tab)
        return
      # if route changes
      elsif i != nil and tab.get_nth_page(tab.page).child.route[i+1] != tab.get_nth_page(tab.page).child.parent
        tab.get_nth_page(tab.page).child.route = tab.get_nth_page(tab.page).child.route.take(i+1)
        @next_but.sensitive = false
        @back_but.sensitive = true
        @up_but.sensitive = true
      end
      tab.get_nth_page(tab.page).child.route.push(tab.get_nth_page(tab.page).child.parent)
      tab.get_nth_page(tab.page).child.curr_dir = tab.get_nth_page(tab.page).child.parent
    # pressed back but
    elsif status == "back"
    go_back(i, tab)
    # pressed next but
    elsif status == "next"
      go_next(i, tab)
    end
  end

  # implements back tool but
  def go_back(i, tab)
    @next_but.sensitive = true
    if i == 1
      @back_but.sensitive = false
      tab.get_nth_page(tab.page).child.parent = tab.get_nth_page(tab.page).child.route[i-1]
      tab.get_nth_page(tab.page).child.curr_dir = tab.get_nth_page(tab.page).child.parent
    end
    tab.get_nth_page(tab.page).child.parent = tab.get_nth_page(tab.page).child.route[i-1]
    tab.get_nth_page(tab.page).child.curr_dir = tab.get_nth_page(tab.page).child.parent
  end

  # implements next tool but
  def go_next(i, tab)
    @back_but.sensitive = true
    @up_but.sensitive = true
    if i + 2 == tab.get_nth_page(tab.page).child.route.length
      @next_but.sensitive = false
    end
    tab.get_nth_page(tab.page).child.parent = tab.get_nth_page(tab.page).child.route[i+1]
    tab.get_nth_page(tab.page).child.curr_dir = tab.get_nth_page(tab.page).child.parent
  end
 
  def pressed_home_buton(tab)
    if tab.get_nth_page(tab.page).child.curr_dir == "#{ENV["HOME"]}/"
      return
    end
    tab.get_nth_page(tab.page).child.parent = "#{ENV["HOME"]}/"
    fill_store(false, "#{ENV["HOME"]}/", tab, tab.get_nth_page(tab.page).child.file_store)
    tab.get_nth_page(tab.page).child.route.push("#{ENV["HOME"]}/")
    @back_but.sensitive = true
    @up_but.sensitive = true
    @next_but.sensitive = false
  end

  def pressed_up_button(tab)
    basename = File.basename(tab.get_nth_page(tab.page).child.parent)
    parent = tab.get_nth_page(tab.page).child.parent
    parent = parent.chomp(basename + "/")
    tab.get_nth_page(tab.page).child.parent = parent
    fill_store("new_path", tab.get_nth_page(tab.page).child.parent, tab, tab.get_nth_page(tab.page).child.file_store)
    if parent == "/"
      @up_but.sensitive = false
    end
  end

  def set_widget(back_button, next_button, file_path_entry, win, up_button)
    @back_but = back_button
    @next_but = next_button
    @up_but = up_button
    @file_path_entry = file_path_entry
    @main_window = win
  end
  
  # if any tab available return true for new_tab function
  def tab_available?(tab)
    if tab.n_pages >= 1
      return true
    end
  end

end
