#!/usr/bin/ruby

require 'yajl'
require 'ruby_kml'
include KML

class KMLBuilder

  def initialize debug=nil
    @debug=debug
  end

  def pos_to_bits pos, fmt
    ds = pos*3600.0
    s=ds % 60.0
    m=(ds / 60).to_i % 60
    d=pos.to_i
    fmt % [d,m,s]
  end

  def posstrg lat,lng
    slat = (lat >= 0) ? 'N' : 'S';
    lat = lat.abs
    slng = (lng >= 0) ? 'E' : 'W';
    lng = lng.abs
    s0 = pos_to_bits(lat, "%02d:%02d:%04.1f")
    s1 = pos_to_bits(lng, "%03d:%02d:%04.1f")
    "#{s0}#{slat} #{s1}#{slng}"
  end

  def pts_from_file inf
    arry = []
    json = File.new(inf)
    Yajl::Parser.parse(json, {:symbolize_names => true}) do |o|
      if o[:type] == 'raw_gps'
	arry << {:lat => o[:lat],  :lon => o[:lon], :alt => o[:alt],
	  :utime => o[:utime], :spd => o[:spd], :cse => o[:cse]}
      end
    end
    arry
  end

  def build arry, outf, title=nil
    kml = KMLFile.new

    linestr=''
    title||='MWP Log'
    desc=title

    arry.each do |el|
      coords = "#{el[:lon]},#{el[:lat]},#{el[:alt]}"
      linestr << coords << "\n"
    end

    doc = {
      :name => 'Tracker',
      :styles => [
	Style.new(
		  :id => 'HeliIcon',
		  :icon_style => IconStyle.new(
					       :icon => Icon.new(
								 :href => "http://maps.google.com/mapfiles/kml/shapes/heliport.png"
								 )
					       )
		  ),
	Style.new(:id => "transBluePoly",
		  :line_style => LineStyle.new(:width => 1.5),
		  :poly_style => PolyStyle.new(:color => '7dff0000')
		  )
      ],
      :features => []
    }

    pm = Placemark.new(:name => 'Track',
                       :description => desc,
                       :style_url => '#transBluePoly',
                       :geometry => LineString.new(
                                                   :extrude => true,
                                                   :tessellate => false,
                                                   :altitude_mode => 'absolute',
                                                   :coordinates => linestr
                                                   )
		       )

    doc[:features] << pm
    arry.each do |p|
      ctim = Time.at(p[:utime]).gmtime.strftime("%FT%TZ")
      adesc = "#{title}<br/>Time: #{ctim}<br/>Position: #{posstrg(p[:lat],p[:lon])}<br/>Speed: #{"%.1f" % p[:spd]}m/s<br/>Course: #{"%d" % p[:cse]}deg<br/>Altitude: #{p[:alt]}m<br/>"
      coords = "#{p[:lon]},#{p[:lat]},#{p[:alt]}"
      pt = Placemark.new(:name => 'Track',
			 :description => adesc,
			 :geometry => Point.new(:coordinates=> coords),
			 )
      doc[:features] << pt
    end

    kml.objects <<  Document.new(doc)
    File.open(outf,'w') {|f| f.puts kml.render }
  end
end

if __FILE__ == $0
  k = KMLBuilder.new
  arry = k.pts_from_file ARGV[0]
  k.build arry, (ARGV[1]||STDOUT.fileno)
end