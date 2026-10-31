defmodule EXLA.ClientTest do
  use ExUnit.Case, async: true

  doctest EXLA.Client

  describe "get_supported_platforms/0" do
    test "returns supported platforms with device information" do
      %{host: _} = EXLA.Client.get_supported_platforms()
    end
  end

  describe "start_distributed_service/2" do
    test "listens until the service is garbage collected" do
      {:ok, socket} = :gen_tcp.listen(0, [])
      {:ok, port} = :inet.port(socket)
      :ok = :gen_tcp.close(socket)

      test = self()

      # The service lives as long as the process holding the reference
      owner =
        spawn(fn ->
          service = EXLA.Client.start_distributed_service("127.0.0.1:#{port}", 2)
          send(test, :started)
          receive do: (:stop -> is_reference(service))
        end)

      assert_receive :started
      assert listening?(port)

      send(owner, :stop)

      assert Enum.any?(1..50, fn _ ->
               Process.sleep(100)
               not listening?(port)
             end)
    end
  end

  defp listening?(port) do
    case :gen_tcp.connect(~c"127.0.0.1", port, []) do
      {:ok, socket} -> :gen_tcp.close(socket) == :ok
      {:error, :econnrefused} -> false
    end
  end

  describe "build_client/2" do
    test "addressable devices are the local devices" do
      client = EXLA.Client.build_client(:diag, platform: :host)
      assert client.addressable_device_ids == Enum.to_list(0..(client.device_count - 1))
      assert client.default_device_id == 0
    end

    test "unknown platform names the client and the supported platforms" do
      exception =
        assert_raise ArgumentError, fn ->
          EXLA.Client.build_client(:diag, platform: :not_a_platform)
        end

      assert exception.message =~ "client :diag"
      assert exception.message =~ ":not_a_platform"
      assert exception.message =~ ":host"
    end

    test "invalid default device names the client and platform" do
      exception =
        assert_raise ArgumentError, fn ->
          EXLA.Client.build_client(:diag, platform: :host, default_device_id: -1)
        end

      assert exception.message =~ "client :diag"
      assert exception.message =~ ":host"
      assert exception.message =~ "-1"
    end
  end
end
