require 'tonkachi'

html = open('sample/merged_table.html').read
doc = Nokogiri::HTML.parse(html)
table_node = doc.at_css('table')
free_table_node = Tonkachi.free_rowspan_colspan(table_node)
open('sample/free_table.html', 'w'){|f|
  f.puts free_table_node.to_html
}

html = open('sample/normal_table.html').read
doc = Nokogiri::HTML.parse(html)
table_node = doc.at_css('table')
transposed_table_node = Tonkachi.transpose_nokogiri_table(table_node)
open('sample/transposed_table.html', 'w'){|f|
  f.puts transposed_table_node.to_html
}

html = open('sample/nodes.html').read
doc = Nokogiri::HTML.parse(html)
nodes = Tonkachi.get_nodes(doc.at_css('body'))
nodes.each{|node|
  if node.name == 'text' then
    if node.text.strip.empty? then
      next
    else
      puts node.text
    end
  else
    puts node.name
  end
  puts Tonkachi.get_css_path(node)
}
