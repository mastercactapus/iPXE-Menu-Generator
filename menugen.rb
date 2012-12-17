require 'yaml'
puts "\#!ipxe"


URL = "http://nathan-server.lan/netboot"

$id = 0
def new_id
  "a" + ($id += 1).to_s + "b"
end

class Menu
  attr_reader :id
  def initialize(title)
    @id    = new_id
    @title = title
    @items = []
    @finished = false
  end
  def break(message="")
    @items << {
      id: "--gap",
      label: message
    }
  end
  def item(message, action)
    @items << {
      id: new_id,
      action: action,
      label:message
    }
  end
  def finish
    @finished=true
    puts "goto d#{id}"
    puts ":e#{id}"
    puts "menu --name #{id} #{@title}"
    @items.each { |item| puts item_str(item) }
    puts "choose --menu #{id} lsel && goto ${lsel}"
    puts ":d#{id}"
  end
  def display
    finish unless @finished
    puts display_str
  end
  def display_str
    "goto e#{id}"
  end
  private
  def item_str(item)
    out = ["item --menu #{id} #{item[:id]} #{item[:label] || ''}"]
    unless item[:action].nil?
      out << "goto c#{item[:id]}"
      out << ":#{item[:id]}"
      out << action_str(item[:action])
      out << "goto err"
      out << ":c#{item[:id]}"
    end
    out.join("\n")
  end
  def action_str(act)
    if act.is_a? Array
      act.map {|itm| action_str itm}.join("\n")
    elsif act.is_a? String
      act
    elsif act.is_a? Menu
      act.display_str
    end
  end
end

def gen_from_glob(glob_str, menu)
  Dir[glob_str].each do |file|
    cfg = YAML.load_file(file)
    lines = cfg[:lines].join("\n").gsub("_DIR_",File.dirname(file))
    menu.item cfg[:label], lines
  end
end

memiso = Menu.new("Boot ISO using memdisk")
saniso = Menu.new("Boot ISO using SAN")
main = Menu.new("Nathan's Network Boot System")

Dir["../iso/*.iso"].each do |file|
  file.sub! /^\.\./, URL
  memiso.item File.basename(file), 
    [ "kernel #{File.join(URL,"memdisk")}",
      "initrd #{file} harddisk=1",
      "boot"]
  saniso.item File.basename(file),
  "sanboot --keep --drive=0x80 #{file}"
end

memiso.break
saniso.break
memiso.item "Back to Main Menu", main.display_str
saniso.item "Back to Main Menu", main.display_str

main.break "ISO Boot"
main.item "SAN Boot Options", saniso.display_str
main.item "Memdisk Boot Options", memiso.display_str
main.break "Custom Boot Options"
gen_from_glob("custom/**/menu.yml", main)
main.break "Other Options"
main.item "Reboot", "reboot"
main.item "iPXE Shell", "shell"

memiso.finish
saniso.finish
main.finish

main.display

puts ":err"
puts "echo Should not have gotten here, dropping to shell!"
puts "shell"
