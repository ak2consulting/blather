module Blather

  class Stream < EventMachine::Connection
    class NoConnection < RuntimeError; end

    STREAM_NS = 'http://etherx.jabber.org/streams'
    attr_accessor :jid, :password

    ##
    # Start the stream between client and server
    #   [client] must be an object that will respond to #call and #jid=
    #   [jid] must be a valid argument for JID.new (see JID)
    #   [pass] must be the password
    #   [host] (optional) must be the hostname or IP to connect to. defaults to the domain of [jid]
    #   [port] (optional) must be the port to connect to. defaults to 5222
    def self.start(client, jid, pass, host = nil, port = 5222)
      jid = JID.new jid
      if host
        connect host, port, self, client, jid, pass
      else
        require 'resolv'
        srv = []
        Resolv::DNS.open { |dns| srv = dns.getresources("_xmpp-client._tcp.#{jid.domain}", Resolv::DNS::Resource::IN::SRV) }
        if srv.empty?
          connect jid.domain, port, self, client, jid, pass
        else
          srv.sort! { |a,b| (a.priority != b.priority) ? (a.priority <=> b.priority) : (b.weight <=> a.weight) }
          conn = nil
          srv.each { |r| break unless (conn = connect(r.target.to_s, r.port, self, client, jid, pass)) === false }
          conn
        end
      end
    end

    ##
    # Attempt a connection
    # Stream will raise +NoConnection+ if it receives #unbind before #post_init
    # this catches that and returns false prompting for another attempt
    def self.connect(host, port, conn, client, jid, pass)
      EM.connect host, port, conn, client, jid, pass
    rescue NoConnection
      false
    end

    [:started, :stopped, :ready, :negotiating].each do |state|
      define_method("#{state}?") { @state == state }
    end

    ##
    # Send data over the wire
    #   The argument for this can be anything that
    #   responds to #to_s
    def send(stanza)
      #TODO Queue if not ready
      Blather.logger.debug "SENDING: (#{caller[1]}) #{stanza}"
      send_data stanza.respond_to?(:to_xml) ? stanza.to_xml : stanza.to_s
    end

    ##
    # Called by EM.connect to initialize stream variables
    def initialize(client, jid, pass) # :nodoc:
      super()

      @error = nil
      @receiver = @client = client

      self.jid = jid
      @to = self.jid.domain
      @password = pass
    end

    ##
    # Called when EM completes the connection to the server
    # this kicks off the starttls/authorize/bind process
    def connection_completed # :nodoc:
#      @keepalive = EM::PeriodicTimer.new(60) { send_data ' ' }
      start
    end

    ##
    # Called by EM with data from the wire
    def receive_data(data) # :nodoc:
      Blather.logger.debug "\n#{'-'*30}\n"
      Blather.logger.debug "<< #{data}"
      @parser << data

    rescue ParseError => e
      @error = e
      send "<stream:error><xml-not-well-formed xmlns='#{StreamError::STREAM_ERR_NS}'/></stream:error>"
      stop
    end

    def post_init
      @connected = true
    end

    ##
    # Called by EM when the connection is closed
    def unbind # :nodoc:
      raise NoConnection unless @connected

#      @keepalive.cancel
      @state = :stopped
      @client.receive_data @error if @error
      @client.unbind
    end

    ##
    # Called by the parser with parsed nodes
    def receive(node) # :nodoc:
      Blather.logger.debug "RECEIVING (#{node.element_name}) #{node}"
      @node = node

      if @node.namespace && @node.namespace.prefix == 'stream'
        case @node.element_name
        when 'stream'
          @state = :ready if @state == :stopped
          return
        when 'error'
          handle_stream_error
          return
        when 'end'
          stop
          return
        when 'features'
          @state = :negotiating
          @receiver = Features.new(
            self,
            proc { ready! },
            proc { |err| @error = err; stop }
          )
        end
      end
      @receiver.receive_data @node.to_stanza
    end

    ##
    # Ensure the JID gets attached to the client
    def jid=(new_jid) # :nodoc:
      Blather.logger.debug "NEW JID: #{new_jid}"
      @jid = JID.new new_jid
      @client.jid = @jid
    end

  protected
    ##
    # Stop the stream
    def stop
      unless @state == :stopped
        @state = :stopped
        send '</stream:stream>'
      end
    end

    def handle_stream_error
      @error = StreamError.import(@node)
      stop
    end

    def ready!
      @state = :started
      @receiver = @client
      @client.post_init
    end
  end
end
