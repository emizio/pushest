defmodule Pushest.Socket.Utils do
  @moduledoc ~S"""
  Various Socket-scoped utilities.
  """

  alias Pushest.Socket.Data.{Url, State, SocketInfo}
  alias Pushest.Data.Options

  @version Mix.Project.config()[:version]
  @protocol 7

  @doc ~S"""
  Returns auth token needed to authorize our client against Pusher server when
  subscribing to private or presence channel. Token is generated only for those
  two channel types as it's not needed for public channels subscriptions.
  """
  @spec auth(%State{}, String.t(), map) :: nil | String.t()
  def auth(state, channel = "private-" <> _rest, user_data) do
    do_auth(state, channel, user_data)
  end

  def auth(state, channel = "presence-" <> _rest, user_data) do
    do_auth(state, channel, user_data)
  end

  def auth(_state, _channel, _user_data), do: nil

  @doc ~S"""
  Generates Url struct with domain, path and port parts needed to build Pusher
  Server URL for given Pusher app key and configuration. String values are
  converted to charlist since that is the accepted format for underlying :gun lib.
  """
  @spec url(map) :: %Url{}
  def url(%{key: key, cluster: cluster, encrypted: encrypted}) do
    %Url{
      domain: to_charlist("ws-#{cluster}.pusher.com"),
      path:
        to_charlist(
          "/app/#{key}?protocol=#{@protocol}&client=pushest&version=#{@version}&flash=false"
        ),
      port: if(encrypted, do: 443, else: 80)
    }
  end

  @doc ~S"""
  Checks whether `user_data` map contains mandatory element `user_id` and its
  content is valid. Used when subscribing to presence channel as user_id is
  necessary there.

  ## Examples

      iex> Pushest.Socket.Utils.validate_user_data(%{user_id: 1})
      {:ok, %{user_id: 1}}

      iex> Pushest.Socket.Utils.validate_user_data(%{user_id: "1"})
      {:ok, %{user_id: "1"}}

      iex> Pushest.Socket.Utils.validate_user_data(%{user_id: ""})
      {:error, %{user_id: ""}}

      iex> Pushest.Socket.Utils.validate_user_data(%{user_id: nil})
      {:error, %{user_id: nil}}

      iex> Pushest.Socket.Utils.validate_user_data(%{})
      {:error, %{}}
  """
  @spec validate_user_data(map) :: {:ok, map} | {:error, map}
  def validate_user_data(user_data) when user_data == %{}, do: {:error, user_data}
  def validate_user_data(user_data = %{user_id: nil}), do: {:error, user_data}
  def validate_user_data(user_data = %{user_id: ""}), do: {:error, user_data}
  def validate_user_data(user_data = %{user_id: _}), do: {:ok, user_data}

  @spec do_auth(%State{}, String.t(), map) :: String.t()
  defp do_auth(
         %State{
           options: %Options{key: key, secret: secret},
           socket_info: %SocketInfo{socket_id: socket_id}
         },
         channel,
         user_data
       ) do
    signed = string_to_sign(socket_id, channel, user_data)
    signature = :crypto.mac(:hmac, :sha256, secret, signed) |> Base.encode16(case: :lower)

    "#{key}:#{signature}"
  end

  @spec string_to_sign(String.t(), String.t(), map) :: String.t()
  defp string_to_sign(socket_id, channel, user_data) do
    "#{socket_id}:#{channel}:#{Poison.encode!(user_data)}"
  end
end
