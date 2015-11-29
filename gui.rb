#! ruby editor.rb "C:/Users/Cam/Programming/Visual Studio 2015/Projects/rpg_engine/rpg_engine"

require 'rubygems'
require 'gosu'

class Gui
    attr_reader :name, :actor, :selected, :snap, :input, :width, :height, :which_type, :current_depth, :image, :piece, :args
    attr_writer :name, :actor, :selected, :width, :height, :current_depth

    def initialize
        @input = nil
        @bg_col = 0xFF_AAAAAA
        @border_col = 0xFF_666666
        @text_col = 0xFF_000000
        @fg_col = 0xFF_FFFFFF

        @name = '<no name>'
        @width = 1024
        @height = 768
        @selected = nil
        @which_type = :actor
        @actor = '<no actor>'
        @args = Array.new
        @image = '<no image>'
        @img = nil
        @current_depth = 0
        @snap = {x: 32, y: 32}
        @piece = {x: 0, y: 0, w: 32, h: 32}
    end

    def set_room_name
        $window.start_input('Room name', lambda do |name|
            return false if name.length == 0
            @name = name.chomp.gsub(/[\s]/, '_')
        end)
    end

    def set_snap
        $window.start_input('Snap', lambda do |snap|
            return false if snap.count('x') != 1
            @snap[:x], @snap[:y] = snap.gsub(/[^\dx]/, '').split('x', 2).map {|x| [1, x.to_i.abs].max}
        end)
    end

    def set_dimensions
        $window.start_input('Dimensions', lambda do |dimensions|
            return false if dimensions.count('x') != 1
            @width, @height = dimensions.gsub(/[^\dx]/, '').split('x', 2).map {|x| x.to_i}
        end)
    end

    def set_depth
        $window.start_input('Depth', lambda do |depth|
            @current_depth = depth.gsub(/[^\d\-]/, '').to_i || 0
            return true
        end)
    end

    def raise_depth
        depths = $tiles.keys.map { |x| x.to_i }.sort
        i = 0
        if depths.length > 0
            while i < depths.length - 1 and depths[i] <= @current_depth
                i += 1
            end
            @current_depth = depths[i]
        end
    end

    def lower_depth
        depths = $tiles.keys.map { |x| x.to_i }.sort.reverse
        i = 0
        if depths.length > 0
            while i < depths.length - 1 and depths[i] >= @current_depth
                i += 1
            end
            @current_depth = depths[i]
        end
    end

    def set_actor
        if @which_type == :tile
            @which_type = :actor
            @selected = nil
        end
        $window.start_input('Actor', lambda do |actor|
            args = actor.split ' '
            actor = args.shift
            if $actors[actor] != nil and $actors[actor][:args] == args.length
                @actor = actor
                @args = args
                return true
            end
            return false
        end)
    end

    def set_tile
        if @which_type == :actor
            @which_type = :tile
            @selected = nil
        end
        $window.start_input('Tile (image X,Y WxH)', lambda do |str|
            image, w, h, x, y = nil
            pieces = str.chomp.split(' ', 3)
            pieces.each do |piece|
                if piece.include? ','
                    x, y = piece.split ','
                    x = x.to_i if x != nil
                    y = y.to_i if y != nil
                elsif piece.include? 'x'
                    w, h = piece.split 'x'
                    w = w.to_i if w != nil
                    h = h.to_i if h != nil
                else
                    image ||= piece
                end
            end
            if $images[image] != nil or @image != '<no image>'
                if $images[image] != nil
                    @image = image
                    @img = Gosu::Image.new("#{$cpp_project or '.'}/resource/image/#{$images[@image]}")
                end
                @piece = {x: x || @piece[:x], y: y || @piece[:y], w: w || @piece[:w] || @snap[:x], h: h || @piece[:h] || @snap[:y]}
                @piece[:h] = [@img.height, @piece[:h]].min
                @piece[:w] = [@img.width, @piece[:w]].min
                @piece[:y] = [@img.height - @piece[:h], @piece[:y]].min
                @piece[:x] = [@img.width - @piece[:w], @piece[:x]].min
                return true
            end
            return false
        end)
    end

    def shift_tile_up
        if @which_type == :tile and @img != nil
            @piece[:y] = [0, @piece[:y] - @snap[:y]].max
        end
    end
    def shift_tile_down
        if @which_type == :tile and @img != nil
            @piece[:y] = [@img.height - @piece[:h], @piece[:y] + @snap[:y]].min
        end
    end
    def shift_tile_left
        if @which_type == :tile and @img != nil
            @piece[:x] = [0, @piece[:x] - @snap[:x]].max
        end
    end
    def shift_tile_right
        if @which_type == :tile and @img != nil
            @piece[:x] = [@img.width - @piece[:w], @piece[:x] + @snap[:y]].min
        end
    end

    def contract_tile_ver
        if @which_type == :tile and @img != nil
            @piece[:h] = [@snap[:y], @piece[:h] - @snap[:y]].max
        end
    end
    def expand_tile_ver
        if @which_type == :tile and @img != nil
            @piece[:h] = [@img.height, @piece[:h] + @snap[:y]].min
            @piece[:y] = [@img.height - @piece[:h], @piece[:y]].min
        end
    end
    def contract_tile_hor
        if @which_type == :tile and @img != nil
            @piece[:w] = [@snap[:x], @piece[:w] - @snap[:x]].max
        end
    end
    def expand_tile_hor
        if @which_type == :tile and @img != nil
            @piece[:w] = [@img.width, @piece[:w] + @snap[:x]].min
            @piece[:x] = [@img.width - @piece[:w], @piece[:x]].min
        end
    end

    def click id, mouse_x, mouse_y
        case id
        when Gosu::MsLeft
            case mouse_y
            when (0..32) # set the room name
                set_room_name
            when (32..48) # set the room dimensions
                set_dimensions
            when (64..64+200-32) # click in the actor/tile selection box
                if @which_type == :actor
                    set_actor
                else
                    set_tile
                end
            when (200+32..200+32+16) # toggle actors/tiles
                if (16..100) === mouse_x
                    @which_type = :actor
                elsif (100..200-16) === mouse_x
                    @which_type = :tile
                end
                @selected = nil
            when (64+400..64+400+16) # set the snap x/y
                set_snap
            end
        end
    end

    def draw
        Gosu::draw_rect(0, 0, 200, 768, @bg_col)
        Gosu::draw_line(200, 0, @border_col, 200, 768, @border_col)

        $font.draw(@name, 16, 16, 0, 1, 1, @text_col)
        $font.draw("size: #{@width}x#{@height}", 16, 32, 0, 1, 1, @text_col)

        Gosu::draw_rect(16, 64, 200 - 32, 200 - 32, @border_col)
        Gosu::draw_rect(17, 65, 200 - 34, 200 - 34, @bg_col)

        if @actor != '<no actor>' and @which_type == :actor
            $font.draw(@actor, 16, 48, 0, 1, 1, @text_col)
            $actors[@actor][:sprite].draw(16, 64, 0)
        elsif @image != '<no image>' and @which_type == :tile
            $font.draw(@image, 16, 48, 0, 1, 1, @text_col)
            size = 200 - 32
            mid = size / 2
            xx = [0, mid - @piece[:x] - @piece[:w] / 2].max
            yy = [0, mid - @piece[:y] - @piece[:h] / 2].max

            px = [0, @piece[:x] + @piece[:w] / 2 - mid].max
            py = [0, @piece[:y] + @piece[:h] / 2 - mid].max
            pw = [size - xx, @img.width - px].min
            ph = [size - yy, @img.height - py].min

            @img.subimage(px, py, pw, ph).draw(16 + xx, 64 + yy, 0)
            Gosu::draw_rect(16 + [mid - @piece[:w] / 2, 0].max,
                            64 + [mid - @piece[:h] / 2, 0].max,
                            [size, @piece[:w]].min,
                            [size, @piece[:h]].min,
                            0x33_FFFFFF)
        end
        Gosu::draw_rect(16 + (100 - 16) * {actor: 0, tile: 1}[@which_type], 64 + 200 - 32, (200 - 32) / 2, 16, @fg_col)
        $font.draw('Actor', 16, 64 + 200 - 32, 0, 1, 1, @text_col)
        $font.draw('Tile', 100, 64 + 200 - 32, 0, 1, 1, @text_col)

        Gosu::draw_rect(16, 64 + 200 + 32, 200 - 32, 200 - 32, @border_col)
        Gosu::draw_rect(17, 64 + 200 + 33, 200 - 34, 200 - 34, @bg_col)

        if @selected != nil
            if @which_type == :actor
                $font.draw(@selected[:actor], 16, 64 + 200 + 16, 0, 1, 1, @text_col)
                $font.draw("X: #{$actors[@selected[:actor]][:locations][@selected[:location]][:x]}", 16, 64 + 200 + 32, 0, 1, 1, @text_col)
                $font.draw("Y: #{$actors[@selected[:actor]][:locations][@selected[:location]][:y]}", 16, 64 + 200 + 48, 0, 1, 1, @text_col)
                $font.draw("A: #{$actors[@selected[:actor]][:locations][@selected[:location]][:args]}", 16, 64 + 200 + 64, 0, 1, 1, @text_col)
            else
                $font.draw("Tile #{@selected[:which]}", 16, 64 + 200 + 16, 0, 1, 1, @text_col)
                $font.draw("X: #{$tiles[@selected[:depth]][@selected[:which]][:pos][:x]}", 16, 64 + 200 + 32, 0, 1, 1, @text_col)
                $font.draw("Y: #{$tiles[@selected[:depth]][@selected[:which]][:pos][:y]}", 16, 64 + 200 + 48, 0, 1, 1, @text_col)
                $font.draw("Z: #{@current_depth}", 16, 64 + 200 + 64, 0, 1, 1, @text_col)
            end
        else
            $font.draw('<none selected>', 16, 64 + 200 + 16, 0, 1, 1, @text_col)
        end

        $font.draw("Snap: #{@snap[:x]}x#{@snap[:y]}", 16, 64 + 200 + 200, 0, 1, 1, @text_col)

        $font.draw("Depth: #{@current_depth}", 16, 64 + 200 + 200 + 16, 0, 1, 1, @text_col)
    end
end