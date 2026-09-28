module ActiveCanvas
  # Shared by PageContentUpdate, PagePreview, and Admin::PagesController's
  # validate_template/chip_values/sample_data/preview_iframe actions: runs a
  # (possibly unsaved, dup'd) page's validations and reports only the
  # bindings error, if any.
  #
  # A dup'd page fails the slug uniqueness check against its own row, so only
  # the bindings errors are meaningful here.
  module InvalidBindingsCheck
    def self.message_for(page)
      page.validate
      page.errors.full_messages_for(:bindings).to_sentence.presence
    end
  end
end
