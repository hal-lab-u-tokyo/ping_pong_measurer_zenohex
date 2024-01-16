defmodule PingPongMeasurerZenohex do
  @moduledoc """
  Documentation for `PingPongMeasurerZenohex`.
  """

  require Logger

  alias PingPongMeasurerZenohex.Ping2, as: Ping
  alias PingPongMeasurerZenohex.Pong2, as: Pong

  alias PingPongMeasurerZenohex.OsInfo.CpuMeasurer
  alias PingPongMeasurerZenohex.OsInfo.MemoryMeasurer
  alias PingPongMeasurerZenohex.Ping2.Measurer, as: PingMeasurer

  def start_ping_processes(context, node_counts, data_directory_path, from) do
    Ping.start_link({context, node_counts, data_directory_path, from})
    Ping.start_subscribing()
  end

  def stop_ping_processes() do
    GenServer.stop(Ping)

    Logger.info("stop_ping_processes done.")
  end

  def start_pong_processes(context, node_counts) do
    Pong.start_link({context, node_counts})
  end

  def stop_pong_processes() do
    GenServer.stop(Pong)
  end

  def start_ping_pong(payload) do
    Ping.get_publishers()
    |> Ping.publish(payload)
  end

  def wait_until_all_nodes_finished(node_counts, finished_node_counts \\ 0) do
    receive do
      :finished ->
        finished_node_counts = finished_node_counts + 1

        if(node_counts > finished_node_counts) do
          wait_until_all_nodes_finished(node_counts, finished_node_counts)
        end
    end
  end

  def start_os_info_measurement(data_directory_path, measurement_cycle_ms \\ 100)
      when is_binary(data_directory_path) and is_integer(measurement_cycle_ms) do
    ds_name = os_info_supervisor_name()
    PingPongMeasurerZenohex.DynamicSupervisor.start_link(ds_name)

    DynamicSupervisor.start_child(
      ds_name,
      {CpuMeasurer, {data_directory_path, measurement_cycle_ms}}
    )

    DynamicSupervisor.start_child(
      ds_name,
      {MemoryMeasurer, {data_directory_path, measurement_cycle_ms}}
    )

    Logger.info("start_os_info_measurement done.")
  end

  def stop_os_info_measurement() do
    DynamicSupervisor.stop(os_info_supervisor_name())
  end

  def start_ping_measurer(data_directory_path) when is_binary(data_directory_path) do
    ds_name = ping_measurer_supervisor_name()
    PingPongMeasurerZenohex.DynamicSupervisor.start_link(ds_name)

    for node_id <- Ping.get_node_id_list() do
      DynamicSupervisor.start_child(
        ds_name,
        {PingMeasurer, %{node_id: node_id, data_directory_path: data_directory_path}}
      )
    end

    Logger.info("start_ping_measurer done.")
  end

  def sample_start_process(node_counts,payload) do
    Ping.get_publishers()
    |> Ping.sample_pub(node_counts,payload)
  end

  def stop_ping_measurer() do
    DynamicSupervisor.stop(ping_measurer_supervisor_name())
  end

  defp os_info_supervisor_name() do
    Module.concat(__MODULE__, OsInfo.DynamicSupervisor) #MEMO: concat of module names
  end

  defp ping_measurer_supervisor_name() do
    Module.concat(__MODULE__, Ping.Measurer.DynamicSupervisor)
  end
end
