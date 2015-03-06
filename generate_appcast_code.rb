#!/usr/bin/env ruby

require 'json'
require 'open-uri'
require 'time'

if ARGV.length < 3
  puts "Usage: #{$PROGRAM_NAME} <version> <build> <local_zip_file>"
  exit 1
end

version, build, local_zip_file = ARGV

local_zip_file = File.expand_path(local_zip_file)
file_size = File.size(local_zip_file)

json = JSON.parse(open("https://api.github.com/repos/hivewallet/hive-mac/releases").read)
release = json.detect { |r| r['tag_name'] == version }

unless release
  puts "Error: Release #{version} not found on GitHub."
  exit 1
end

date = Time.parse(release['published_at']).rfc822
release_notes = release['body'].gsub(/\- (.*?)\r\n/, "              <li>\\1</li>\n").strip
zip_asset = release['assets'].detect { |a| a['content_type'] == 'application/zip' }

unless zip_asset
  puts "Error: Release #{version} has no zip file uploaded."
  exit 1
end

zip_url = "https://github.com/hivewallet/hive-mac/releases/download/#{version}/#{zip_asset['name']}"

puts %(
<item>
    <title>Hive #{version}</title>
    <description>
        <![CDATA[
            <style type="text/css">
              h2 { font-family: Helvetica; font-weight: bold; font-size: 10pt; }
              ul { font-family: Helvetica; font-size: 10pt; }
              li { margin: 5px 0px; }
            </style>

            <h2>What's changed:</h2>

            <ul>
              #{release_notes}
            </ul>
        ]]>
    </description>
    <pubDate>#{date}</pubDate>
    <enclosure
    url="#{zip_url}"
    sparkle:version="#{build}"
    sparkle:shortVersionString="#{version}"
    length="#{file_size}"
    type="application/octet-stream" />
</item>
)
