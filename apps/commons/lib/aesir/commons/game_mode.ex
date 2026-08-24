defmodule Aesir.Commons.GameMode do
  @moduledoc """
  Provides the game mode selected at boot.
  """

  @typedoc "The server's game ruleset."
  @type t :: :renewal | :pre_renewal

  @pt_key __MODULE__

  @doc "Returns the cached game mode or the configured mode when it has not been cached."
  @spec mode() :: t()
  def mode do
    :persistent_term.get(@pt_key, nil) || Application.get_env(:commons, :game_mode, :renewal)
  end

  @doc "Caches the configured game mode for the lifetime of the node."
  @spec cache!() :: :ok
  def cache! do
    :persistent_term.put(@pt_key, mode())
  end

  @doc "Converts a game mode to its protocol enum value."
  @spec proto_enum(t()) :: :GAME_MODE_RENEWAL | :GAME_MODE_PRE_RENEWAL
  def proto_enum(:renewal), do: :GAME_MODE_RENEWAL
  def proto_enum(:pre_renewal), do: :GAME_MODE_PRE_RENEWAL
end
