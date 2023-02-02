require 'flex_columns'
require 'flex_columns/helpers/exception_helpers'

describe FlexColumns::Contents::FlexColumnContentsBase do
  include FlexColumns::Helpers::ExceptionHelpers

  before :each do
    @klass = Class.new(FlexColumns::Contents::FlexColumnContentsBase)
  end

  it "should include ActiveModel::Validations" do
    @klass.included_modules.map(&:name).include?("ActiveModel::Validations").should be
  end

  it "should extend FlexColumnContentsClass" do
    @klass.respond_to?(:is_flex_column_class?).should be
    @klass.is_flex_column_class?.should be
  end

  context "with a set-up class" do
    before :each do
      @model_class = Class.new
      allow(@klass).to receive(:model_class).with(no_args).and_return(@model_class)
      allow(@klass).to receive(:column_name).with(no_args).and_return(:fcn)

      @json_string = '{"foo":"bar","bar":"baz"}'

      @model_instance = @model_class.new
      allow(@model_instance).to receive(:[]).with(:fcn).and_return(@json_string)

      @column_data = double("column_data")
    end

    def expect_column_data_creation(input)
      expect(@klass).to receive(:_flex_columns_create_column_data).once do |*args|
        args.length.should == 2
        args[0].should == input
        args[1].class.should be(@klass)

        @column_data
      end
    end

    describe "#initialize" do
      it "should accept nil" do
        expect_column_data_creation(nil)
        @klass.new(nil)
      end

      it "should accept a String" do
        source_string = " foo "
        expect_column_data_creation(source_string)
        @klass.new(source_string)
      end

      it "should accept a model of the right class" do
        expect_column_data_creation(@json_string)
        @klass.new(@model_instance)
      end

      it "should not accept a model of the wrong class" do
        wrong_model_class = Class.new
        allow(@model_class).to receive(:name).and_return("bongo")
        wrong_model_instance = wrong_model_class.new
        class << wrong_model_instance
          def to_s
            "whatevs"
          end
          def inspect
            "whatevs"
          end
        end
        e = capture_exception(ArgumentError) { @klass.new(wrong_model_instance) }
        e.message.should match(/bongo/i)
        e.message.should match(/whatevs/i)
      end
    end

    describe "#describe_flex_column_data_source" do
      it "should work with a model instance" do
        expect_column_data_creation(@json_string)
        @instance = @klass.new(@model_instance)

        allow(@model_class).to receive(:name).with(no_args).and_return("mcname")
        allow(@model_instance).to receive(:id).with(no_args).and_return("mcid")
        s = @instance.describe_flex_column_data_source

        s.should match(/mcname/)
        s.should match(/mcid/)
        s.should match(/fcn/)
      end

      it "should work with a raw string" do
        expect_column_data_creation(@json_string)
        @instance = @klass.new(@json_string)

        allow(@model_class).to receive(:name).with(no_args).and_return("mcname")
        s = @instance.describe_flex_column_data_source
        s.should match(/mcname/)
        s.should match(/fcn/)
      end
    end

    describe "#notification_hash_for_flex_column_data_source" do
      it "should work with a model instance" do
        expect_column_data_creation(@json_string)
        @instance = @klass.new(@model_instance)

        h = @instance.notification_hash_for_flex_column_data_source
        h.keys.sort_by(&:to_s).should == [ :model_class, :column_name, :model ].sort_by(&:to_s)
        h[:model_class].should be(@model_class)
        h[:column_name].should == :fcn
        h[:model].should be(@model_instance)
      end

      it "should work with a raw string" do
        expect_column_data_creation(@json_string)
        @instance = @klass.new(@json_string)

        h = @instance.notification_hash_for_flex_column_data_source
        h.keys.sort_by(&:to_s).should == [ :model_class, :column_name, :source ].sort_by(&:to_s)
        h[:model_class].should be(@model_class)
        h[:column_name].should == :fcn
        h[:source].should == @json_string
      end
    end

    describe "#before_validation!" do
      it "should do nothing if created with a raw string" do
        expect_column_data_creation(@json_string)
        @instance = @klass.new(@json_string)
        @instance.before_validation!
      end

      it "should do nothing if the instance is valid" do
        expect_column_data_creation(@json_string)
        @instance = @klass.new(@model_instance)

        expect(@instance).to receive(:valid?).once.with(no_args).and_return(true)
        @instance.before_validation!
      end

      it "should copy errors over if the instance is invalid" do
        expect_column_data_creation(@json_string)
        @instance = @klass.new(@model_instance)

        expect(@instance).to receive(:valid?).once.with(no_args).and_return(false)
        allow(@instance).to receive(:errors).with(no_args).and_return([
          double('error', attribute: :e1, message: :m1),
          double('error', attribute: :e2, message: :m2)
        ])

        errors = Object.new
        class << errors
          def add(k, v)
            @_errors ||= [ ]
            @_errors << [ k, v ]
          end

          def all_errors
            @_errors
          end
        end

        allow(@model_instance).to receive(:errors).with(no_args).and_return(errors)

        @instance.before_validation!
        all_errors = errors.all_errors
        all_errors.length.should == 2

        e1 = all_errors.detect { |e| e[0] == "fcn.e1" }
        e1[1].should == :m1

        e2 = all_errors.detect { |e| e[0] == "fcn.e2" }
        e2[1].should == :m2
      end
    end

    describe "JSON serialization" do
      it "should return ColumnData#to_hash_for_serialization for #to_hash_for_serialization and #as_json" do
        expect_column_data_creation(@json_string)
        @instance = @klass.new(@model_instance)

        allow(@column_data).to receive(:to_hash).and_return({ :a => :b, :c => :d })
        @instance.to_hash_for_serialization.should == { :a => :b, :c => :d }
        @instance.as_json.should == { :a => :b, :c => :d }
      end
    end

    describe "#before_save!" do
      it "should do nothing if created with a raw string" do
        expect_column_data_creation(@json_string)
        @instance = @klass.new(@json_string)

        @instance.before_save!
      end

      context "with a valid instance" do
        before :each do
          expect_column_data_creation(@json_string)
          @instance = @klass.new(@model_instance)
          allow(@model_instance).to receive(:_flex_column_object_for).with(:fcn, false).and_return(@instance)
        end

        it "should tell you if it's been deserialized" do
          expect(@column_data).to receive(:deserialized?).once.with(no_args).and_return(true)
          @instance.deserialized?.should be
          expect(@column_data).to receive(:deserialized?).once.with(no_args).and_return(false)
          @instance.deserialized?.should_not be
        end

        it "should save if the class tells it to" do
          expect(@klass).to receive(:requires_serialization_on_save?).once.with(@model_instance).and_return(true)
          expect(@column_data).to receive(:to_stored_data).once.with(no_args).and_return("somestoreddata")
          expect(@model_instance).to receive(:[]=).once.with(:fcn, "somestoreddata")
          @instance.before_save!
        end

        it "should not save if the class tells it not to" do
          expect(@klass).to receive(:requires_serialization_on_save?).once.with(@model_instance).and_return(false)
          @instance.before_save!
        end
      end
    end

    context "with a valid instance" do
      before :each do
        expect_column_data_creation(@json_string)
        @instance = @klass.new(@model_instance)
      end

      it "should return itself for #to_model" do
        @instance.to_model.should be(@instance)
      end

      it "should delegate to the column data on []" do
        expect(@column_data).to receive(:[]).once.with(:xxx).and_return(:yyy)
        @instance[:xxx].should == :yyy
      end

      it "should return a useful string for #inspect" do
        expect(@column_data).to receive(:to_hash).once.and_return({ :aaa => 'bbb', :ccc => 'ddd'})
        i = @instance.inspect
        i.should match(/aaa/)
        i.should match(/bbb/)
        i.should match(/ccc/)
        i.should match(/ddd/)
      end

      it "should abbreviate that hash, if necessary" do
        expect(@column_data).to receive(:to_hash).once.and_return({ :aaa => 'bbb', :ccc => ('ddd' * 1_000)})
        i = @instance.inspect
        i.should match(/aaa/)
        i.should match(/bbb/)
        i.should match(/ccc/)
        i.should match(/ddddddddd/)
        i.length.should < 1_000
      end

      it "should delegate to the column data on []=" do
        expect(@column_data).to receive(:[]=).once.with(:xxx, :yyy).and_return(:zzz)
        (@instance[:xxx] = :yyy).should == :yyy
      end

      it "should delegate to the column data on #touch!" do
        expect(@column_data).to receive(:touch!).once.with(no_args)
        @instance.touch!
      end

      it "should delegate to the column data on #to_json" do
        expect(@column_data).to receive(:to_json).once.with(no_args).and_return("somejsondata")
        @instance.to_json.should == "somejsondata"
      end

      it "should delegate to the column data on #to_stored_data" do
        expect(@column_data).to receive(:to_stored_data).once.with(no_args).and_return("somestoreddata")
        @instance.to_stored_data.should == "somestoreddata"
      end

      it "should delegate to the column data on #keys" do
        expect(@column_data).to receive(:keys).once.with(no_args).and_return([ :a, :z, :q ])
        @instance.keys.should == [ :a, :z, :q ]
      end
    end
  end
end
