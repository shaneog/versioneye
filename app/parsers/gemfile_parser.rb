class GemfileParser < CommonParser
  
  # Parser for Gemfile. For Ruby. 
  # http://gembundler.com/man/gemfile.5.html
  # http://docs.rubygems.org/read/chapter/16#page74
  # 
  def parse ( url )
    return nil if url.nil?    
    
    response = self.fetch_response(url)
    gemfile = response.body
    return nil if gemfile.nil?
    
    project = Project.new
    project.dependencies = Array.new
    
    gemfile.each_line do |line|
      
      # if it starts not with gem skip the line
      line = line.strip
      next if line.match(/^gem/).nil?
      
      line = line.gsub("gem ", "")
      line_elements = line.split(",")
      package = self.replace_comments(line_elements[0])
      package = package.strip
      package = package.gsub('"', '')
      package = package.gsub("'", "")
      
      dependency = Projectdependency.new
      dependency.name = package
      
      product = Product.find_by_key(package)
      if product.nil? 
        product = Product.find_by_key_case_insensitiv(package)
      end
      if product 
        dependency.prod_key = product.prod_key 
        dependency.version_current = product.version
      else 
        project.unknown_number = project.unknown_number + 1
      end
      
      version = line_elements[1]
      parse_requested_version(version, dependency, product)
      
      if dependency.outdated?
        project.out_number = project.out_number + 1
      end      
      project.dependencies << dependency
    end
    project.dep_number = project.dependencies.count
    project.project_type = Project::A_TYPE_RUBYGEMS
    project.language = Product::A_LANGUAGE_RUBY
    project.url = url
    project
  end

  # It is important that this method is not writing into the database! 
  #
  def parse_requested_version(version, dependency, product)
    if (version.nil? || version.empty?)
      self.update_requested_with_current(dependency, product)
      return 
    end
    version = self.replace_comments(version)
    version = version.strip
    version = version.gsub('"', '')
    version = version.gsub("'", "")

    if product.nil? 
      dependency.version_requested = version
      dependency.version_label = version
    
    elsif version.match(/^=/)
      # Equals
      version.gsub!("=", "")
      version.gsub!(" ", "")
      dependency.version_requested = version
      dependency.version_label = version
      dependency.comperator = "="
    
    elsif version.match(/^!=/)
      # Not equal to version
      version.gsub!("!=", "")
      version.gsub!(" ", "")
      newest_version = product.newest_but_not(version)
      dependency.version_requested = newest_version
      dependency.comperator = "!="
      dependency.version_label = version
    
    elsif version.match(/^>=/)
      # Greater than or equal to
      version.gsub!(">=", "")
      version.gsub!(" ", "")
      newest_version = product.greater_than_or_equal(version)
      dependency.version_requested = newest_version.version
      dependency.comperator = ">="
      dependency.version_label = version
    
    elsif version.match(/^>/)
      # Greater than version
      version.gsub!(">", "")
      version.gsub!(" ", "")
      newest_version = product.greater_than(version)
      dependency.version_requested = newest_version.version
      dependency.comperator = ">"
      dependency.version_label = version
    
    elsif version.match(/^<=/)
      # Less than or equal to
      version.gsub!("<=", "")
      version.gsub!(" ", "")
      newest_version = product.smaller_than_or_equal(version)
      dependency.version_requested = newest_version.version
      dependency.comperator = "<="
      dependency.version_label = version
    
    elsif version.match(/^\</)
      # Less than version
      version.gsub!("\<", "")
      version.gsub!(" ", "")
      newest_version = product.smaller_than(version)
      dependency.version_requested = newest_version.version
      dependency.comperator = "<"
      dependency.version_label = version
    
    elsif version.match(/^~>/)
      # Approximately greater than -> Pessimistic Version Constraint
      ver = version.gsub("~>", "")
      ver = ver.gsub(" ", "")
      starter = Product.version_approximately_greater_than_starter(ver)
      versions = product.versions_start_with( starter )
      highest_version = Product.newest_version_from(versions)
      if highest_version
        dependency.version_requested = highest_version.version
      else 
        dependency.version_requested = ver
      end
      dependency.comperator = "~>"
      dependency.version_label = ver

    elsif version.match(/^git:/) or version.match(/^:git/)
      dependency.version_requested = "GIT"
      dependency.version_label = "GIT"
      dependency.comperator = "="

    elsif version.match(/^require:/) or version.match(/^:require/) or version.match(/^:group/) or version.match(/^group:/)
      dependency.version_requested = product.version
      dependency.version_label = product.version
      dependency.comperator = "="
    
    else
      dependency.version_requested = version
      dependency.comperator = "="
      dependency.version_label = version
    end
    
  end

  def replace_comments(value)
    return nil unless value
    comment = value.match(/#.*/)
    if comment 
      value.gsub!(comment[0], "")
    end
    value
  end
  
end
