module Blather
class Stanza

  # = Presence Stanza
  #
  # Within Blather most of the interaction with Presence stanzas will be through one of its child classes: Status or Subscription.
  #
  # Presence stanzas are used to express an entity's current network availability (offline or online, along with
  # various sub-states of the latter and optional user-defined descriptive text), and to notify other entities of
  # that availability. Presence stanzas are also used to negotiate and manage subscriptions to the presence of other entities.
  #
  # == Type Attribute
  #
  # The +type+ attribute of a presence stanza is optional. A presence stanza that does not possess a +type+ attribute
  # is used to signal to the server that the sender is online and available for communication. If included, the +type+
  # attribute specifies a lack of availability, a request to manage a subscription to another entity's presence, a
  # request for another entity's current presence, or an error related to a previously-sent presence stanza. If included,
  # the +type+ attribute must have one of the following values:
  #
  # * +:unavailable+ -- Signals that the entity is no longer available for communication
  # * +:subscribe+ -- The sender wishes to subscribe to the recipient's presence.
  # * +:subscribed+ -- The sender has allowed the recipient to receive their presence.
  # * +:unsubscribe+ -- The sender is unsubscribing from another entity's presence.
  # * +:unsubscribed+ -- The subscription request has been denied or a previously-granted subscription has been cancelled.
  # * +:probe+ -- A request for an entity's current presence; should be generated only by a server on behalf of a user.
  # * +:error+ -- An error has occurred regarding processing or delivery of a previously-sent presence stanza.
  #
  # Blather provides a helper for each possible type:
  #
  #   Presence#unavailabe?
  #   Presence#unavailable?
  #   Presence#subscribe?
  #   Presence#subscribed?
  #   Presence#unsubscribe?
  #   Presence#unsubscribed?
  #   Presence#probe?
  #   Presence#error?
  #
  # Blather treats the +type+ attribute like a normal ruby object attribute providing a getter and setter.
  # The default +type+ is nil.
  #
  #   presence = Presence.new
  #   presence.type                # => nil
  #   presence.type = :unavailable
  #   presence.unavailable?        # => true
  #   presence.error?              # => false
  #
  #   presence.type = :invalid   # => RuntimeError
  #
  class Presence < Stanza
    VALID_TYPES = [:unavailable, :subscribe, :subscribed, :unsubscribe, :unsubscribed, :probe, :error] # :nodoc:

    register :presence

    ##
    # Creates a class based on the presence type
    # either a Status or Subscription object is created based
    # on the type attribute.
    # If neither is found it instantiates a Presence object
    def self.import(node) # :nodoc:
      klass = case node['type']
      when nil, 'unavailable' then Status
      when /subscribe/        then Subscription
      else self
      end
      klass.new.inherit(node)
    end

    ##
    # Ensure element_name is "presence" for all subclasses
    def self.new
      super :presence
    end

    attribute_helpers_for(:type, VALID_TYPES)

    ##
    # Ensures type is one of :unavailable, :subscribe, :subscribed, :unsubscribe, :unsubscribed, :probe or :error
    def type=(type) # :nodoc:
      raise ArgumentError, "Invalid Type (#{type}), use: #{VALID_TYPES*' '}" if type && !VALID_TYPES.include?(type.to_sym)
      super
    end

  end

end #Stanza
end
