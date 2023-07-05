defmodule PingPongMeasurerZenohex.Pong2 do
  use GenServer

  require Logger

  @message_type 'StdMsgs.Msg.String'
  @ping_topic 'ping_topic'
  @pong_topic 'pong_topic'

  alias PingPongMeasurerZenohex.Utils

  def start_link(args_tuple) do
    GenServer.start_link(__MODULE__, args_tuple, name: __MODULE__)
  end

  def init({context, node_counts}) when is_integer(node_counts) do
    """
    {:ok, node_id_list} = Zenohex.ResourceServer.create_nodes(context, 'pong_node', node_counts)

    {:ok, subscribers} =
      Zenohex.Node.create_subscribers(node_id_list, @message_type, @ping_topic, :multi)

    {:ok, publishers} =
      Zenohex.Node.create_publishers(node_id_list, @message_type, @pong_topic, :multi)

    for {_node_id, index} <- Enum.with_index(node_id_list) do
      subscriber = Enum.at(subscribers, index)
      publisher = Enum.at(publishers, index)

      Zenohex.Subscriber.start_subscribing([subscriber], context, fn message ->
        message = Zenohex.Msg.read(message, @message_type)
        Logger.debug('ping: ' ++ message.data)

        Zenohex.Publisher.publish([publisher], [Utils.create_payload(message.data)])
      end)
    end

    {:ok, nil}
  """
    session = Zenohex.open
    {:ok, publisher} = Session.declare_publisher(session, "demo/example/zenoh-rs-pub")
    {:ok, subscriber} = Session.declare_subscriber(session, "demo/example/zenoh-rs-pub", fn m -> IO.inspect(m) end)

    publishers = [publisher]
    subscribers = [subscriber]

    node_id_list = ['a']

    for {_node_id, index} <- Enum.with_index(node_id_list) do
      subscriber = Enum.at(subscribers, index)
      publisher = Enum.at(publishers, index)

      Zenohex.Publisher.put(publisher, Utils.create_payload(payload_charlist))
    end
  end
end
