require "gtk3"
require "filemagic"
require "./rfilemanager-iconview"
require "./rfilemanager-file-actions"
require "./rfilemanager-shortcuts"

class AddRemoveTab

  COL_PATH, COL_DISPLAY_NAME, COL_IS_DIR, COL_PIXBUF = (0..3).to_a

  def create_variable
    @shortcut_obj = ShortCuts.new
    @shortcut_obj.create_file_action_obj
    @file_actions_obj = FileActions.new
    @file_actions_obj.get_icon_list
  end

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
    file_store = Gtk::ListStore.new(String, String, TrueClass, Gdk::Pixbuf)
    fill_store(false, parent, tab, file_store) 
    iconview = RFileManagerIconView.new
    iconview.model = file_store
    iconview.selection_mode = :multiple
    iconview.text_column = COL_DISPLAY_NAME
    iconview.pixbuf_column = COL_PIXBUF
    mime = FileMagic.mime
    iconview.signal_connect("item_activated") do |_, path|
      iter = file_store.get_iter(path)
      if iter[COL_DISPLAY_NAME]
        if mime.file(iter[COL_PATH]).include?("directory")
          tab.get_nth_page(tab.page).child.parent = iter[COL_PATH]
          fill_store("new_path", iter[COL_PATH], tab, file_store)
          @back_but.sensitive = true
          @up_but.sensitive = true
        else
          @file_actions_obj.open_default_application(iter[COL_PATH])
        end
      end
    end
    swin.add(iconview)
   
    # iconview x,y coordinate detect
    iconview.signal_connect("motion-notify-event") do |widget, event|
      @iconview_path = iconview.get_path_at_pos(event.x, event.y)
    end

    # right click activate
    iconview.signal_connect("button-press-event") do |widget, event|
      if event.event_type == Gdk::Event::Type::BUTTON_PRESS
        if event.button == 3
          iconview.unselect_all
          if @iconview_path != nil
            iconview.select_path(@iconview_path)
            @file_actions_obj.rightclik_menu(event, @iconview_path, tab) 
            @main_window.show_all
          end
        end
      end
    end
    tab.append_page(swin, hbox)
    hbox.show_all
    # new page properties
    new_page = tab.get_nth_page(tab.n_pages-1)
    new_page.child.parent = parent
    new_page.child.curr_dir = parent
    new_page.child.route.push(parent)
    new_page.child.file_store = file_store
    new_page.child.label = tab_label
    close_but.signal_connect("clicked"){tab.remove_page(tab.page_num(new_page));
                                        if not tab_available?(tab)
                                          @file_path_entry.text = ""
                                        end
                                       }
    tab.signal_connect("switch-page") do |_, _, current_page_num|
      @file_path_entry.text = tab.get_nth_page(current_page_num).child.parent
      check_next_back_buttons(current_page_num, tab)
    end
    # iconview.drag_dest_set(Gtk::Drag::DestDefaults::ALL,
    #                   [["test", Gtk::Drag::TargetFlags::OTHER_WIDGET, 98765]],
    #                  Gdk::DragContext::Action::MOVE)
    # iconview.drag_source_set(Gdk::Window::ModifierType::BUTTON1_MASK,
    #                     [["test", Gtk::Drag::TargetFlags::OTHER_WIDGET, 12885]],
    #                     Gdk::DragContext::Action::MOVE)
    # iconview.signal_connect("drag-data-get") do |widget, drag_context, data, info, time|
    # drag_context.selection
    #end
    # iconview.signal_connect("drag-drop") do |w, dc, x, y, time|
    # w.drag_get_data(dc, dc.targets[-1], time)
    # target = w.drag_dest_find_target(dc, w.drag_dest_get_target_list())
    #end
    #iconview.enable_model_drag_source(Gdk::Window::ModifierType::BUTTON1_MASK,
    #                                  TARGET_TABLE,
    #                                  Gdk::DragContext::Action::COPY|Gdk::DragContext::Action::MOVE)
    #iconview.enable_model_drag_dest(TARGET_TABLE,
    #                                 Gdk::DragContext::Action::COPY|Gdk::DragContext::Action::MOVE)
    accel_group = Gtk::AccelGroup.new
    @shortcut_obj.create_shortcuts(accel_group, tab)
    @main_window.add_accel_group(accel_group)
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
      fill_store2(parent, file_store, true)
    else
      parent = tab.get_nth_page(tab.page).child.parent    
      fill_store2(parent, file_store, true)
      set_tab_name(tab)
    end
  end

  def fill_store2(parent, file_store, clear)
    if clear
      file_store.clear
    end
    icon_theme = Gtk::IconTheme.default
    Dir.glob(File.join(parent, "*")).each do |path|
      is_dir = FileTest.directory?(path)
      icon = @file_actions_obj.get_icon(is_dir, path)
      iter = file_store.append
      iter[COL_DISPLAY_NAME] = GLib.filename_to_utf8(File.basename(path))
      iter[COL_PATH] = path
      if is_dir
        iter[COL_PATH] += "/"
      end
      iter[COL_IS_DIR] = is_dir
      iter[COL_PIXBUF] = icon
    end
  end

  # implements according to file path new or old
  def check_status(status, tab) 
    i = tab.get_nth_page(tab.page).child.route.index(tab.get_nth_page(tab.page).child.curr_dir)
    if status == "new_path"
      # if path added already
      if i != nil and tab.get_nth_page(tab.page).child.route[i+1] == tab.get_nth_page(tab.page).child.parent
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
    if i+2 == tab.get_nth_page(tab.page).child.route.length
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
    fill_store("new_path", parent, tab, tab.get_nth_page(tab.page).child.file_store)
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
