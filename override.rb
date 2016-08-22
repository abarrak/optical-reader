module OpticalReader
  class App < Base
    # Override sinatra uri for i18n aware url genreation.
    def uri addr = nil, absolute = true, add_script_name = true
      return addr if addr =~ /\A[a-z][a-z0-9\+\.\-]*:/i
      uri = [host = String.new]
      if absolute
        host << "http#{'s' if request.secure?}://"
        if request.forwarded? or request.port != (request.secure? ? 443 : 80)
          host << request.host_with_port
        else
          host << request.host
        end
      end
      uri << request.script_name.to_s if add_script_name
      uri << I18n.locale.to_s
      uri << (addr ? addr : request.path_info).to_s
      File.join uri
    end

    # :to to alias the new implementation. url not 'for agnostic stuff. e.g.: public'
    alias to uri
  end
end
