module FileUploadCache
  module CachedAttributes
    extend ActiveSupport::Concern

    module ClassMethods

      def cached_file_for(field, options={})
        attr_accessor :"#{field}_cache_id", :"cached_#{field}"
        define_method "#{field}_with_cache=" do |value|
          instance_variable_set("@#{field}_original", value)
          self.send("#{field}_without_cache=", value)
        end

        alias_method_chain :"#{field}=", :cache
        
        before_validation lambda {
          original = self.instance_variable_get("@#{field}_original")
          original.rewind if original && original.respond_to?(:rewind)
          
          # set file var from cache if cache id exists and original is blank (in before_validation, in case file is required)
          if( ! self.send("#{field}_cache_id").blank? && original.blank? )
            if cached_file = CachedFile.find(self.send("#{field}_cache_id"))
              tf = FileUploadCache::Tempfile.for(cached_file.read, cached_file.original_filename)
              self.send("#{field}=", tf)
              self.send("cached_#{field}=", cached_file)
            end
          end
        }

        after_validation lambda {
          original = self.instance_variable_get("@#{field}_original")
          original.rewind if original && original.respond_to?(:rewind)
          
          # set cached file if there are errors
          if self.errors.present?
            if self.send("cached_#{field}").blank? && original.respond_to?(:read)
              cached_file = CachedFile.store(original)
              self.send("cached_#{field}=", cached_file)
              self.send("#{field}_cache_id=", cached_file.id)
            end
            if options[:nested_children]
              options[:nested_children].each{|assoc, assoc_field|
                self.send(assoc).each{|child_record|
                  if child_record.new_record?
                    original_child = child_record.instance_variable_get("@#{assoc_field}_original")
                    if original_child && original_child.respond_to?(:read)
                      original_child.rewind if original_child.respond_to?(:rewind)
                      child_cached_file = CachedFile.store(original_child)
                      child_record.send("cached_#{assoc_field}=", child_cached_file)
                      child_record.send("#{assoc_field}_cache_id=", child_cached_file.id)
                    end
                  end
                }
              }
            end
            if options[:double_nested_children]
              options[:double_nested_children].each{|parent_association, nested_children|
                nested_children.each{|assoc, assoc_field|
                  self.send(parent_association).each{|parent_record|
                    parent_record.send(assoc).each{|child_record|
                      if child_record.new_record?
                        original_child = child_record.instance_variable_get("@#{assoc_field}_original")
                        if original_child && original_child.respond_to?(:read)
                          original_child.rewind if original_child.respond_to?(:rewind)
                          child_cached_file = CachedFile.store(original_child)
                          child_record.send("cached_#{assoc_field}=", child_cached_file)
                          child_record.send("#{assoc_field}_cache_id=", child_cached_file.id)
                        end
                      end
                    }
                  }
                }
              }
            end
          # otherwise delete cached file is no longer needed
          elsif self.send("#{field}_cache_id").present? && cached_file = CachedFile.find(self.send("#{field}_cache_id"))
            CachedFile.delete(self.send("#{field}_cache_id"))
            self.send("cached_#{field}=", nil)
            self.send("#{field}_cache_id=", nil)
          end
        }
      end
    end
  end

end

ActiveRecord::Base.send(:include, FileUploadCache::CachedAttributes)
