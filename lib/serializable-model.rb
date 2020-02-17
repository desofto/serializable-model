module SerializableModel
  def self.included(base)
    base.send :extend, ClassMethods
  end

  module ClassMethods
    attr_reader :attributes

    def attribute(*attrs)
      @attributes ||= {}

      attrs = [attrs] unless attrs.is_a? Array

      attrs.each do |attr|
        attr = { attr => {} } unless attr.is_a? Hash
        attr.each do |name, opts|
          name = name.to_sym

          @attributes[name] = opts

          type = opts.is_a?(Hash) ? opts[:type] : opts

          case type
          when nil, :string, 'string'
            attr_accessor name
          when :integer, 'integer'
            attr_reader name

            define_method("#{name}=") do |value|
              instance_variable_set("@#{name}", value.to_s.tr('^[0-9]', '').to_i)
            end
          when :float, 'float'
            attr_reader name

            define_method("#{name}=") do |value|
              instance_variable_set("@#{name}", value.to_s.tr(',', '.').to_f)
            end
          when :date, 'date'
            attr_reader name

            define_method("#{name}=") do |value|
              instance_variable_set("@#{name}", value.to_date)
            end
          when :time, 'time'
            attr_reader name

            define_method("#{name}=") do |value|
              instance_variable_set("@#{name}", value.to_time)
            end
          when :datetime, 'datetime'
            attr_reader name

            define_method("#{name}=") do |value|
              instance_variable_set("@#{name}", value.to_datetime)
            end
          when :array, 'array'
            define_method(name) do
              instance_variable_get("@#{name}") || []
            end
          else
            attr_reader name

            define_method("#{name}=") do |value|
              instance_variable_set("@#{name}", value) if value.in?(type) || value.try(:to_sym).in?(type)
            end
          end
        end
      end

      define_method(:initialize) do |attrs = {}|
        attrs.try(:symbolize_keys!)

        self.class.attributes.each do |name, opts|
          type = opts.is_a?(Hash) ? opts[:type] : opts

          if type.in? [:array, 'array']
            items = attrs[name] || []
            items = items.map { |item| opts[:class_name].to_s.constantize.new(item) } if opts.is_a?(Hash) && opts[:class_name].present?
            instance_variable_set("@#{name}", items)
          else
            hash = attrs[name] || (opts.is_a?(Hash) ? opts[:default] : nil)
            hash = opts[:class_name].to_s.constantize.new(hash || {}) if opts.is_a?(Hash) && opts[:class_name].present?
            send("#{name}=", hash)
          end
        end
      end

      define_method(:to_h) do
        hash = {}

        self.class.attributes.keys.each do |name|
          value = instance_variable_get("@#{name}")
          if value.respond_to? :map
            value = value.map do |item|
              item = item.to_h if item.respond_to? :to_h
              item
            end
          else
            value = value.to_h if value.respond_to? :to_h
          end

          hash[name] = value
        end

        hash
      end
    end
  end
end
