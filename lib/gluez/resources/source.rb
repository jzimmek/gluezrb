resource :source do

  mandatory     :not_if
  mandatory     :filename
  mandatory     :folder
  mandatory     :make
  optional      :tmp_dir, :default => "~/tmp"

  ready!
  
  steps do |step|
    step.checks << self.not_if
    step.code = <<-CODE
      [ -f #{self.tmp_dir}/#{self.filename} ] && rm #{self.tmp_dir}/#{self.filename}
      [ -d #{self.tmp_dir}/#{self.folder} ] && rm -rf #{self.tmp_dir}/#{self.folder}

      wget --no-check-certificate -O #{self.tmp_dir}/#{self.filename} #{self.name}
      tar -C #{self.tmp_dir}/ -x#{self.filename =~ /\.tar\.bz2/ ? "j" : "z"}f #{self.tmp_dir}/#{self.filename}
      cd #{self.tmp_dir}/#{self.folder} && #{self.make}
    CODE
  end
end