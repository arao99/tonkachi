require "tonkachi/version"
require "nokogiri"

module Tonkachi
  class Error < StandardError; end
  # Your code goes here...
  @nodes = Array.new
  
  def self.free_rowspan_colspan(table_node)
    # free colspan
    table_node.css('tr').each{|tr|
      tr.css('th, td').each{|td|
        if td.has_attribute?('colspan') then
          colspan_count = td.attr('colspan').to_i
          td.delete('colspan')
          (colspan_count - 1).times{
            td.next = td.dup
          }
        end
      }
    }
    
    # fill td
    col_count_max = 0
    rowspan_count_array = Array.new
    table_node.css('tr').each{|tr|
      col_count = tr.css('th, td').length + rowspan_count_array.length
      if col_count_max < col_count then
        col_count_max = col_count
      end
      rowspan_count_array.map!{|rowspan_count|
        rowspan_count - 1
      }
      rowspan_count_array.delete(0)
      tr.css('th, td').each{|td|
        if td.has_attribute?('rowspan') then
          rowspan_count = td.attr('rowspan').to_i - 1
          unless rowspan_count == 0 then
            rowspan_count_array.push(rowspan_count)
          end
        end
      }
    }
    rowspan_count_array = Array.new
    table_node.css('tr').each{|tr|
      col_count = tr.css('th, td').length + rowspan_count_array.length
      lack_td_count = col_count_max - col_count
      lack_td_count.times{
        tr.add_child('<td> </td>')
      }
      rowspan_count_array.map!{|rowspan_count|
        rowspan_count - 1
      }
      rowspan_count_array.delete(0)
      tr.css('th, td').each{|td|
        if td.has_attribute?('rowspan') then
          rowspan_count = td.attr('rowspan').to_i - 1
          unless rowspan_count == 0 then
            rowspan_count_array.push(rowspan_count)
          end
        end
      }
    }
    
    # free rowspan
    col_max_idx = table_node.at_css('tr').css('th, td').length - 1
    (0..col_max_idx).each{|col_idx|
      rowspan = Hash.new
      if col_idx == col_max_idx then
        table_node.css('tr').each{|tr|
          if rowspan.has_key?(:count) then
            tr.css('th, td')[col_idx - 1].next = rowspan[:td].dup
            rowspan[:count] -= 1
            if rowspan[:count] == 0 then
              rowspan = Hash.new
            end
          elsif tr.css('th, td')[col_idx]&.has_attribute?('rowspan') then
            rowspan_count = tr.css('th, td')[col_idx].attr('rowspan').to_i - 1
            unless rowspan_count == 0 then
              rowspan[:count] = rowspan_count
              rowspan[:td] = tr.css('th, td')[col_idx]
            end
            tr.css('th, td')[col_idx].delete('rowspan')
          end
        }
      else
        table_node.css('tr').each{|tr|
          if rowspan.has_key?(:count) then
            if tr.css('th, td')[col_idx] then
              tr.css('th, td')[col_idx].previous = rowspan[:td].dup
            else
              tr.add_child(rowspan[:td].dup)
            end
            rowspan[:count] -= 1
            if rowspan[:count] == 0 then
              rowspan = Hash.new
            end
          elsif tr.css('th, td')[col_idx]&.has_attribute?('rowspan') then
            rowspan_count = tr.css('th, td')[col_idx].attr('rowspan').to_i - 1
            unless rowspan_count == 0 then
              rowspan[:count] = rowspan_count
              rowspan[:td] = tr.css('th, td')[col_idx]
            end
            tr.css('th, td')[col_idx].delete('rowspan')
          end
        }
      end
    }
    # return result
    return table_node
  end
  
  def self.transpose_nokogiri_table(table_node)
    # init transpose table node
    transpose_table_node = Nokogiri::XML::Node.new('table', table_node)
    
    # add attributes of original table (only for parsing)
    transpose_table_node.set_attribute('rooter', table_node.attr('rooter'))
    transpose_table_node.set_attribute('table_parser_courses', table_node.attr('table_parser_courses'))
    
    # prepare tr
    num_of_org_col = table_node.at_css('tr').css('th, td').length
    num_of_org_col.times{
      transpose_table_node.add_child('<tr></tr>')
    }
    
    # pick up th and td from original table and put them in transpose table
    table_node.css('tr').each{|tr|
      tr.css('th, td').each_with_index{|td, col_idx|
        transpose_table_node.css('tr')[col_idx].add_child(td.dup)
      }
    }
    
    # return result
    return transpose_table_node
  end
  
  def self.get_nodes(node)
    @nodes = Array.new
    node_with_flag = [node, false]
    dfs(node_with_flag)
    return @nodes
  end
  
  def self.get_css_path(node)
    parent_nodes = [get_class_id(node)]
    parent_node = node.parent
    parent_nodes.push(get_class_id(parent_node))
    
    while parent_node.name != 'html' do
      parent_node = parent_node.parent
      parent_nodes.push(get_class_id(parent_node))
    end
    return insert_class_id(parent_nodes.reverse, node.css_path)
  end
  
  private_class_method def self.dfs(node_with_flag)
    node_with_flag[1] = true
    @nodes.push(node_with_flag[0])
    children = node_with_flag[0].children
    children_with_flag = children.map{|child|
      [child, false]
    }
    children_with_flag.each{|child_with_flag|
      unless child_with_flag[1] then
        dfs(child_with_flag)
      end
    }
    return nil
  end
  
  private_class_method def self.get_class_id(node)
    node_attributes = [node.name, {}]
    if node.attributes.has_key?('class') then
      node_attributes[1]['class'] = node.attributes['class'].value
    end
    if node.attributes.has_key?('id') then
      node_attributes[1]['id'] = node.attributes['id'].value
    end
    return node_attributes
  end
  
  private_class_method def self.insert_class_id(parent_nodes, node_css_path)
    return_node_css_path = Array.new
    node_css_path.split(' > ').each_with_index{|tag, idx|
      unless parent_nodes[idx][1].empty? then
        if parent_nodes[idx][1].has_key?('class') then
          tag += '.' + parent_nodes[idx][1]['class']
        end
        if parent_nodes[idx][1].has_key?('id') then
          tag += '#' + parent_nodes[idx][1]['id']
        end
      end
      return_node_css_path.push(tag)
    }
    return return_node_css_path.join(' > ')
  end
end
