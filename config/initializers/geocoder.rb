Geocoder.configure(cache: ActiveSupport::Cache::FileStore.new(Rails.root.join('cache/geocode')))
