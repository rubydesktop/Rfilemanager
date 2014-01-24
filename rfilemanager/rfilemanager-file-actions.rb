require "gtk3"

class FileActions

# opens file with default application
def open_default_application(file)
  system "xdg-open #{file}"
end

end
