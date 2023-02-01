require 'flex_columns'
require 'flex_columns/helpers/system_helpers'
require 'flex_columns/helpers/exception_helpers'

describe "FlexColumns JSON aliasing" do
  include FlexColumns::Helpers::SystemHelpers
  include FlexColumns::Helpers::ExceptionHelpers

  before :each do
    @dh = FlexColumns::Helpers::DatabaseHelper.new
    @dh.setup_activerecord!

    create_standard_system_spec_tables!

    define_model_class(:UserBackdoor, 'flexcols_spec_users') { }
  end

  after :each do
    drop_standard_system_spec_tables!
  end

  it "should store attributes under their JSON alias, but use other names absolutely everywhere else" do
    define_model_class(:User, 'flexcols_spec_users') do
      flex_column :user_attributes do
        field :wants_email, :integer, :json => :we
        field :language_setting, :json => :ls

        validates :wants_email, :numericality => { :greater_than_or_equal_to => 0 }
      end
    end

    user = ::User.new
    user.name = 'User 1'
    user.wants_email = 123
    user.language_setting = 'foobar'
    user.save!

    user_bd = ::UserBackdoor.find(user.id)
    json = user_bd.user_attributes
    parsed = JSON.parse(json)

    parsed.keys.sort.should == %w{we ls}.sort
    parsed['we'].should == 123
    parsed['ls'].should == 'foobar'

    # make sure hashes work on original field names
    lambda { user.user_attributes[:we] }.should raise_error(FlexColumns::Errors::NoSuchFieldError)
    lambda { user.user_attributes[:ls] }.should raise_error(FlexColumns::Errors::NoSuchFieldError)

    # Make sure methods work on original field names
    lambda { user.user_attributes.send(:we) }.should raise_error(NoMethodError)
    lambda { user.user_attributes.send(:ls) }.should raise_error(NoMethodError)

    # Make sure validations work still
    user.valid?.should be

    user.wants_email = -123

    user.valid?.should_not be
    user.errors.attribute_names.should == [ :'user_attributes.wants_email' ]

    user.user_attributes.valid?.should_not be
    user.user_attributes.errors.attribute_names.should == [ :wants_email ]
  end

  it "should prohibit conflicting JSON names" do
    e = capture_exception(FlexColumns::Errors::ConflictingJsonStorageNameError) do
      define_model_class(:User, 'flexcols_spec_users') { }

      define_model_class(:User, 'flexcols_spec_users') do
        flex_column :user_attributes, :unknown_fields => :delete do
          field :wants_email, :json => :aaa
          field :language_setting, :json => :aaa
        end
      end
    end

    e.model_class.should == ::User
    e.column_name.should == :user_attributes
    e.new_field_name.should == :language_setting
    e.existing_field_name.should == :wants_email
    e.json_storage_name.should == :aaa

    e.message.should match(/User/i)
    e.message.should match(/user_attributes/i)
    e.message.should match(/language_setting/i)
    e.message.should match(/wants_email/i)
    e.message.should match(/aaa/i)
  end

  it "should prohibit JSON names from conflicting with non-aliased fields" do
    e = capture_exception(FlexColumns::Errors::ConflictingJsonStorageNameError) do
      define_model_class(:User, 'flexcols_spec_users') { }

      define_model_class(:User, 'flexcols_spec_users') do
        flex_column :user_attributes, :unknown_fields => :delete do
          field :wants_email
          field :language_setting, :json => :wants_email
        end
      end
    end

    e.model_class.should == ::User
    e.column_name.should == :user_attributes
    e.new_field_name.should == :language_setting
    e.existing_field_name.should == :wants_email
    e.json_storage_name.should == :wants_email

    e.message.should match(/User/i)
    e.message.should match(/user_attributes/i)
    e.message.should match(/language_setting/i)
    e.message.should match(/wants_email/i)
    e.message.should match(/wants_email/i)
  end

  it "should treat field names present in the JSON hash as unknown fields, and delete them if asked to" do
    define_model_class(:User, 'flexcols_spec_users') do
      flex_column :user_attributes, :unknown_fields => :delete do
        field :wants_email, :json => :we
        field :language_setting, :json => :ls
      end
    end

    user = ::User.new
    user.name = 'User 1'
    user.save!

    user_bd = ::UserBackdoor.find(user.id)
    user_bd.user_attributes = { 'wants_email' => 123, 'we' => 456, 'language_setting' => 'bonko' }.to_json
    user_bd.save!

    user_again = ::User.find(user.id)
    user_again.wants_email.should == 456
    user_again.language_setting.should be_nil
    user_again.user_attributes.touch!
    user_again.save!

    user_bd = ::UserBackdoor.find(user.id)
    JSON.parse(user_bd.user_attributes).keys.sort.should == %w{we}.sort
  end

  it "should treat field names present in the JSON hash as unknown fields, and preserve them if asked to" do
    define_model_class(:User, 'flexcols_spec_users') do
      flex_column :user_attributes do
        field :wants_email, :json => :we
        field :language_setting, :json => :ls
      end
    end

    user = ::User.new
    user.name = 'User 1'
    user.save!

    user_bd = ::UserBackdoor.find(user.id)
    user_bd.user_attributes = { 'wants_email' => 123, 'we' => 456, 'language_setting' => 'bonko' }.to_json
    user_bd.save!

    user_again = ::User.find(user.id)
    user_again.wants_email.should == 456
    user_again.wants_email = 567
    user_again.language_setting.should be_nil
    user_again.save!

    user_bd = ::UserBackdoor.find(user.id)
    parsed = JSON.parse(user_bd.user_attributes)
    parsed.keys.sort.should == %w{wants_email we language_setting}.sort
    parsed['wants_email'].should == 123
    parsed['we'].should == 567
    parsed['language_setting'].should == 'bonko'
  end
end
