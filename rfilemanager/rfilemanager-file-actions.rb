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
    all_volumes.each do |volume|
      v = volume.mount
      hash.store(v.name, v.get_mount.default_location.path)
    end
    return hash
  end
end
