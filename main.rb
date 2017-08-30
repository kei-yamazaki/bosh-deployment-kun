require 'psych'

RELEASE_DIR = ARGV[0]
REQUIRED_VALUE = '(( inline ))'
SHOW_DESCRIPTION = true

$count = 0
$check_map = {}

class Hash
  def sort_by_key(recursive = false, &block)
    self.keys.sort(&block).reduce({}) do |seed, key|
      seed[key] = self[key]
      if recursive && seed[key].is_a?(Hash)
        seed[key] = seed[key].sort_by_key(true, &block)
      end
      seed
    end
  end
end

def make_tree(key, value, result, key_str)
  if key.include?('.')
    keys = key.split('.', 2)
    if result[keys[0]].nil?
      result[keys[0]] = {}
    end
    make_tree(keys[1], value, result[keys[0]], key_str)
  else
    default_value = value[key_str]
    if default_value.nil?
      result[key + '-' + $count.to_s] = REQUIRED_VALUE
    else
      result[key + '-' + $count.to_s] = default_value
    end
    $count = $count + 1
  end
  result
end

def description_map(strs)
  map = {}
  strs.each_line do |str|
    desc = str.sub(/.+: /, '')
    if desc != str
      map[str.sub(/:.+$/, '')] = desc
    end
  end
  map
end

def find_description(description_map, line)
  key = line.sub(/:.+/, '')
  if !description_map[key].nil? && description_map[key] != REQUIRED_VALUE + "\n"
    '  # ' + description_map[key]
  else
    ''
  end
end

def dump(map)
  Psych.dump(map, :line_width => -1)
end

specs = Dir.glob(RELEASE_DIR)

all_props = {}
specs.each do |spec|
  all_props = all_props.merge(Psych.load_file(spec)['properties'])
end

result = {}
result_description = {}
all_props.each do |k, v|
  result = make_tree(k, v, result, 'default')
end

$count = 0
all_props.each do |k, v|
  result_description = make_tree(k, v, result_description, 'description')
end

result = result.sort_by_key(true)

result_strs = dump(result)
result_str_description_strs = dump(result_description)

desc_map = description_map(result_str_description_strs)

result_strs.each_line do |str|
  fixed_line = str.sub(/-\d+:/, ':')
  fixed_line = fixed_line.sub("\n", '')
  prefix = ''
  unless fixed_line.end_with?(REQUIRED_VALUE)
    prefix = '#'
  end
  if SHOW_DESCRIPTION
    puts prefix + fixed_line + find_description(desc_map, str)
  else
    puts prefix + fixed_line
  end
end
