# encoding: utf-8

def format_keeper(content)
  content.gsub(/(\n{2,})/, "\n\n")
     .gsub(/(\b\{)/, " {")
     .gsub(/(^-\()/, "- (")
     .gsub(/(\b\n+\{)/, " {")
     .gsub(/(\n+\})/, "\n}")
     .gsub(/(\)\s+\{)/, ") {")
     .gsub(/(\}else)/, "} else")
     # .gsub(/(^\/\/\s+Created by .*?\.$)/) { |c| c + "\n" + c.split("Created")[0] + "Updated by junjie.li on 18/04/09" }
end

`find YH-IOS -name '*.h'`.split("\n").each do |filepath|
  puts filepath

  content = IO.read(filepath)
  content = format_keeper(content)
  File.open(filepath, "w:utf-8") do |file|
    file.puts(content)
  end
end