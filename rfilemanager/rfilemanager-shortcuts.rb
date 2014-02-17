require "gtk3"

class ShortCuts

  def create_shortcuts(accel_group, tab)
    accel_group.connect(Gdk::Keyval::GDK_KEY_A, Gdk::Window::ModifierType::CONTROL_MASK,
                        Gtk::AccelFlags::VISIBLE){tab.get_nth_page(tab.page).
                                                  child.select_all}
    accel_group.connect(Gdk::Keyval::GDK_KEY_C, Gdk::Window::ModifierType::CONTROL_MASK,
                        Gtk::AccelFlags::VISIBLE){p "ctrl-c"}
    accel_group.connect(Gdk::Keyval::GDK_KEY_X, Gdk::Window::ModifierType::CONTROL_MASK,
                        Gtk::AccelFlags::VISIBLE){p "ctrl-x"}
     

  end

end
