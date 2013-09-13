# encoding: utf-8

require File.expand_path('../spec_helper.rb', __FILE__)

describe Backup::Storage::Kanbox do
  let(:model)   { Backup::Model.new(:test_trigger, 'test label') }
  let(:storage) do
    Backup::Storage::Kanbox.new(model) do |db|
      db.api_key      = 'my_access_id'
      db.api_secret   = 'my_access_key'
      db.keep         = 5
    end
  end

  it 'should be a subclass of Storage::Base' do
    Backup::Storage::Kanbox.
      superclass.should == Backup::Storage::Base
  end

  describe '#initialize' do
    after { Backup::Storage::Kanbox.clear_defaults! }

    it 'should load pre-configured defaults through Base' do
      Backup::Storage::Kanbox.any_instance.expects(:load_defaults!)
      storage
    end

    it 'should pass the model reference to Base' do
      storage.instance_variable_get(:@model).should == model
    end

    it 'should pass the storage_id to Base' do
      storage = Backup::Storage::Kanbox.new(model, 'my_storage_id')
      storage.storage_id.should == 'my_storage_id'
    end

    context 'when no pre-configured defaults have been set' do
      it 'should use the values given' do
        storage.api_key.should      == 'my_access_id'
        storage.api_secret.should   == 'my_access_key'
        storage.path.should         == 'backups'

        storage.storage_id.should be_nil
        storage.keep.should       == 5
      end

      it 'should use default values if none are given' do
        storage = Backup::Storage::Kanbox.new(model)
        storage.api_key.should      be_nil
        storage.api_secret.should   be_nil
        storage.path.should         == 'backups'

        storage.storage_id.should be_nil
        storage.keep.should       be_nil
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Storage::Kanbox.defaults do |s|
          s.api_key      = 'some_api_key'
          s.api_secret   = 'some_api_secret'
          s.path         = 'some_path'
          s.keep         = 15
        end
      end

      it 'should use pre-configured defaults' do
        storage = Backup::Storage::Kanbox.new(model)

        storage.api_key.should      == 'some_api_key'
        storage.api_secret.should   == 'some_api_secret'
        storage.path.should         == 'some_path'

        storage.storage_id.should be_nil
        storage.keep.should       == 15
      end

      it 'should override pre-configured defaults' do
        storage = Backup::Storage::Kanbox.new(model) do |s|
          s.api_key      = 'new_api_key'
          s.api_secret   = 'new_api_secret'
          s.path         = 'new_path'
          s.keep         = 10
        end

        storage.api_key.should      == 'new_api_key'
        storage.api_secret.should   == 'new_api_secret'
        storage.path.should         == 'new_path'

        storage.storage_id.should be_nil
        storage.keep.should       == 10
      end
    end # context 'when pre-configured defaults have been set'
  end # describe '#initialize'
  
  describe '#connection' do
    let (:connection) { mock }
    let (:session) { mock }
    
    it "should return old connction if it exist" do
      storage.instance_variable_set(:@connection,connection)
      storage.send(:connection).should == connection
    end
  end

  describe '#transfer!' do
    let(:connection) { mock }
    let(:package) { mock }
    let(:file) { mock }
    let(:s) { sequence '' }

    before do
      storage.instance_variable_set(:@package, package)
      Backup::Config.stubs(:tmp_path).returns('/local/path')
      storage.stubs(:connection).returns(connection)
      file.stubs(:read).returns("foo")
    end

    it 'should transfer the package files' do
      storage.expects(:remote_path_for).in_sequence(s).with(package).
          returns('remote/path')
      package.stubs(:filenames).returns(['backup.tar.enc-aa','backup.tar.enc-ab'])
      # first yield
      Backup::Logger.expects(:info).in_sequence(s).with(
        "Storing 'remote/path/backup.tar.enc-aa'..."
      )
      connection.expects(:put).in_sequence(s).with(
        File.join('remote/path', 'backup.tar.enc-aa'), File.join('/local/path', 'backup.tar.enc-aa')
      )
      # second yield
      Backup::Logger.expects(:info).in_sequence(s).with(
        "Storing 'remote/path/backup.tar.enc-ab'..."
      )
      connection.expects(:put).in_sequence(s).with(
        File.join('remote/path', 'backup.tar.enc-ab'), File.join('/local/path', 'backup.tar.enc-ab')
      )

      storage.send(:transfer!)
    end
  end # describe '#transfer!'

  describe '#remove!' do
    let(:package) { mock }
    let(:connection) { mock }
    let(:s) { sequence '' }

    before do
      storage.stubs(:storage_name).returns('Storage::Kanbox')
      storage.stubs(:connection).returns(connection)
    end

    it 'should remove the package files' do
      storage.expects(:remote_path_for).in_sequence(s).with(package).
          returns('remote/path')
      # after both yields
      Backup::Logger.expects(:info).in_sequence(s).with(
        "Removeing 'remote/path' from Kanbox..."
      )
      connection.expects(:delete).in_sequence(s).with('remote/path')

      storage.send(:remove!, package)
    end
  end # describe '#remove!'


end