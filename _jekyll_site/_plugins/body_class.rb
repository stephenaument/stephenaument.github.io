class BodyClassTag < Liquid::Tag
  def generate_body_class(prefix, id)
    puts "id: #{id}"
    id = id.gsub(/\.\w*?$/, '').gsub(/[-\/]/, '_').gsub(/^_/, '') # Remove extension from url, replace '-' and '/' with underscore, Remove leading '_'

    case prefix
    when "class"
      prefix = ""
    else
      prefix = "#{prefix}_"
    end

    "#{prefix}#{id}"
  end

  def render(context)
    page = context.environments.first["page"]
    classes = []

    classes.push page['path'].split('.').first

    classes.join(" ")
  end

end

Liquid::Template.register_tag('body_class', BodyClassTag)
