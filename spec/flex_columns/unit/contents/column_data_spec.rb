require 'flex_columns'
require 'flex_columns/helpers/exception_helpers'

describe FlexColumns::Contents::ColumnData do
  include FlexColumns::Helpers::ExceptionHelpers

  before :each do
    @field_set = double("field_set")
    allow(@field_set).to receive(:kind_of?).with(FlexColumns::Definition::FieldSet).and_return(true)
    allow(@field_set).to receive(:all_field_names).with(no_args).and_return([ :foo, :bar, :baz ])

    @field_foo = double("field_foo")
    allow(@field_foo).to receive(:field_name).and_return(:foo)
    allow(@field_foo).to receive(:json_storage_name).and_return(:foo)
    @field_bar = double("field_bar")
    allow(@field_bar).to receive(:field_name).and_return(:bar)
    allow(@field_bar).to receive(:json_storage_name).and_return(:bar)
    @field_baz = double("field_baz")
    allow(@field_baz).to receive(:field_name).and_return(:baz)
    allow(@field_baz).to receive(:json_storage_name).and_return(:baz)

    allow(@field_set).to receive(:field_named) do |x|
      case x.to_sym
      when :foo then @field_foo
      when :bar then @field_bar
      when :baz then @field_baz
      else nil
      end
    end

    allow(@field_set).to receive(:field_with_json_storage_name) do |x|
      case x.to_sym
      when :foo then @field_foo
      when :bar then @field_bar
      when :baz then @field_baz
      else nil
      end
    end

    @data_source = double("data_source")
    allow(@data_source).to receive(:describe_flex_column_data_source).with(no_args).and_return("describedescribe")
    allow(@data_source).to receive(:notification_hash_for_flex_column_data_source).and_return(:notif1 => :a, :notif2 => :b)

    @json_string = '  {"bar":123,"foo":"bar","baz":"quux"}   '
  end

  def klass
    FlexColumns::Contents::ColumnData
  end

  def new_with_string(s, options = { })
    new_with(options.merge(:storage_string => s))
  end

  def new_with(options)
    effective_options = {
      :data_source => @data_source, :unknown_fields => :preserve, :storage => :text, :storage_string => nil, :binary_header => true, :null => true
      }.merge(options)
    klass.new(@field_set, effective_options)
  end

  it "should validate options properly" do
    valid_options = {
      :data_source => @data_source,
      :unknown_fields => :preserve,
      :storage => :text
    }

    lambda { klass.new(double("not_a_field_set"), valid_options) }.should raise_error(ArgumentError)
    lambda { klass.new(@field_set, valid_options.merge(:data_source => nil)) }.should raise_error(ArgumentError)
    lambda { klass.new(@field_set, valid_options.merge(:unknown_fields => :foo)) }.should raise_error(ArgumentError)
    lambda { klass.new(@field_set, valid_options.merge(:storage => :foo)) }.should raise_error(ArgumentError)
    lambda { klass.new(@field_set, valid_options.merge(:length_limit => 'foo')) }.should raise_error(ArgumentError)
    lambda { klass.new(@field_set, valid_options.merge(:length_limit => 3)) }.should raise_error(ArgumentError)
    lambda { klass.new(@field_set, valid_options.merge(:compress_if_over_length => 3.5)) }.should raise_error(ArgumentError)
    lambda { klass.new(@field_set, valid_options.merge(:compress_if_over_length => 'foo')) }.should raise_error(ArgumentError)
    lambda { klass.new(@field_set, valid_options.merge(:null => 'foo')) }.should raise_error(ArgumentError)
  end

  context "with a valid instance" do
    before :each do
      @instance = new_with_string(@json_string)
    end

    describe "[]" do
      it "should reject invalid field names" do
        expect(@field_set).to receive(:field_named).with(:quux).and_return(nil)

        e = capture_exception(FlexColumns::Errors::NoSuchFieldError) { @instance[:quux] }
        e.data_source.should be(@data_source)
        e.field_name.should == :quux
        e.all_field_names.should == [ :foo, :bar, :baz ]
      end

      it "should return data from a valid field correctly" do
        @instance[:foo].should == 'bar'
      end
    end

    describe "[]=" do
      it "should reject invalid field names" do
        expect(@field_set).to receive(:field_named).with(:quux).and_return(nil)

        e = capture_exception(FlexColumns::Errors::NoSuchFieldError) { @instance[:quux] = "a" }
      end

      it "should assign data to a valid field correctly" do
        @instance[:foo] = "abc"
        @instance[:foo].should == "abc"
      end

      it "should transform Symbols to Strings" do
        @instance[:foo] = :abc
        @instance[:foo].should == "abc"
      end
    end

    it "should return keys for #keys" do
      @instance.keys.sort_by(&:to_s).should == [ :foo, :bar, :baz ].sort_by(&:to_s)
    end

    it "should not return things set to nil in #keys" do
      @instance[:bar] = nil
      @instance.keys.sort_by(&:to_s).should == [ :foo, :baz ].sort_by(&:to_s)
    end

    describe "touching" do
      it "should deserialize, if needed, on touch!" do
        instance = new_with_string("---unparseable JSON---")

        lambda { instance.touch! }.should raise_error(FlexColumns::Errors::UnparseableJsonInDatabaseError)
      end

      it "should be deserialized if you simply read from it" do
        @instance.deserialized?.should_not be
        @instance[:foo]
        @instance.deserialized?.should be
      end

      it "should be deserialized if you set a field to something different" do
        @instance.deserialized?.should_not be
        @instance[:foo] = 'baz'
        @instance.deserialized?.should be
      end
    end

    it "should return JSON data with #to_json" do
      json = @instance.to_json
      parsed = JSON.parse(json)
      parsed.keys.sort.should == %w{foo bar baz}.sort
      parsed['foo'].should == 'bar'
      parsed['bar'].should == 123
      parsed['baz'].should == 'quux'
    end

    describe "#to_hash" do
      it "should return a hash with the data in it, with indifferent access" do
        h = @instance.to_hash
        h.keys.sort.should == %w{foo bar baz}.sort
        h['foo'].should == 'bar'
        h['bar'].should == 123
        h['baz'].should == 'quux'
        h[:foo].should == 'bar'
        h[:bar].should == 123
        h[:baz].should == 'quux'
      end

      it "should deserialize if needed" do
        h = new_with_string(@json_string).to_hash
        h.keys.sort.should == %w{foo bar baz}.sort
        h['foo'].should == 'bar'
        h['bar'].should == 123
        h['baz'].should == 'quux'
      end

      it "should not return unknown fields" do
        h = new_with_string({ 'foo' => 'bar', 'baz' => 123, 'quux' => 'whatever' }.to_json).to_hash
        h.keys.sort.should == %w{foo baz}.sort
        h['foo'].should == 'bar'
        h['baz'].should == 123
        h['bar'].should be_nil
        h['quux'].should be_nil
      end
    end

    it "should accept a Hash as JSON, already parsed by the database stack" do
      @instance = new_with(:storage_string => { 'foo' => 'bar', 'baz' => 123, 'bar' => 'quux' })
      @instance['foo'].should == 'bar'
      @instance['bar'].should == 'quux'
      @instance['baz'].should == 123
    end

    describe "#to_stored_data" do
      it "should return JSON data properly" do
        json = @instance.to_stored_data
        parsed = JSON.parse(json)
        parsed.keys.sort.should == %w{foo bar baz}.sort
        parsed['foo'].should == 'bar'
        parsed['bar'].should == 123
        parsed['baz'].should == 'quux'
      end

      it "should return a raw JSON hash if the column type is :json" do
        @instance = new_with_string(@json_string, :storage => :json)
        @instance.to_stored_data.should == { :foo => 'bar', :baz => 'quux', :bar => 123 }
      end

      describe "with a text column" do
        it "should return nil if there's no data and the column allows it" do
          @instance = new_with_string("{}")
          @instance.to_stored_data.should == nil
        end

        it "should return the empty string if there's no data and the column does not allow nulls" do
          @instance = new_with_string("{}", :null => false)
          @instance.to_stored_data.should == ""
        end
      end

      describe "with a binary column" do
        it "should return nil if there's no data and the column allows it" do
          @instance = new_with_string("{}", :storage => :binary)
          @instance.to_stored_data.should == nil
        end

        it "should return the empty string if there's no data and the column does not allow nulls" do
          @instance = new_with_string("{}", :storage => :binary, :null => false)
          @instance.to_stored_data.should == ""
        end
      end

      it "should return JSON from a binary column with :header => false" do
        @instance = new_with_string(@json_string, :storage => :binary, :binary_header => false)
        json = @instance.to_stored_data
        parsed = JSON.parse(json)
        parsed.keys.sort.should == %w{foo bar baz}.sort
        parsed['foo'].should == 'bar'
        parsed['bar'].should == 123
        parsed['baz'].should == 'quux'
      end

      it "should return uncompressed JSON from a binary column without compression" do
        @instance = new_with_string(@json_string, :storage => :binary)
        stored = @instance.to_stored_data
        stored.should match(/^FC:01,0,/)
        json = stored[8..-1]

        parsed = JSON.parse(json)
        parsed.keys.sort.should == %w{foo bar baz}.sort
        parsed['foo'].should == 'bar'
        parsed['bar'].should == 123
        parsed['baz'].should == 'quux'
      end

      it "should return compressed JSON from a binary column with compression" do
        @json_string = ({ :foo => 'bar' * 1000, :bar => 123, :baz => 'quux' }.to_json)
        @instance = new_with_string(@json_string, :storage => :binary, :compress_if_over_length => 1)
        stored = @instance.to_stored_data
        stored.should match(/^FC:01,1,/)
        compressed = stored[8..-1]

        require 'stringio'
        input = StringIO.new(compressed, "r")
        reader = Zlib::GzipReader.new(input)
        uncompressed = reader.read

        parsed = JSON.parse(uncompressed)
        parsed.keys.sort.should == %w{foo bar baz}.sort
        parsed['foo'].should == 'bar' * 1000
        parsed['bar'].should == 123
        parsed['baz'].should == 'quux'
      end

      it "should return uncompressed JSON from a binary column with compression, but that isn't long enough" do
        @json_string = ({ :foo => 'bar', :bar => 123, :baz => 'quux' }.to_json)
        @instance = new_with_string(@json_string, :storage => :binary, :compress_if_over_length => 10_000)
        stored = @instance.to_stored_data
        stored.should match(/^FC:01,0,/)
        json = stored[8..-1]

        parsed = JSON.parse(json)
        parsed.keys.sort.should == %w{foo bar baz}.sort
        parsed['foo'].should == 'bar'
        parsed['bar'].should == 123
        parsed['baz'].should == 'quux'
      end

      it "should blow up if the string won't fit" do
        @json_string = ({ :foo => 'bar' * 1000, :bar => 123, :baz => 'quux' }.to_json)
        @instance = new_with_string(@json_string, :storage => :binary, :length_limit => 1_000)

        e = capture_exception(FlexColumns::Errors::JsonTooLongError) { @instance.to_stored_data }
        e.data_source.should be(@data_source)
        e.limit.should == 1_000
        e.json_string.should match(/^FC:01,0,/)
        e.json_string.length.should >= 3_000
      end
    end

    describe "deserialization" do
      it "should raise an error if encoding is wrong" do
        bad_encoding = double("bad_encoding")
        allow(bad_encoding).to receive(:kind_of?).with(String).and_return(true)
        allow(bad_encoding).to receive(:kind_of?).with(Hash).and_return(false)
        expect(bad_encoding).to receive(:valid_encoding?).with(no_args).and_return(false)

        exception = StandardError.new("bonk")
        expect(FlexColumns::Errors::IncorrectlyEncodedStringInDatabaseError).to receive(:new).once.with(@data_source, bad_encoding).and_return(exception)

        capture_exception { new_with_string(bad_encoding)[:foo] }.should be(exception)
      end

      it "should accept blank strings just fine" do
        instance = new_with_string("   ")
        instance[:foo].should be_nil
        instance[:bar].should be_nil
        instance[:baz].should be_nil
      end

      it "should raise an error if the JSON doesn't parse" do
        bogus_json = "---unparseable JSON---"
        instance = new_with_string(bogus_json)

        e = capture_exception(FlexColumns::Errors::UnparseableJsonInDatabaseError) { instance[:foo] }
        e.data_source.should be(@data_source)
        e.raw_string.should == bogus_json
        e.source_exception.kind_of?(JSON::ParserError).should be
        e.message.should match(/describedescribe/)
      end

      it "should raise an error if the JSON doesn't represent a Hash" do
        bogus_json = "[ 1, 2, 3 ]"
        instance = new_with_string(bogus_json)

        e = capture_exception(FlexColumns::Errors::InvalidJsonInDatabaseError) { instance[:foo] }
        e.data_source.should be(@data_source)
        e.raw_string.should == bogus_json
        e.returned_data.should == [ 1, 2, 3 ]
        e.message.should match(/describedescribe/)
      end

      it "should accept uncompressed strings with a header" do
        instance = new_with_string("FC:01,0,#{@json_string}")
        instance[:foo].should == "bar"
        instance[:bar].should == 123
        instance[:baz].should == "quux"
      end

      it "should accept compressed strings with a header" do
        require 'stringio'
        stream = StringIO.new("w")
        writer = Zlib::GzipWriter.new(stream)
        writer.write(@json_string)
        writer.close

        header = "FC:01,1,"
        header.force_encoding("BINARY") if header.respond_to?(:force_encoding)
        total = header + stream.string
        total.force_encoding("BINARY") if total.respond_to?(:force_encoding)
        instance = new_with_string(total)
        instance[:foo].should == "bar"
        instance[:bar].should == 123
        instance[:baz].should == "quux"
      end

      it "should fail if the version number is too big" do
        bad_string = "FC:02,0,#{@json_string}"
        instance = new_with_string(bad_string)

        e = capture_exception(FlexColumns::Errors::InvalidFlexColumnsVersionNumberInDatabaseError) { instance[:foo] }
        e.data_source.should be(@data_source)
        e.raw_string.should == bad_string
        e.version_number_in_database.should == 2
        e.max_version_number_supported.should == 1
        e.message.should match(/describedescribe/)
      end

      it "should fail if the compression number is too big" do
        require 'stringio'
        stream = StringIO.new("w")
        writer = Zlib::GzipWriter.new(stream)
        writer.write(@json_string)
        writer.close

        header = "FC:01,2,"
        header.force_encoding("BINARY") if header.respond_to?(:force_encoding)
        bad_string = header + stream.string
        bad_string.force_encoding("BINARY") if bad_string.respond_to?(:force_encoding)

        instance = new_with_string(bad_string)
        e = capture_exception(FlexColumns::Errors::InvalidDataInDatabaseError) { instance[:foo] }
        e.data_source.should be(@data_source)
        e.raw_string.should == bad_string
        e.message.should match(/2/)
        e.message.should match(/describedescribe/)
      end

      it "should fail if the compressed data is bogus" do
        require 'stringio'
        stream = StringIO.new("w")
        writer = Zlib::GzipWriter.new(stream)
        writer.write(@json_string)
        writer.close
        compressed_data = stream.string

        100.times do
          pos_1 = rand(10)
          pos_2 = rand(10)
          tmp = compressed_data[pos_1]
          compressed_data[pos_1] = compressed_data[pos_2]
          compressed_data[pos_2] = tmp
        end

        header = "FC:01,1,"
        header.force_encoding("BINARY") if header.respond_to?(:force_encoding)
        bad_string = header + compressed_data
        bad_string.force_encoding("BINARY") if bad_string.respond_to?(:force_encoding)

        instance = new_with_string(bad_string)
        e = capture_exception(FlexColumns::Errors::InvalidCompressedDataInDatabaseError) { instance[:foo] }
        e.data_source.should be(@data_source)
        e.raw_string.should == bad_string
        e.source_exception.class.should == Zlib::GzipFile::Error
        e.message.should match(/describedescribe/)
      end
    end

    describe "notifications" do
      before :each do
        @deserializations = [ ]
        ds = @deserializations

        ActiveSupport::Notifications.subscribe('flex_columns.deserialize') do |name, start, finish, id, payload|
          ds << payload
        end

        @serializations = [ ]
        s = @serializations

        ActiveSupport::Notifications.subscribe('flex_columns.serialize') do |name, start, finish, id, payload|
          s << payload
        end
      end

      it "should trigger a notification on deserialization" do
        @deserializations.length.should == 0

        @instance[:foo].should == 'bar'
        @deserializations.length.should == 1
        @deserializations[0].should == { :notif1 => :a, :notif2 => :b, :raw_data => @json_string }
      end

      it "should trigger a notification on serialization" do
        @serializations.length.should == 0

        @instance[:foo].should == 'bar'
        @serializations.length.should == 0

        @instance.to_stored_data

        @serializations.length.should == 1
        @serializations[0].should == { :notif1 => :a, :notif2 => :b }
      end

      it "should not trigger a notification on #to_json" do
        @serializations.length.should == 0

        @instance[:foo].should == 'bar'
        @serializations.length.should == 0

        @instance.to_json

        @serializations.length.should == 0
      end

      it "should not deserialize until data is required" do
        @deserializations.length.should == 0
      end
    end

    describe "unknown-field handling" do
      it "should hang on to unknown data if asked" do
        s = { :foo => 'bar', :quux => 'baz' }.to_json
        @instance = new_with_string(s)
        parsed = JSON.parse(@instance.to_json)
        parsed['quux'].should == 'baz'
      end

      it "should discard unknown data if asked" do
        s = { :foo => 'bar', :quux => 'baz' }.to_json
        @instance = new_with_string(s, :unknown_fields => :delete)
        parsed = JSON.parse(@instance.to_json)
        parsed.keys.should == [ 'foo' ]
        parsed['quux'].should_not be
      end

      it "should not allow unknown data to conflict with known data" do
        field_set = double("field_set")
        allow(field_set).to receive(:kind_of?).with(FlexColumns::Definition::FieldSet).and_return(true)
        allow(field_set).to receive(:all_field_names).with(no_args).and_return([ :foo ])

        field_foo = double("field_foo")
        allow(field_foo).to receive(:field_name).and_return(:foo)
        allow(field_foo).to receive(:json_storage_name).and_return(:bar)

        allow(field_set).to receive(:field_named) do |x|
          case x.to_sym
          when :foo then field_foo
          else nil
          end
        end

        allow(field_set).to receive(:field_with_json_storage_name) do |x|
          case x.to_sym
          when :bar then field_foo
          else nil
          end
        end

        json_string = { :foo => 'aaa', :bar => 'bbb' }.to_json
        instance = klass.new(field_set, :storage_string => json_string, :data_source => @data_source,
          :unknown_fields => :preserve, :storage => :text, :binary_header => true,
          :null => true)

        instance[:foo].should == 'bbb'
        lambda { instance[:bar] }.should raise_error(FlexColumns::Errors::NoSuchFieldError)

        reparsed = JSON.parse(instance.to_json)
        reparsed.keys.sort.should == %w{foo bar}.sort
        reparsed['foo'].should == 'aaa'
        reparsed['bar'].should == 'bbb'
      end
    end
  end
end
