module FileUploadCache
  class Tempfile < ::Tempfile
    attr_accessor :original_filename

    # mode should be :binmode or :text
    def self.for(data, filename, mode = :binmode)
      file = self.new(filename)
      file.original_filename = filename
      file.binmode if mode == :binmode
      file.write(data)
      file.rewind
      file
    end

  end
end
