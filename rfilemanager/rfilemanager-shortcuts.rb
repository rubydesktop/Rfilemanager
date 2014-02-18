require "gtk3"
require "./rfilemanager-file-actions"

class ShortCuts

  def create_file_action_obj
    @file_action_obj = FileActions.new
  end

  def create_shortcuts(accel_group, tab, main_window)
    accel_group.connect(Gdk::Keyval::GDK_KEY_A, Gdk::Window::ModifierType::CONTROL_MASK,
                        Gtk::AccelFlags::VISIBLE){tab.get_nth_page(tab.page).
                                                  child.select_all}
    accel_group.connect(Gdk::Keyval::GDK_KEY_C, Gdk::Window::ModifierType::CONTROL_MASK,
                        Gtk::AccelFlags::VISIBLE){@file_action_obj.copy_file(tab)}
    accel_group.connect(Gdk::Keyval::GDK_KEY_X, Gdk::Window::ModifierType::CONTROL_MASK,
                        Gtk::AccelFlags::VISIBLE){p "ctrl-x"}
    accel_group.connect(Gdk::Keyval::GDK_KEY_V, Gdk::Window::ModifierType::CONTROL_MASK,
                        Gtk::AccelFlags::VISIBLE){@file_action_obj.paste_file(tab, main_window)}
  end

end
