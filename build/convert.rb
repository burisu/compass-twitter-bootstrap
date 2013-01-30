require 'open-uri'
require 'json'

class Convert
  
  def initialize(bootstrap_version)
    @version = bootstrap_version.to_s
  end


  def process
    get_less_files.each do |name|
    # for name in ["labels-badges.less"]
      unless ['bootstrap.less', 'responsive.less'].include?(name)
        file = open_git_file("https://raw.github.com/twitter/bootstrap/#{@version}/less/#{name}")
        file = convert(file)

        if name == 'variables.less'
          file = insert_default_vars(file)
        end

        if name == 'labels-badges.less'
          file = fix_labels_badges(file)
        end

        save_file(name, file) unless name == 'mixins.less'
      end
    end

    self.create_sass_files
  end

  def create_sass_files
    puts 'Creating sass files for testing'

    scss_files = 'stylesheets'

    Dir.glob(scss_files+'/*').each do |dir|
      file_or_dir = File.open dir

      if File.file? file_or_dir
        convert_scss(file_or_dir)
      else
        Dir.open(file_or_dir).each do |filename|
          file = File.open("#{file_or_dir.path}/#{filename}")
          next unless File.fnmatch? '**.scss', file
          convert_scss(file, 'compass-twitter-bootstrap/')
        end
      end
    end
  end

private

  # Get the sha of less branch
  def get_tree_sha
    sha = nil
    trees = open("https://api.github.com/repos/twitter/bootstrap/git/trees/#{@version}").read
    trees = JSON.parse trees
    trees['tree'].find{|t| t['path'] == 'less'}['sha']
  end

  def get_less_files
    files = open("https://api.github.com/repos/twitter/bootstrap/git/trees/#{get_tree_sha}").read
    files = JSON.parse files
    files['tree'].select{|f| f['type'] == 'blob' }.map{|f| f['path'] }
  end


  def convert(file)
    file = replace_interpolation(file)
    file = replace_vars(file)
    file = replace_fonts(file)
    file = replace_font_family(file)
    file = replace_grads(file)
    file = replace_mixins(file)
    file = replace_less_extend(file)
    file = replace_includes(file)
    file = replace_spin(file)
    file = replace_opacity(file)
    file = replace_image_urls(file)
    file = replace_image_paths(file)
    file = replace_escaping(file)
    file = replace_keyframes(file)
    file = replace_media(file)

    file
  end

  def open_git_file(file)
    open(file).read
  end

  def save_file(name, content)
    name = name.gsub(/\.less/, '')
    f = File.open("stylesheets/compass-twitter-bootstrap/_#{name}.scss", "w+")
    f.write(content)
    f.close
    puts "Converted #{name}\n"
  end

  def replace_interpolation(less)
    less.gsub(/@{([^}]+)}/, '#{$\1}')
  end

  def replace_vars(less)
    less.gsub(/@[a-zA-Z0-9\-\_]+/) do |variable|
      variable = variable[1..-1]
      if ["keyframes", "media", "import", "page", "charset", "supports", "font-face", "namespace", "document"].include?(variable)
        "@" + variable
      else
        "$" + compassize(variable)
      end
    end
  end

  def replace_keyframes(less)
    less.gsub(/(\$)(-(webkit|moz|o|ms)-)?(keyframes)/, '@\2\3')
  end

  def replace_fonts(less)
    less.gsub(/#font \> \.([\w-]+)/, '@include ctb-font-\1')
  end

  def replace_font_family(less)
    less.gsub(/#font \> #family \> \.([\w-]+)/, '@include ctb-font-family-\1')
  end

  def replace_grads(less)
    less.gsub(/#gradient \> \.([\w-]+)/, '@include ctb-gradient-\1')
  end

  def replace_mixins(less)
    less.gsub(/^\.([\w-]*)(\(.*\))([\s\{]+)$/, '@mixin \1\2\3')
  end

  def replace_includes(less)
    less.gsub(/\.([\w-]*)(\(.*\));?/, '@include ctb-\1\2;')
  end

  def replace_less_extend(less)
    less.gsub(/\#(\w+) \> \.([\w-]*)(\(.*\));?/, '@include ctb-\1-\2\3;')
  end

  def replace_spin(less)
    less.gsub(/spin/, 'adjust-hue')
  end

  def replace_opacity(scss)
    scss.gsub(/\@include opacity\((\d+)\)/) {|s| "@include ctb-opacity(#{$1.to_f / 100})"}
  end

  def replace_image_urls(less)
    less.gsub(/background-image: url\("?(.*?)"?\);/) {|s| "background-image: image-url(\"#{$1}\");" }
  end

  def replace_image_paths(less)
    less.gsub('../img/', '')
  end

  def replace_escaping(less)
    less = less.gsub(/\~"([^"]+)"/, '#{\1}') # Get rid of ~ escape
    less.gsub(/(\W)e\("([^\)]+)"\)/) {|s| "#{$1 if $1 != /\s/}#{$2}"} # Get rid of e escape
  end

  def replace_media(less)
    less.gsub(/(^\s*)\$media(\ +)/, '\1@media\2')
  end

  def insert_default_vars(scss)
    scss.gsub(/^(\$.+);$/, '\1 !default;')
  end

  def fix_labels_badges(less)
    less.gsub(/\.label\s*\,[\s\n]*\.badge\s*\{[^\{]*\&\-important[^\{]*([^\{]*\{[^\{]*\}[^\{]*)+\}/m) do |rule|
      rule.gsub!(/\.label\,\s*\.badge/, '@each $item in label, badge')
      rule.gsub(/\&\-/, '.#{$item}-')
    end
  end


  def compassize(name)
    name.to_s.gsub(/(\d+)/, ' \1').gsub(/(\d)\ (\d)/, '\1\2').split(/(?=[A-Z])|\s+/).map(&:downcase).join('-')
  end


  def convert_scss(file, folder='')
    sass_files = 'stylesheets-sass'
    system("sass-convert #{file.path} #{sass_files}/#{folder}#{File.basename(file, 'scss')}sass")
  end

end

Convert.new("v2.2.2").process
