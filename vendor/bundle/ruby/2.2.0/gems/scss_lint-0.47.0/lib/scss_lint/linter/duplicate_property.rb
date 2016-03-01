module SCSSLint
  # Checks for a property declared twice in a rule set.
  class Linter::DuplicateProperty < Linter
    include LinterRegistry

    def visit_root(_node)
      @ignore_consecutive = config['ignore_consecutive']
      yield
    end

    def check_properties(node)
      static_properties(node).each_with_object({}) do |prop, prop_names|
        prop_key = property_key(prop)

        if existing_prop = prop_names[prop_key]
          if existing_prop.line < prop.line - 1 || !ignore_consecutive_of?(prop)
            add_lint(prop, "Property `#{existing_prop.name.join}` already "\
                           "defined on line #{existing_prop.line}")
          else
            prop_names[prop_key] = prop
          end
        else
          prop_names[prop_key] = prop
        end
      end

      yield # Continue linting children
    end

    alias visit_rule check_properties
    alias visit_mixindef check_properties

  private

    def static_properties(node)
      node.children
          .select { |child| child.is_a?(Sass::Tree::PropNode) }
          .reject { |prop| prop.name.any? { |item| item.is_a?(Sass::Script::Node) } }
    end

    # Returns a key identifying the bucket this property and value correspond to
    # for purposes of uniqueness.
    def property_key(prop)
      prop_key = prop.name.join
      prop_value = property_value(prop)

      # Differentiate between values for different vendor prefixes
      prop_value.to_s.scan(/^(-[^-]+-.+)/) do |vendor_keyword|
        prop_key << vendor_keyword.first
      end

      prop_key
    end

    def property_value(prop)
      case prop.value
      when Sass::Script::Funcall
        prop.value.name
      when Sass::Script::String
      when Sass::Script::Tree::Literal
        prop.value.value
      else
        prop.value.to_s
      end
    end

    def ignore_consecutive_of?(prop)
      case @ignore_consecutive
      when true
        return true
      when false
        return false
      when nil
        return false
      when Array
        return @ignore_consecutive.include?(prop.name.join)
      else
        raise SCSSLint::Exceptions::LinterError,
              "#{@ignore_consecutive.inspect} is not a valid value for ignore_consecutive."
      end
    end
  end
end
