resource :substitute do
  mandatory :entries
  
  ready!

  self.entries.each do |entry|
    pattern, replacement = entry
    steps do |step|
      step.checks << %Q("\\$(cat #{self.name} | md5sum - | awk '{print \\$1}')" = "\\$(cat #{self.name} | sed 's/#{pattern}/#{replacement}/g' | md5sum - | awk '{print \\$1}')")
      step.code = "sed 's/#{pattern}/#{replacement}/g' -i #{self.name}"
    end
  end
end