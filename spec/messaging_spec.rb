require 'webmock/rspec'
require 'avro_turf/messaging'
require_relative 'fake_schema_registry_server'

describe AvroTurf::Messaging do
  let(:registry_url) { "http://registry.example.com" }
  let(:logger) { Logger.new(StringIO.new) }

  let(:avro) {
    AvroTurf::Messaging.new(
      registry_url: registry_url,
      schemas_path: "spec/schemas",
      logger: logger
    )
  }

  let(:message) { { "full_name" => "John Doe" } }

  before do
    FileUtils.mkdir_p("spec/schemas")
  end

  before do
    stub_request(:any, /^#{registry_url}/).to_rack(FakeSchemaRegistryServer)
    FakeSchemaRegistryServer.clear
  end

  before do
    define_schema "person.avsc", <<-AVSC
      {
        "name": "person",
        "type": "record",
        "fields": [
          {
            "type": "string",
            "name": "full_name"
          }
        ]
      }
    AVSC
  end

  shared_examples_for "encoding and decoding" do
    it "encodes and decodes messages" do
      data = avro.encode(message, schema_name: "person")
      expect(avro.decode(data)).to eq message
    end

    it "allows specifying a reader's schema" do
      data = avro.encode(message, schema_name: "person")
      expect(avro.decode(data, schema_name: "person")).to eq message
    end
  end

  it_behaves_like "encoding and decoding"

  context "with a provided schema store" do
    let(:schema_store) { AvroTurf::SchemaStore.new(path: "spec/schemas") }

    let(:avro) do
      AvroTurf::Messaging.new(
        registry_url: registry_url,
        schema_store: schema_store,
        logger: logger
      )
    end

    it_behaves_like "encoding and decoding"

    it "uses the provided schema store" do
      allow(schema_store).to receive(:find).and_call_original
      avro.encode(message, schema_name: "person")
      expect(schema_store).to have_received(:find).with("person", nil)
    end
  end

  it "caches parsed schemas for decoding" do
    data = avro.encode(message, schema_name: "person")
    avro.decode(data)
    allow(Avro::Schema).to receive(:parse).and_call_original
    expect(avro.decode(data)).to eq message
    expect(Avro::Schema).not_to have_received(:parse)
  end

  context "when active_support/core_ext is present" do
    let(:avro) do
      super().tap do |messaging|
        # Simulate the presence of active_support/core_ext by monkey patching
        # the schema store to monkey patch #to_json on the returned schema.
        schema_store = messaging.instance_variable_get(:@schema_store)
        def schema_store.find(*)
          super.extend(Module.new do
            # Replace to_json on the returned schema with an implementation
            # that returns something similar to active_support/core_ext/json
            def to_json(*args)
              instance_variables.each_with_object(Hash.new) do |ivar, result|
                result[ivar.to_s.sub('@','')] = instance_variable_get(ivar)
              end.to_json(*args)
            end
          end)
        end
      end
    end

    it_behaves_like "encoding and decoding"
  end
end
