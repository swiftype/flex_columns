require 'flex_columns/utilities'

module FlexColumns
  module Errors
    class Base < ::StandardError
      private
      def maybe_model_instance_description
        if model_instance
          " on #{model_instance.class.name} ID #{model_instance.id.inspect}"
        else
          ""
        end
      end
    end

    class FieldError < Base; end
    class NoSuchFieldError < FieldError
      attr_reader :model_instance, :column_name, :field_name, :all_field_names

      def initialize(model_instance, column_name, field_name, all_field_names)
        @model_instance = model_instance
        @column_name = column_name
        @field_name = field_name
        @all_field_names = all_field_names

        super(%{You tried to set field #{field_name.inspect} of flex column #{column_name.inspect}
#{maybe_model_instance_description}. However, there is no such field
defined on that flex column; the defined fields are:

  #{all_field_names.join(", ")}})
      end
    end

    class DefinitionError < Base; end
    class NoSuchColumnError < DefinitionError; end
    class InvalidColumnTypeError < DefinitionError; end

    class DataError < Base; end

    class JsonTooLongError < DataError
      attr_reader :model_instance, :column_name, :limit, :json_string

      def initialize(model_instance, column_name, limit, json_string)
        @model_instance = model_instance
        @column_name = column_name
        @limit = limit
        @json_string = json_string

        super(%{When trying to serialize JSON for the flex column #{column_name.inspect}
#{maybe_model_instance_description}, the JSON produced was too long
to fit in the database. We produced #{json_string.length} characters of JSON, but the
database's limit for that column is #{limit} characters.

The JSON we produced was:

  #{FlexColumns::Utilities.abbreviated_string(json_string)}})
      end
    end

    class InvalidDataInDatabaseError < DataError
      attr_reader :model_instance, :column_name, :raw_string

      def initialize(model_instance, column_name, raw_string)
        @model_instance = model_instance
        @column_name = column_name
        @raw_string = raw_string

        super(create_message)
      end

      private
      def create_message
        %{When parsing the JSON#{maybe_model_instance_description}, which is:

#{FlexColumns::Utilities.abbreviated_string(raw_string)}

}
      end
    end

    class UnparseableJsonInDatabaseError < InvalidDataInDatabaseError
      attr_reader :source_exception

      def initialize(model_instance, column_name, raw_string, source_exception)
        @source_exception = source_exception
        super(model_instance, column_name, raw_string)
      end

      private
      def create_message
        source_message = source_exception.message

        if source_message.respond_to?(:force_encoding)
          source_message.force_encoding("UTF-8")
          source_message = source_message.chars.select { |c| c.valid_encoding? }.join
        end

        super + %{, we got an exception: #{source_message} (#{source_exception.class.name})}
      end
    end

    class IncorrectlyEncodedStringInDatabaseError < InvalidDataInDatabaseError
      attr_reader :invalid_chars_as_array, :raw_data_as_array, :first_bad_position

      def initialize(model_instance, column_name, raw_string)
        @raw_data_as_array = raw_string.chars.to_a
        @valid_chars_as_array = [ ]
        @invalid_chars_as_array = [ ]
        @raw_data_as_array.each_with_index do |c, i|
          if (! c.valid_encoding?)
            @invalid_chars_as_array << c
            @first_bad_position ||= i
          else
            @valid_chars_as_array << c
          end
        end
        @first_bad_position ||= :unknown

        super(model_instance, column_name, @valid_chars_as_array.join)
      end

      private
      def create_message
        extra = %{\n\nThere are #{invalid_chars_as_array.length} invalid characters out of #{raw_data_as_array.length} total characters.
(The string above showing the original JSON omits them, so that it's actually a valid String.)
The first bad character occurs at position #{first_bad_position}.

Some of the invalid chars are (in hex):

    }

        extra += invalid_chars_as_array[0..19].map { |c| c.unpack("H*") }.join(" ")

        super + extra
      end
    end

    class InvalidJsonInDatabaseError < InvalidDataInDatabaseError
      attr_reader :returned_data

      def initialize(model_instance, column_name, raw_string, returned_data)
        super(model_instance, column_name, raw_string)
        @returned_data = returned_data
      end

      private
      def create_message
        super + %{, the JSON returned wasn't a Hash, but rather #{returned_data.class.name}:

#{FlexColumns::Utilities.abbreviated_string(returned_data.inspect)}}
      end
    end
  end
end
