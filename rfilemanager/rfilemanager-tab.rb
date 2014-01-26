require "gtk3"
require "filemagic"
require "./rfilemanager-iconview"
require "./rfilemanager-file-actions"

class AddRemoveTab

  COL_PATH, COL_DISPLAY_NAME, COL_IS_DIR, COL_PIXBUF = (0..3).to_a

  def create_variable
    @icon_theme = Gtk::IconTheme.default
    @icon_list = @icon_theme.icons
    @mime = FileMagic.mime
    @file_actions_obj = FileActions.new
  end

  def new_tab(tab, parent)
    swin =  Gtk::ScrolledWindow.new
    viewport  = Gtk::Viewport.new(swin.hadjustment, swin.vadjustment)
    file_store = Gtk::ListStore.new(String, String, TrueClass, Gdk::Pixbuf)
    fill_store(false, parent, tab, file_store)
    iconview = RFileManagerIconView.new
    iconview.model = file_store
    iconview.selection_mode = :multiple
    iconview.text_column = COL_DISPLAY_NAME
    iconview.pixbuf_column = COL_PIXBUF
    iconview.signal_connect("item_activated") do |_, path|
      iter = file_store.get_iter(path)
      if iter[COL_DISPLAY_NAME]
        if @mime.file(iter[COL_PATH]).include?("directory")
          tab.get_nth_page(tab.page).child.parent = iter[COL_PATH]
          fill_store("new_path", iter[COL_PATH], tab, file_store)
          @back_but.sensitive = true
        else
          @file_actions_obj.open_default_application(iter[COL_PATH])
        end
      end
    end
    swin.add(iconview)
    tab.append_page(swin, Gtk::Label.new(File.basename(parent)))
    # new page properties
    new_page = tab.get_nth_page(tab.n_pages-1)
    new_page.child.parent = parent
    new_page.child.curr_dir = parent
    new_page.child.route.push(parent)
    new_page.child.file_store = file_store
    tab.signal_connect("switch-page") do |_, _, current_page_num|
      check_next_back_buttons(current_page_num, tab)
    end
  end

  def check_next_back_buttons(page_num, tab)
    if tab.get_nth_page(page_num).child.route.length == 1
      @back_but.sensitive = false
      @next_but.sensitive = false
      return
    elsif tab.get_nth_page(page_num).child.curr_dir == tab.get_nth_page(page_num).child.route.last
      @back_but.sensitive = true
      @next_but.sensitive = false
      return
    elsif tab.get_nth_page(page_num).child.curr_dir == tab.get_nth_page(page_num).child.route.first
      @back_but.sensitive = false
      @next_but.sensitive = true
      return
    else
      @back_but.sensitive = true
      @next_but.sensitive = true
      return
    end
  end

  def fill_store(status, parent, tab, file_store)
    if status 
      check_status(status, tab)
    end
    # set_adress_line()   
    file_store.clear
    if tab.page == -1
    fill_store2(parent, file_store)
    else
      parent = tab.get_nth_page(tab.page).child.parent    
      fill_store2(parent, file_store)
    end
  end

  def fill_store2(parent, file_store)
    Dir.glob(File.join(parent, "*")).each do |path|
      is_dir = FileTest.directory?(path)
      icon_name = get_icon_name(is_dir, path)
      icon = @icon_theme.load_icon(icon_name, 48, Gtk::IconTheme::LookupFlags::FORCE_SVG)
      iter = file_store.append
      iter[COL_DISPLAY_NAME] = GLib.filename_to_utf8(File.basename(path))
      iter[COL_PATH] = path
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
    if i+2 == tab.get_nth_page(tab.page).child.route.length
      @next_but.sensitive = false
    end
    tab.get_nth_page(tab.page).child.parent = tab.get_nth_page(tab.page).child.route[i+1]
    tab.get_nth_page(tab.page).child.curr_dir = tab.get_nth_page(tab.page).child.parent
  end

  def get_icon_name(is_dir, path)
    if is_dir
      icon = "gnome-fs-directory"
    else
        mimetype = @mime.file(path)
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
    return icon
  end

  def set_buttons(back_button, next_button)
    @back_but = back_button
    @next_but = next_button
  end
end
