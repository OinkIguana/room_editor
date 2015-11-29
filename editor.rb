#! ruby editor.rb "C:/Users/Cam/Programming/Visual Studio 2015/Projects/rpg_engine/rpg_engine"

require 'json'
require 'rubygems'
require 'gosu'

require_relative 'gui'

$cpp_project = ARGV.shift.chomp unless ARGV.empty?
$cpp_project ||= 3

$images = Hash.new
$sprites = Hash.new
$actors = Hash.new
$tiles = Hash.new

$font = Gosu::Font.new(16, name: 'Courier')

class Editor < Gosu::Window
    def initialize
        super 1224, 768
        self.caption = 'Room Editor'
        @pan = {x: 0, y: 0}
        @input = nil
        @show_grid = true
        @click = {
            left: nil,
            middle: nil,
            right: nil
        }

        Dir.glob("#{$cpp_project or '.'}/*.image").each do |file|
            File.readlines(file).each do |line|
                name, file = line.split ' '
                $images[name] = file[1..-2]
            end
        end
        Dir.glob("#{$cpp_project or '.'}/*.sprite").each do |file|
            new_next = true
            cur_name = ''
            File.readlines(file).each do |line|
                if new_next
                    cur_name, image = line.chomp.split(' ', 2)
                    $sprites[cur_name] = {
                        file: $images[image],
                        image: nil
                    }
                    new_next = false
                elsif line.chomp == 'x'
                    new_next = true
                elsif line[0] == 'f'
                    x, y, w, h = line[1..-1].split(' ').map { |el| el.to_i }
                    $sprites[cur_name][:image] = Gosu::Image.new("#{$cpp_project or '.'}/resource/image/#{$sprites[cur_name][:file]}", {
                        tileable: true,
                        rect: [x, y, w, h]
                    })
                end
            end
        end
        Dir.glob("#{$cpp_project or '.'}/actor_*.h").each do |file|
            File.readlines(file).each do |line|
                if line[0...7] == '#Actor:'
                    name, sprite, depth = line[7..-1].chomp.split ' '
                    $actors[name] = {
                        sprite: sprite ? $sprites[sprite][:image] : nil,
                        depth: depth.to_i,
                        locations: Array.new
                    }
                end
            end
        end

        @gui = Gui.new
    end

    def update
        if @click[:middle] != nil
            @pan[:x] += @click[:middle][:x] - mouse_x
            @pan[:y] += @click[:middle][:y] - mouse_y
            @click[:middle] = {x: mouse_x, y: mouse_y}
        end
        if @click[:left] != nil
            if @gui.selected != nil
                if @gui.which_type == :actor
                    if Gosu::button_down? Gosu::KbLeftAlt
                        move_actor(mouse_x - 200 + @pan[:x], mouse_y + @pan[:y], @gui.selected)
                    else
                        move_actor(mouse_x - 200 + @pan[:x], mouse_y + @pan[:y], @gui.selected, @gui.snap)
                    end
                else
                    if Gosu::button_down? Gosu::KbLeftAlt
                        move_tile(mouse_x - 200 + @pan[:x], mouse_y + @pan[:y], @gui.selected)
                    else
                        move_tile(mouse_x - 200 + @pan[:x], mouse_y + @pan[:y], @gui.selected, @gui.snap)
                    end
                end
            end
            @click[:left] = {x: mouse_x, y: mouse_y}
        end
        if Gosu::button_down? Gosu::KbLeftShift
            @gui.selected = nil
            if @gui.which_type == :actor and @click[:left] != nil and @gui.actor != '<no actor>' and under_mouse == nil
                add_actor(@gui.actor, mouse_x + @pan[:x] - 200, mouse_y + @pan[:y], @gui.snap)
            elsif @gui.which_type == :tile and @click[:left] != nil and @gui.image != '<no image>' and under_mouse == nil
                add_tile({image: @gui.image, piece: @gui.piece}, mouse_x + @pan[:x] - 200, mouse_y + @pan[:y], @gui.current_depth, @gui.snap)
            elsif @click[:right] != nil
                if(@gui.which_type == :actor)
                    remove_actor under_mouse
                else
                    remove_tile under_mouse
                end
            end
        end
    end

    def draw
        Gosu::draw_rect(0, 0, width, height, 0xFF_777777)
        Gosu::draw_rect(-@pan[:x] + 200, -@pan[:y], @gui.width, @gui.height, 0xFF_FFFFFF)

        $actors.each do |name,actor|
            if actor[:sprite]
                actor[:locations].each do |loc|
                    actor[:sprite].draw(loc[:x] + 200 - @pan[:x], loc[:y] - @pan[:y], actor[:depth] || 50)
                end
            end
        end

        $tiles.each do |depth,tiles|
            tiles.each do |tile|
                tile[:img].draw(tile[:pos][:x] + 200 - @pan[:x], tile[:pos][:y] - @pan[:y], depth.to_i)
            end
        end

        @gui.draw

        if self.text_input != nil
            $font.draw("#{@input[:name]}: #{self.text_input.text.insert(self.text_input.caret_pos, '_')}", 16, 768 - 16, 100, 1, 1, 0xFF_000000)
        end

        if @show_grid
            (0...@gui.width).step @gui.snap[:x] do |xx|
                Gosu::draw_line(xx - @pan[:x] + 200, -@pan[:y], 0xFF_AAAAAA, xx - @pan[:x] + 200, -@pan[:y] + @gui.height, 0xFF_AAAAAA)
            end
            (0...@gui.height).step @gui.snap[:y] do |yy|
                Gosu::draw_line(-@pan[:x] + 200, yy - @pan[:y], 0xFF_AAAAAA, -@pan[:x] + 200 + @gui.width, yy - @pan[:y], 0xFF_AAAAAA)
            end
        end
    end

    def compile # converts the json to cpp
        puts `ruby json-to-cpp.rb "#{$cpp_project or '.'}/resource/room" "#{$cpp_project or '.'}"`
    end

    def clear_room
        @gui = Gui.new
        $tiles = Hash.new
        $actors.each do |name,actor|
            actor[:locations] = Array.new
        end
    end

    def save # saves the room to a .json file
        if @gui.name != '<no name>'
            act = Hash.new
            til = Hash.new
            $actors.each do |name, actor|
                act[name] = Array.new
                actor[:locations].each do |loc|
                    act[name] << [loc[:x], loc[:y]].map { |x| x.to_i }
                end
            end
            $tiles.each do |depth, tiles|
                if tiles.length > 0
                    til[depth.to_s] = Array.new
                    tiles.each do |tile|
                        til[depth.to_s] << {
                            image: tile[:image_name],
                            pos: {
                                x: tile[:pos][:x].to_i,
                                y: tile[:pos][:y].to_i
                            },
                            piece: {
                                x: tile[:piece][:x].to_i,
                                y: tile[:piece][:y].to_i,
                                w: tile[:piece][:w].to_i,
                                h: tile[:piece][:h].to_i
                            }
                        }
                    end
                end
            end
            data = {
                'name': @gui.name,
                'width': @gui.width,
                'height': @gui.height,
                'actors': act,
                'tiles': til
            }
            File.open("#{$cpp_project or '.'}/resource/room/#{@gui.name}.json", "w") do |file|
                file.puts JSON.pretty_generate data
            end
            puts "Saved to #{$cpp_project or '.'}/resource/room/#{@gui.name}.json"
        end
    end

    def load file # loads a room from a .json File
        room = JSON.parse IO.readlines(file).join
        @gui.name = room['name']
        @gui.width = room['width']
        @gui.height = room['height']
        room['actors'].each do |type, locations|
            locations.each do |(x, y)|
                add_actor(type, x, y)
            end
        end
        room['tiles'].each do |depth, tiles|
            tiles.each do |tile|
                add_tile({
                    image: tile['image'],
                    piece: {
                        x: tile['piece']['x'].to_i,
                        y: tile['piece']['y'].to_i,
                        w: tile['piece']['w'].to_i,
                        h: tile['piece']['h'].to_i
                    }
                }, tile['pos']['x'].to_i, tile['pos']['y'].to_i, depth.to_i)
            end
        end
    end

    def add_actor actor, xx, yy, snap = {x: 1, y: 1} # adds a new actor at the given position
        $actors[actor][:locations] << {x: xx - (xx % snap[:x]), y: yy - (yy % snap[:y])}
    end

    def move_actor xx, yy, actor, snap = {x: 1, y: 1} # moves an actor to the given position
        $actors[actor[:actor]][:locations][actor[:location]] = {x: xx - (xx % snap[:x]), y: yy - (yy % snap[:y])}
    end

    def remove_actor actor # removes an actor
        @gui.selected = nil
        if actor != nil
            $actors[actor[:actor]][:locations].delete_at actor[:location]
        end
    end

    def add_tile tile, xx, yy, dd, snap = {x: 1, y: 1} # adds a new tile at the given position
        $tiles[dd] ||= Array.new
        $tiles[dd] << {
            image_name: tile[:image],
            img: Gosu::Image.new("#{$cpp_project or '.'}/resource/image/#{$images[tile[:image]]}", {
                tileable: true,
                rect: [tile[:piece][:x], tile[:piece][:y], tile[:piece][:w], tile[:piece][:h]]
            }),
            piece: {
                x: tile[:piece][:x],
                y: tile[:piece][:y],
                w: tile[:piece][:w],
                h: tile[:piece][:h]
            },
            pos: {x: xx - (xx % snap[:x]), y: yy - (yy % snap[:y])}
        }
    end

    def move_tile xx, yy, tile, snap = {x: 1, y: 1} # moves a tile to the given position
        if tile != nil
            $tiles[tile[:depth]][tile[:which]][:pos] = {x: xx - (xx % snap[:x]), y: yy - (yy % snap[:y])}
        end
    end

    def remove_tile tile # removes an actor
        @gui.selected = nil
        if tile != nil
            $tiles[tile[:depth]].delete_at tile[:which]
        end
    end

    def under_mouse # finds the most recently created actor at the mouse position
        xx, yy = mouse_x - 200 + @pan[:x], mouse_y + @pan[:y]
        inst = nil
        if @gui.which_type == :actor
            $actors.each do |name, actor|
                w, h = [actor[:sprite].width, actor[:sprite].height] if actor[:sprite]
                w ||= 16
                h ||= 16
                actor[:locations].each_with_index do |loc, i|
                    if (0..w) === xx - loc[:x] and (0..h) === yy - loc[:y]
                        inst = {actor: name, location: i}
                    end
                end
            end
        else
            if $tiles[@gui.current_depth]
                $tiles[@gui.current_depth].each_with_index do |tile, i|
                    x, y, w, h = [tile[:pos][:x], tile[:pos][:y], tile[:piece][:w], tile[:piece][:h]]
                    if (0..w) === xx - x and (0..h) === yy - y
                        inst = {depth: @gui.current_depth, which: i}
                    end
                end
            end
        end
        return inst
    end

    def select_or_create_instance # selects the instance at the mouse position, or creates one if there is not one
        if not Gosu::button_down? Gosu::KbLeftShift
            if under_mouse != nil
                @gui.selected = under_mouse
            elsif @gui.actor != '<no actor>'
                add_actor(@gui.actor, mouse_x + @pan[:x] - 200, mouse_y + @pan[:y], @gui.snap)
                @gui.selected = {actor: @gui.actor, location: $actors[@gui.actor][:locations].length - 1}
            end
        end
    end

    def select_or_create_tile # selects the tile at the mouse position, or creates one if there is not one
        if not Gosu::button_down? Gosu::KbLeftShift
            if under_mouse != nil
                @gui.selected = under_mouse
            elsif @gui.image != '<no image>'
                add_tile({image: @gui.image, piece: @gui.piece}, mouse_x + @pan[:x] - 200, mouse_y + @pan[:y], @gui.current_depth, @gui.snap)
                @gui.selected = {depth: @gui.current_depth, which: $tiles[@gui.current_depth].length - 1}
            end
        end
    end

    def button_down id
        if @input == nil
            case id
            when Gosu::MsLeft, Gosu::MsRight, Gosu::MsMiddle
                if mouse_x <= 200
                    # pass mouse events in the GUI area to the GUI
                    @gui.click(id, mouse_x, mouse_y)
                    return
                else
                    case id
                    when Gosu::MsLeft
                        if(@gui.which_type == :actor)
                            select_or_create_instance
                        else
                            select_or_create_tile
                        end
                        @click[:left] = {x: mouse_x, y: mouse_y}
                    when Gosu::MsMiddle
                        @click[:middle] = {x: mouse_x, y: mouse_y}
                    when Gosu::MsRight
                        if(@gui.which_type == :actor)
                            remove_actor under_mouse
                        else
                            remove_tile under_mouse
                        end
                        @click[:right] = {x: mouse_x, y: mouse_y}
                    end
                end
            when Gosu::KbPageUp
                @gui.raise_depth
            when Gosu::KbPageDown
                @gui.lower_depth
            when Gosu::KbUp
                if Gosu::button_down? Gosu::KbLeftShift
                    @gui.contract_tile_ver
                else
                    @gui.shift_tile_up
                end
            when Gosu::KbDown
                if Gosu::button_down? Gosu::KbLeftShift
                    @gui.expand_tile_ver
                else
                    @gui.shift_tile_down
                end
            when Gosu::KbLeft
                if Gosu::button_down? Gosu::KbLeftShift
                    @gui.contract_tile_hor
                else
                    @gui.shift_tile_left
                end
            when Gosu::KbRight
                if Gosu::button_down? Gosu::KbLeftShift
                    @gui.expand_tile_hor
                else
                    @gui.shift_tile_right
                end
            when Gosu::KbD
                @gui.set_depth
            when Gosu::KbA
                @gui.set_actor
            when Gosu::KbT
                @gui.set_tile
            when Gosu::KbR
                clear_room
            when Gosu::KbN
                @gui.set_room_name
            when Gosu::KbX
                @gui.set_dimensions
            when Gosu::KbP
                @gui.set_snap
            when Gosu::KbG
                @show_grid = !@show_grid
            when Gosu::KbS
                save
            when Gosu::KbC
                compile
            when Gosu::Kb0
                @pan = {x: 0, y: 0}
            when Gosu::KbL
                start_input('Load file', lambda do |input|
                    file = "#{$cpp_project or '.'}/resource/room/#{input}.json"
                    if File.exist? file
                        clear_room
                        load file
                        return true
                    else
                        return false
                    end
                end)
            end
        else
            case id
            when Gosu::KbReturn
                finish_input
            when Gosu::KbEscape
                cancel_input
            end
        end
    end

    def button_up id
        case id
        when Gosu::MsLeft
            @click[:left] = nil
        when Gosu::MsMiddle
            @click[:middle] = nil
        when Gosu::MsRight
            @click[:right] = nil
        end
    end

    def needs_cursor?
        true
    end

    def start_input name, cb
        self.text_input = Gosu::TextInput.new
        @input = {name: name, cb: cb}
    end

    def cancel_input
        self.text_input = nil
        @input = nil
        return text_input
    end

    def finish_input
        return cancel_input if self.text_input.text == ''
        if @input[:cb].call self.text_input.text
            @input = nil
            self.text_input = nil
        end
    end
end

$window = Editor.new
$window.show