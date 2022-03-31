require 'active_record'
require 'active_record/migration'

module FlexColumns
  module Helpers
    module SystemHelpers
      MIGRATION_CLASS_BREAKING_VERSION = 5

      def migrate(&block)
        migration_class = Class.new(migration_class_parent)
        metaclass = migration_class.class_eval { class << self; self; end }
        metaclass.instance_eval { define_method(:up, &block) }

        ::ActiveRecord::Migration.suppress_messages do
          migration_class.migrate(:up)
        end
      end

      def reset_schema_cache!(model)
        if model.connection.respond_to?(:schema_cache)
          model.connection.schema_cache.clear!
        elsif model.connection.respond_to?(:clear_cache!)
          model.connection.clear_cache!
        end
      end

      def define_model_class(name, table_name, &block)
        model_class = Class.new(::ActiveRecord::Base)
        ::Object.send(:remove_const, name) if ::Object.const_defined?(name)
        ::Object.const_set(name, model_class)
        model_class.table_name = table_name
        model_class.class_eval(&block)
      end

      def create_standard_system_spec_tables!
        migrate do
          drop_table :flexcols_spec_users rescue nil
          create_table :flexcols_spec_users do |t|
            t.string :name, :null => false
            t.text :user_attributes
            t.text :more_attributes
          end
        end
      end

      def create_standard_system_spec_models!
        define_model_class(:User, 'flexcols_spec_users') { }
      end

      def drop_standard_system_spec_tables!
        migrate do
          drop_table :flexcols_spec_users rescue nil
        end
      end

      def migration_class_parent
        return ::ActiveRecord::Migration if ::ActiveRecord::VERSION::STRING.to_f < MIGRATION_CLASS_BREAKING_VERSION

        ::ActiveRecord::Migration[::ActiveRecord::VERSION::STRING.to_f]
      end
    end
  end
end
