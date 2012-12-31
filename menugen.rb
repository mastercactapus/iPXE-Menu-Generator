#!/usr/bin/env ruby
require 'yaml'
puts "\#!ipxe"


CFG = ARGV[0]

exit 1 unless File.file? CFG

$id = 0
def new_id
  "i" + ($id += 1).to_s + "d"
end

class Menu < Hash
  attr_reader :parent, :dirs, :id, :menuid
  def initialize(yml, parent=nil)
    @id = new_id
    @menuid = @id
    @parent = parent
    @dirs =  @parent ? @parent.dirs : {}
    @dirs.merge! yml["set"] || {}
    @contents = yml["contents"]
    unless @parent.nil?
      @contents << {"gap" => "Navigate"}
      @contents << {"item" => make_link("Go Back",@parent)} unless @parent == get_root
      @contents << {"item" => make_link("Main Menu",get_root)}
    end
    merge! yml
  end
  
  def definition
    lines = []
    lines << "goto end_#{id}"
    lines << ":start_#{id}"
    lines << "menu --name #{id} #{self["label"]}"
    lines += @contents.map { |item| define_content(item.first.first, item.first.last) }
    lines << "choose --menu #{id} lsel && goto ${lsel}"
    lines << ":end_#{id}"

    lines.join("\n")
  end
  def trigger
    "goto start_#{id}"
  end
  private
  def make_link(label, menu)
    {
      "label" => label,
      "actions" => menu.trigger 
    }
  end
  def get_root
    p = self
    p = p.parent until p.parent == nil
    p
  end
  def define_content(type,data)
    case type
    when "gap"
      Gap.new(data, self).to_s
    when "item"
      Item.new(data, self).to_s
    when "menu"
      menu = Menu.new(data, self)
      item = Item.new(make_link(data["label"],menu),self)
      [menu.definition, item.to_s].join("\n")
    else
      puts type
      puts data
      throw :fit => "Malformed menu.yml!! contents must only contain gap, item, or menu"
    end
  end
end

class Item < Hash
  attr_reader :parent, :dirs, :menuid, :id
  def initialize(yml, parent)
    @parent = parent
    @id = new_id
    @menuid = @parent.menuid
    @dirs = @parent.dirs
    if yml["append_dir"]
      @dirs = {}
      @parent.dirs.each do |dir,path|
        @dirs[dir] = File.join(path,yml["append_dir"])
      end
    else
      @dirs = @parent.dirs
    end
    merge! yml
  end
  def to_s
    lines = []
    lines << "item --menu #{menuid} start_#{id} #{self["label"]}"
    lines << "goto end_#{id}"
    lines << ":start_#{id}"
    
    act = (self["actions"].is_a?(Array) ? self["actions"] : [self["actions"]]).join("\n")
    @dirs.each do |dir,path|
      act.gsub! "_#{dir}_", path
    end
    lines << act + " ||"
    
    lines << "goto err"
    lines << ":end_#{id}"

    lines.join("\n")    
  end
end

class Gap < String
  attr_reader :parent, :menuid, :label
  def initialize(gap_str, parent)
    @parent = parent
    @menuid = @parent.menuid
    @label = gap_str
  end
  def to_s
    "item --menu #{menuid} --gap #{label}"
  end
end

cfg = YAML.load_file(CFG)

main = Menu.new(cfg["root_menu"])

puts main.definition

puts ":err"
puts main.trigger
puts "echo Should not have gotten here, dropping to shell!"
puts "shell"
