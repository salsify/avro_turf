require 'avro_turf/schema_registry'

# Caches registrations and lookups to the schema registry in memory.
class AvroTurf::CachedSchemaRegistry < DelegateClass(AvroTurf::SchemaRegistry)

  def initialize(upstream)
    @upstream = super(upstream)
    @schemas_by_id = {}
    @ids_by_schema = {}
  end

  def fetch(id)
    @schemas_by_id[id] ||= @upstream.fetch(id)
  end

  def register(subject, schema)
    @ids_by_schema[subject + schema.to_s] ||= @upstream.register(subject, schema)
  end
end
