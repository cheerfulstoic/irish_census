Dir.glob(Rails.root.join('lib/ext/*')).each {|path| require path }
