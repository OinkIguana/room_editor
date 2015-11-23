#!ruby json-to-cpp.rb "C:/Users/Cam/Programming/Visual Studio 2015/Projects/rpg_engine/rpg_engine/resource/room" "C:/Users/Cam/Programming/Visual Studio 2015/Projects/rpg_engine/rpg_engine"

require 'json'
require 'erb'

render = ERB.new(File.read('./room.cpp.erb'), nil, '-')

in_dir = ARGV.shift.chomp unless ARGV.empty?
out_dir = ARGV.shift.chomp unless ARGV.empty?

rooms = Array.new

File.delete(*Dir.glob("#{out_dir or Dir.pwd}/room_*.cpp"))

room = JSON.parse '{}'

Dir.glob("#{in_dir or Dir.pwd}/*.json").each do |path|
    room = JSON.parse(IO.readlines(path).join)
    rooms << room['name']
    File.open("#{out_dir or Dir.pwd}/room_#{room['name']}.cpp", 'w') do |file|
        file.puts render.result
    end
end

render = ERB.new(File.read('./rooms_list.cpp.erb'), nil, '-')
File.open("#{out_dir or Dir.pwd}/rooms_list.cpp", 'w') do |file|
    file.puts render.result
end

puts "Created #{rooms.length} rooms"